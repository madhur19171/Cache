`timescale 1ns / 1ps

import interface_pkg::*;

module CacheController
(
		input clk,
		input rst,
		
		// CPU Interface
		input CPU_Request CPURequest,
		output CPU_Response CPUResponse,

		// Memory Interface
		output Memory_Request MemoryRequest,
		input Memory_Response MemoryResponse,
		
		// From Cache
		input Cache_Response CacheResponse,
		
		
		// From Tag Comparator
		input [cache_pkg::WAYS - 1 : 0] fromTagComparatorHitVector,
		
		// To Cache
		output Cache_Request CacheRequest

);



	typedef enum {	IDLE, 
					SEND_REQ_TO_CACHE, 
					TAG_MATCH_DELAYED,
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

	wire [cache_pkg::TAG_WIDTH - 1 : 0] addressTag;

	logic hit;	// High if the tag matched and the matched cache line is Valid
	logic [cache_pkg::WAYS - 1 : 0] hitWay;	// Which Way Hit
	wire [cache_pkg::WAYS - 1 : 0] replacementWay;	// TODO: Which Way to replace

	logic [cache_pkg::WAYS - 1 : 0] validWays;		// Valid Ways from set read
	logic [cache_pkg::WAYS - 1 : 0] dirtyWays;		// Drity Ways from set read

	ReplacementLogic #(.WAYS(cache_pkg::WAYS)) replacementLogic (.clk(clk), .rst(rst), .ValidWays(validWays), .replacementWay(replacementWay));
	

	assign addressTag = CPURequest.address[cache_pkg::ADDRESS_WIDTH - 1 -: cache_pkg::TAG_WIDTH];

	// Computing Hit
	always_comb begin
		hit = 0;
		for(int i = 0; i < cache_pkg::WAYS; i++)
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
		for(int i = 0; i < cache_pkg::WAYS; i++)
			validWays[i] = CacheResponse.validDirty[i][0];	// First Bit is Valid
	end

	// Computing the Dirty Ways
	always_comb begin
		dirtyWays = 0;
		for(int i = 0; i < cache_pkg::WAYS; i++)
			dirtyWays[i] = CacheResponse.validDirty[i][1];	// Second bit is Dirty
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
						nextState = CPURequest.valid ? SEND_REQ_TO_CACHE : IDLE;
			
			// Do a Tag Match in the next clock cycle after request is sent 
			SEND_REQ_TO_CACHE: 
						nextState = TAG_MATCH_DELAYED;
			
			// Whether Tag Matched in any Way or not
			TAG_MATCH_DELAYED:
						nextState = TAG_MATCH;	// Delay due to 1 CC delay between tag match due to pipelining
			TAG_MATCH: 
						if(CPURequest.wen)
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
						nextState = (MemoryRequest.valid) ? WAIT_WT_RESP : SEND_WT_TO_MEM;
			WAIT_WT_RESP:
						nextState = (MemoryResponse.valid) ? SEND_RESP_TO_CPU : WAIT_WT_RESP;
			SEND_REQ_TO_MEM:
						nextState = (MemoryRequest.valid) ? WAIT_MEM_RESP : SEND_REQ_TO_MEM;
			WAIT_MEM_RESP:
						nextState = (MemoryResponse.valid) ? CREATE_CACHE_ENTRY : WAIT_MEM_RESP;
			CREATE_CACHE_ENTRY:
						if(CacheRequest.valid & |CacheRequest.wenTag)   // Cache Entry is created once the request to cache is sent with a write to the tag array
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
	assign CPUResponse.data = CacheResponse.data;
	assign CPUResponse.hit = state == SEND_RESP_TO_CPU;

	// Write Data to cache will be from CPU in case of a Write Hit
	// Write Data to cache will be from Memory in case of a Cache Entry Creation
	always_comb begin
		CacheRequest.data = 0;
		if(state == WRITE_HIT)
			CacheRequest.data = CPURequest.data;
		else if(state == CREATE_CACHE_ENTRY)
			CacheRequest.data = MemoryResponse.data;
	end

	// Generating Strobe Signal for Cache
	always_comb begin
		CacheRequest.strobe = 0;
		if(state == WRITE_HIT)
			CacheRequest.strobe = CPURequest.strobe;	// Use Requested strobe on a Write Hit
		else if(state == CREATE_CACHE_ENTRY)
			CacheRequest.strobe = '1;	// Write to all Bytes in the cache line on a Cache Entry Creation
	end

	// Write Data on the hit way in case of a write hit
	// Write Data on the Replacement way in case of a cache entry creation
	always_comb begin
		CacheRequest.wenData = 0;
		if(state == WRITE_HIT)
			CacheRequest.wenData = hitWay;
		else if(state == CREATE_CACHE_ENTRY)
			CacheRequest.wenData = replacementWay;
	end
	
	// logic for toCacheReq
	always_comb begin
		if(state == SEND_REQ_TO_CACHE)
			CacheRequest.valid = 1;	// Send request to Cache to read the Tags
		else if(state == CREATE_CACHE_ENTRY)
			CacheRequest.valid = 1;	// Send request to Cache to Create a new entry
		else if(state == WRITE_HIT)
			CacheRequest.valid = 1;	// Send request to Cache to Write the data
		else 
			CacheRequest.valid = 0;
	end

	// assign toCacheAddress = state == SEND_REQ_TO_CACHE | state == CREATE_CACHE_ENTRY | state == TAG_MATCH ? reqAddress_CPU : 0;	// Tag Comparator also needs Address during TAG_MATCH phase
	assign CacheRequest.address = CPURequest.address;
	assign CacheRequest.wenTag = state == CREATE_CACHE_ENTRY ? replacementWay : 0;
	assign CacheRequest.tag = addressTag;

	assign MemoryRequest.valid = 	(state == SEND_REQ_TO_MEM) 	| 
									(state == WAIT_MEM_RESP) 	| 
									(state == SEND_WT_TO_MEM) 	| 
									(state == WAIT_WT_RESP);
	assign MemoryRequest.address = CPURequest.address;
	assign MemoryRequest.wen = (state == SEND_WT_TO_MEM) | (state == WAIT_WT_RESP);
	assign MemoryRequest.data = CPURequest.data;	// In case of a write back, we need to get this data from the Cache itself
	assign MemoryRequest.strobe = CPURequest.strobe;	// In case of a write back, we need to make all the bits 1

	always_comb begin
		for(int i = 0; i < cache_pkg::WAYS; i++) begin
			CacheRequest.validDirty[i] = 2'b00;
			if(replacementWay[i] == 1'b1)
				CacheRequest.validDirty[i] = 2'b01;	// 0th bit is valid
		end
	end

	// Logging
`ifdef LOGGING
	always_ff @(posedge clk)
		case(state)
			READ_HIT: $display("[Read Hit] Address: 0x%x", CPURequest.address);
			WRITE_HIT: $display("[Write Hit] Address: 0x%x\tData: 0x%x", CPURequest.address, CPURequest.data);
			READ_MISS: $display("[Read Miss] Address: 0x%x", CPURequest.address);
			WRITE_MISS: $display("[Write Miss] Address: 0x%x\tData: 0x%x", CPURequest.address, CPURequest.data);
		endcase

`endif
	
endmodule 
