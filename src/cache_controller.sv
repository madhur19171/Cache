`timescale 1ns / 1ps

module CacheController #(
		parameter ADDRESS_WIDTH = 32, 
		parameter SETS = 1024, 
		parameter WAYS = 2, 
		parameter CACHE_LINE_SIZE = 32, 
		parameter TAG_WIDTH = ADDRESS_WIDTH - ($clog2(SETS) + $clog2(CACHE_LINE_SIZE / 8))
		)
(
		input clk,
		input rst,
		
		// From CPU
		input reqValid_CPU,
		input [ADDRESS_WIDTH - 1 : 0] reqAddress_CPU,
		input [CACHE_LINE_SIZE -1 : 0]reqDataIn_CPU,
		input reqWen_CPU,
		//To CPU
		output reg [CACHE_LINE_SIZE - 1 : 0] respDataOut_CPU,    // Connect to from cache data
		output reg respHit_CPU,

		// To Memory
		output reqValid_MEM,
		output [ADDRESS_WIDTH - 1 : 0] reqAddress_MEM,
		output [CACHE_LINE_SIZE -1 : 0]reqDataOut_MEM,
		output reqWen_MEM,
		//From Memory
		input respValid_MEM,
		input [CACHE_LINE_SIZE - 1 : 0] respDataIn_MEM,
		
		// From Cache
		input [CACHE_LINE_SIZE - 1 : 0] fromCacheData,
		input [1 : 0] fromCacheValidDirty [WAYS - 1 : 0],
		
		// From Tag Comparator
		input [WAYS - 1 : 0] fromTagComparatorHitVector,
		
		// To Cache
		output toCacheReq,
		output [ADDRESS_WIDTH - 1 : 0] toCacheAddress,
		output logic [CACHE_LINE_SIZE - 1 : 0] toCacheData,
		output logic [WAYS - 1 : 0] toCacheWenData,
		output [WAYS - 1 : 0] toCacheWenTag,
		output [TAG_WIDTH - 1 : 0] toCacheTag,
		output logic [1 : 0] toCacheValidDirty [WAYS - 1 : 0]

);



	typedef enum {	IDLE, 
					SEND_REQ_TO_CACHE, 
					TAG_MATCH, 
					READ_HIT, 
					WRITE_HIT, 
					READ_MISS, 
					WRITE_MISS,
					SEND_REQ_TO_MEM,
					WAIT_MEM_RESP,
					CREATE_CACHE_ENTRY,
					SEND_RESP_TO_CPU
				} STATES;

	STATES state, nextState;

	wire [TAG_WIDTH - 1 : 0] addressTag;

	wire tagMatched; // High if any tag matched
	logic hit;	// High if the tag matched and the matched cache line is Valid
	logic [$clog2(WAYS) - 1 : 0] hitWay;	// Which Way Hit
	wire [WAYS - 1 : 0] replacementWay;	// TODO: Which Way to replace

	logic [WAYS - 1 : 0] validWays;		// Valid Ways from set read
	logic [WAYS - 1 : 0] dirtyWays;		// Drity Ways from set read

	ReplacementLogic #(.WAYS(WAYS)) replacementLogic (.clk(clk), .rst(rst), .ValidWays(validWays), .replacementWay(replacementWay));
	
	assign tagMatched = |fromTagComparatorHitVector;

	assign addressTag = reqAddress_CPU[ADDRESS_WIDTH - 1 -: TAG_WIDTH];

	// Computing Hit
	always_comb begin
		hit = 0;
		for(int i = 0; i < WAYS; i++)
			if(fromTagComparatorHitVector[i])
				hit = 1;
	end

	// Computing which way hit
	always_comb begin
		hitWay = 0;
		for(int i = 0; i < WAYS; i++)
			if(fromTagComparatorHitVector[i])
				hitWay = i;
	end

	// Computing the Valid Ways
	always_comb begin
		validWays = 0;
		for(int i = 0; i < WAYS; i++)
			validWays[i] = fromCacheValidDirty[i][0];	// First Bit is Valid
	end

	// Computing the Dirty Ways
	always_comb begin
		dirtyWays = 0;
		for(int i = 0; i < WAYS; i++)
			dirtyWays[i] = fromCacheValidDirty[i][1];	// Second bit is Dirty
	end
	
	// Assigning Next state on clock cycle
	always_ff @(posedge clk) begin
		if(rst)
			state <= IDLE;
		else
			state <= nextState;
	end
	
	// Computing next state: Mealy Machine
	always_comb begin
		case(state)
			// Send request to cache if CPU sent a request
			IDLE:
						nextState = reqValid_CPU ? SEND_REQ_TO_CACHE : IDLE;
			
			// Do a Tag Match in the next clock cycle after request is sent 
			SEND_REQ_TO_CACHE: 
						nextState = TAG_MATCH;
			
			// Whether Tag Matched in any Way or not
			TAG_MATCH: 
						if(reqWen_CPU)
							if(hit)
								nextState = WRITE_HIT;
							else 
								nextState = WRITE_MISS;
						else 
							if(hit)
								nextState = READ_HIT;
							else
								nextState = READ_MISS;
			
			// Just send the response to the CPU
			READ_HIT:
						nextState = SEND_RESP_TO_CPU;
			READ_MISS:
						nextState = SEND_REQ_TO_MEM;
			SEND_REQ_TO_MEM:
						nextState = (reqValid_MEM) ? WAIT_MEM_RESP : SEND_REQ_TO_MEM;
			WAIT_MEM_RESP:
						nextState = (respValid_MEM) ? CREATE_CACHE_ENTRY : WAIT_MEM_RESP;
			CREATE_CACHE_ENTRY:
						if(toCacheReq & |toCacheWenTag)   // Cache Entry is created once the request to cache is sent with a write to the tag array
							if(reqWen_CPU)
								nextState = IDLE;	// TODO
							else
								nextState = SEND_REQ_TO_CACHE;	// Resend the request to the cache after a Miss
						else	
							nextState = CREATE_CACHE_ENTRY;

			default: nextState = IDLE;
		endcase
	end
	
	// Generating Output

	// In case of a hit, the data is directly sent from the Cache
	// In case of a Miss, the Memory serves the request and the cache
	// is resent the request and this time it hits.
	assign respDataOut_CPU = fromCacheData;
	assign respHit_CPU = state == SEND_RESP_TO_CPU;

	// Write Data to cache will be from CPU in case of a Write Hit
	// Write Data to cache will be from Memory in case of a Cache Entry Creation
	always_comb begin
		toCacheData = 0;
		if(state == WRITE_HIT)
			toCacheData = reqDataIn_CPU;
		else if(state == CREATE_CACHE_ENTRY)
			toCacheData = respDataIn_MEM;
	end

	// Write Data on the hit way in case of a write hit
	// Write Data on the Replacement way in case of a cache entry creation
	always_comb begin
		toCacheWenData = 0;
		if(state == WRITE_HIT)
			toCacheWenData = 1 << hitWay;
		else if(state == CREATE_CACHE_ENTRY)
			toCacheWenData = replacementWay;
	end
	
	assign toCacheReq = state == SEND_REQ_TO_CACHE | state == CREATE_CACHE_ENTRY;
	// assign toCacheAddress = state == SEND_REQ_TO_CACHE | state == CREATE_CACHE_ENTRY | state == TAG_MATCH ? reqAddress_CPU : 0;	// Tag Comparator also needs Address during TAG_MATCH phase
	assign toCacheAddress = reqAddress_CPU;
	assign toCacheWenTag = state == CREATE_CACHE_ENTRY ? replacementWay : 0;
	assign toCacheTag = state == CREATE_CACHE_ENTRY ? addressTag : 0;

	assign reqValid_MEM = (state == SEND_REQ_TO_MEM) | (state == WAIT_MEM_RESP);
	assign reqAddress_MEM = (state == SEND_REQ_TO_MEM) | (state == WAIT_MEM_RESP) ? reqAddress_CPU : 0;
	// assign reqDataOut_MEM = state == SEND_REQ_TO_MEM ? // TODO: Incroporate Replacement, Eviction and Write Through
	assign reqWen_MEM = 0;	// TODO

	always_comb begin
		for(int i = 0; i < WAYS; i++) begin
			toCacheValidDirty[i] = 2'b00;
			if(replacementWay[i] == 1'b1)
				toCacheValidDirty[i] = 2'b01;	// 0th bit is valid
		end
	end
	
endmodule 
