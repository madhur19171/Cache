`timescale 1ns / 1ps


module TagComparator  #(
		parameter ADDRESS_WIDTH = 32, 
		parameter SETS = 1024, 
		parameter WAYS = 2, 
		parameter CACHE_LINE_SIZE = 32,
		parameter TAG_WIDTH = ADDRESS_WIDTH - ($clog2(SETS) + $clog2(CACHE_LINE_SIZE / 8))
		)
	(
	    input clk,
	    input rst,
		input [TAG_WIDTH - 1 : 0] tag_in [WAYS - 1 : 0],
		input [1 : 0] [WAYS - 1 : 0] valid_dirty,
		input [ADDRESS_WIDTH - 1 : 0] address_in,
		
		output reg [WAYS - 1 : 0] hitVector,
		output reg [$clog2(WAYS) - 1 : 0] selectLine
	);
	
		wire [TAG_WIDTH - 1 : 0] addressTag;
		
		assign addressTag = address_in[ADDRESS_WIDTH - 1 -: TAG_WIDTH];
	
		always_ff @(posedge clk) begin:HIT_VECTOR_GENERATION
			for(int i = 0; i < WAYS; i++) begin
				if(addressTag == tag_in[i] & (valid_dirty[i][0] == 1))
					hitVector[i] = 1;
				else 
					hitVector[i] = 0;
			end
		end
		
		always_ff @(posedge clk) begin:SELECT_LINE_GENERATION
			selectLine = 0;
			for(int i = 0; i < WAYS; i++) begin
				if((addressTag == tag_in[i]) & (valid_dirty[i][0] == 1))
					selectLine = i;
			end
		end
	
endmodule

module PhysicalCache import interface_pkg::*; import cache_pkg::*;
	(
		input clk,
		input rst,
		
		// CPU Interface
		input CPU_Request CPURequest,
		output CPU_Response CPUResponse,

		// Memory Interface
		output Memory_Request MemoryRequest,
		input Memory_Response MemoryResponse
	);
	
	wire [CACHE_LINE_SIZE - 1 : 0] data_out_way [WAYS - 1 : 0];
	wire [TAG_WIDTH - 1 : 0] tag_out_way [WAYS - 1 : 0];
	
	wire [WAYS - 1 : 0] hitVector;
	wire [$clog2(WAYS) - 1 : 0] selectLine;
	
	Cache_Request CacheRequest; 

	Cache_Response CacheResponse;
	
	
	CacheController cahceController_inst(
		.clk(clk),
		.rst(rst),
		
		// From CPU
		.CPURequest(CPURequest),
		//To CPU
		.CPUResponse(CPUResponse),

		// To Memory
		.MemoryRequest(MemoryRequest),

		//From Memory
		.MemoryResponse(MemoryResponse),
		
		// From Cache
		.CacheResponse(CacheResponse),
		
		// From Tag Comparator
		.fromTagComparatorHitVector(hitVector),
		
		// To Cache
		.CacheRequest(CacheRequest)
		);
	
	CacheMemory #(.ADDRESS_WIDTH(ADDRESS_WIDTH), .SETS(SETS), .WAYS(WAYS), .CACHE_LINE_SIZE(CACHE_LINE_SIZE), .TAG_WIDTH(TAG_WIDTH)) cacheMemory
		(
			.clk(clk),
			.rst(rst),
			
			//From Controller
			.CacheRequest(CacheRequest),
			
			// Bad design Choice to not club these into Cache Response. But just make it work for now.
			//To Cache Controller
			.valid_dirty_out(CacheResponse.validDirty),
			// To Data Select
			.data_out(data_out_way),
			//To Tag Comparator
			.tag_out(tag_out_way)
		);
		
	TagComparator #(.ADDRESS_WIDTH(ADDRESS_WIDTH), .SETS(SETS), .WAYS(WAYS), .CACHE_LINE_SIZE(CACHE_LINE_SIZE), .TAG_WIDTH(TAG_WIDTH)) tagComparator
		(
		    .clk(clk),
		    .rst(rst),
		    
			// From Cache
			.tag_in(tag_out_way),
			.valid_dirty(CacheResponse.validDirty),
			
			// From Controller
			.address_in(CacheRequest.address),
			
			// To Cache Controller
			.hitVector(hitVector),
			
			// To Data select
			.selectLine(selectLine)
		);
		
	
	//Multiplexer
	assign CacheResponse.data = data_out_way[selectLine];

	//to cache controller
 
endmodule
