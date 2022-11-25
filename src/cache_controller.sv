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
		output logic toCacheReq,
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
					SEND_WT_TO_MEM,
					WAIT_WT_RESP,
					WAIT_MEM_RESP,
					CREATE_CACHE_ENTRY,
					SEND_RESP_TO_CPU
				} STATES;

	STATES state, nextState;

	wire [TAG_WIDTH - 1 : 0] addressTag;

	wire tagMatched; // High if any tag matched
	logic hit;	// High if the tag matched and the matched cache line is Valid
	logic [WAYS - 1 : 0] hitWay;	// Which Way Hit
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
		hitWay = fromTagComparatorHitVector;
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
						nextState = SEND_REQ_TO_MEM;	// No need to handle replacement of dirty data as memory and cache are always coherent(WT)
			WRITE_HIT:
						nextState = SEND_WT_TO_MEM;
			WRITE_MISS:
						nextState = SEND_REQ_TO_MEM;
			SEND_WT_TO_MEM:
						nextState = (reqValid_MEM) ? WAIT_WT_RESP : SEND_WT_TO_MEM;
			WAIT_WT_RESP:
						nextState = (respValid_MEM) ? SEND_RESP_TO_CPU : WAIT_WT_RESP;
			SEND_REQ_TO_MEM:
						nextState = (reqValid_MEM) ? WAIT_MEM_RESP : SEND_REQ_TO_MEM;
			WAIT_MEM_RESP:
						nextState = (respValid_MEM) ? CREATE_CACHE_ENTRY : WAIT_MEM_RESP;
			CREATE_CACHE_ENTRY:
						if(toCacheReq & |toCacheWenTag)   // Cache Entry is created once the request to cache is sent with a write to the tag array
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
			toCacheWenData = hitWay;
		else if(state == CREATE_CACHE_ENTRY)
			toCacheWenData = replacementWay;
	end
	
	// logic for toCacheReq
	always_comb begin
		if(state == SEND_REQ_TO_CACHE)
			toCacheReq = 1;	// Send request to Cache to read the Tags
		else if(state == CREATE_CACHE_ENTRY)
			toCacheReq = 1;	// Send request to Cache to Create a new entry
		else if(state == WRITE_HIT)
			toCacheReq = 1;	// Send request to Cache to Write the data
		else 
			toCacheReq = 0;
	end

	// assign toCacheAddress = state == SEND_REQ_TO_CACHE | state == CREATE_CACHE_ENTRY | state == TAG_MATCH ? reqAddress_CPU : 0;	// Tag Comparator also needs Address during TAG_MATCH phase
	assign toCacheAddress = reqAddress_CPU;
	assign toCacheWenTag = state == CREATE_CACHE_ENTRY ? replacementWay : 0;
	assign toCacheTag = addressTag;

	assign reqValid_MEM = (state == SEND_REQ_TO_MEM) | (state == WAIT_MEM_RESP) | (state == SEND_WT_TO_MEM) | (state == WAIT_WT_RESP);
	assign reqAddress_MEM = reqAddress_CPU;
	assign reqWen_MEM = (state == SEND_WT_TO_MEM) | (state == WAIT_WT_RESP);
	assign reqDataOut_MEM = reqDataIn_CPU;

	always_comb begin
		for(int i = 0; i < WAYS; i++) begin
			toCacheValidDirty[i] = 2'b00;
			if(replacementWay[i] == 1'b1)
				toCacheValidDirty[i] = 2'b01;	// 0th bit is valid
		end
	end

	// Logging
`ifdef LOGGING
	always_ff @(posedge clk)
		case(state)
			READ_HIT: $display("[Read Hit] Address: 0x%x", reqAddress_CPU);
			WRITE_HIT: $display("[Write Hit] Address: 0x%x\tData: 0x%x", reqAddress_CPU, reqDataIn_CPU);
			READ_MISS: $display("[Read Miss] Address: 0x%x", reqAddress_CPU);
			WRITE_MISS: $display("[Write Miss] Address: 0x%x\tData: 0x%x", reqAddress_CPU, reqDataIn_CPU);
		endcase

`endif
	
endmodule 
