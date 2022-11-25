`timescale 1ns / 1ps


module TagComparator  #(
		parameter ADDRESS_WIDTH = 32, 
		parameter SETS = 1024, 
		parameter WAYS = 2, 
		parameter CACHE_LINE_SIZE = 32,
		parameter TAG_WIDTH = ADDRESS_WIDTH - ($clog2(SETS) + $clog2(CACHE_LINE_SIZE / 8))
		)
	(
		input [TAG_WIDTH - 1 : 0] tag_in [WAYS - 1 : 0],
		input [1 : 0] valid_dirty [WAYS - 1 : 0],
		input [ADDRESS_WIDTH - 1 : 0] address_in,
		
		output reg [WAYS - 1 : 0] hitVector,
		output reg [$clog2(WAYS) - 1 : 0] selectLine
	);
	
		wire [TAG_WIDTH - 1 : 0] addressTag;
		
		assign addressTag = address_in[ADDRESS_WIDTH - 1 -: TAG_WIDTH];
	
		always_comb begin:HIT_VECTOR_GENERATION
			for(int i = 0; i < WAYS; i++) begin
				if(addressTag == tag_in[i] & (valid_dirty[i][0] == 1))
					hitVector[i] = 1;
				else 
					hitVector[i] = 0;
			end
		end
		
		always_comb begin:SELECT_LINE_GENERATION
			selectLine = 0;
			for(int i = 0; i < WAYS; i++) begin
				if((addressTag == tag_in[i]) & (valid_dirty[i][0] == 1))
					selectLine = i;
			end
		end
	
endmodule

module PhysicalCache #(
		parameter ADDRESS_WIDTH = 32, 
		parameter SETS = 4, 
		parameter WAYS = 2, 
		parameter CACHE_LINE_SIZE = 32,
		parameter TAG_WIDTH = ADDRESS_WIDTH - ($clog2(SETS) + $clog2(CACHE_LINE_SIZE / 8))
		)
	(
		input clk,
		input rst,
		
		// CPU Interface
		input reqValid_CPU,
		input [ADDRESS_WIDTH - 1 : 0] address_in_CPU,
		input [CACHE_LINE_SIZE - 1 : 0]data_in_CPU,
		input wen_CPU,
		
		output [CACHE_LINE_SIZE - 1 : 0]data_out_CPU,
		output hit_CPU,

		// Memory Interface
		// To Memory
		output reqValid_MEM,
		output [ADDRESS_WIDTH - 1 : 0] reqAddress_MEM,
		output [CACHE_LINE_SIZE -1 : 0]reqDataOut_MEM,
		output reqWen_MEM,
		//From Memory
		input respValid_MEM,
		input [CACHE_LINE_SIZE - 1 : 0] respDataIn_MEM
	);
	
	wire [CACHE_LINE_SIZE - 1 : 0] data_out_way [WAYS - 1 : 0];
	wire [TAG_WIDTH - 1 : 0] tag_out_way [WAYS - 1 : 0];
	
	wire [WAYS - 1 : 0] hitVector;
	wire [$clog2(WAYS) - 1 : 0] selectLine;
	
	wire [ADDRESS_WIDTH - 1 : 0] reqAddress_CPU;
	wire [CACHE_LINE_SIZE - 1 : 0] reqDataIn_CPU;  
	wire reqWen_CPU;
	
	wire [CACHE_LINE_SIZE - 1 : 0] respDataOut_CPU;
	wire respHit_CPU;
	
	wire toCacheReq;
	wire [ADDRESS_WIDTH - 1 : 0] toCacheAddress;
	wire [CACHE_LINE_SIZE - 1 : 0] toCacheData;
	wire [WAYS - 1 : 0] toCacheWenData;
	wire [WAYS - 1 : 0] toCacheWenTag;
	wire [TAG_WIDTH - 1 : 0] toCacheTag;
	
	wire [CACHE_LINE_SIZE - 1 : 0] fromCacheData;
	
	wire [1 : 0] fromCacheValidDirty [WAYS - 1 : 0];
	wire [1 : 0] toCacheValidDirty [WAYS - 1 : 0];
	
	
	
	assign reqAddress_CPU = address_in_CPU;
	assign reqDataIn_CPU = data_in_CPU;
	assign reqWen_CPU = wen_CPU;
	
	assign data_out_CPU = respDataOut_CPU;
	assign hit_CPU = respHit_CPU;
	
	
	CacheController #(.ADDRESS_WIDTH(ADDRESS_WIDTH), .SETS(SETS), .WAYS(WAYS), .CACHE_LINE_SIZE(CACHE_LINE_SIZE), .TAG_WIDTH(TAG_WIDTH)) cahceController_inst(
		.clk(clk),
		.rst(rst),
		
		// From CPU
		.reqValid_CPU(reqValid_CPU),
		.reqAddress_CPU(reqAddress_CPU),
		.reqDataIn_CPU(reqDataIn_CPU),
		.reqWen_CPU(reqWen_CPU),
		//To CPU
		.respDataOut_CPU(respDataOut_CPU),
		.respHit_CPU(respHit_CPU),

		// To Memory
		.reqValid_MEM(reqValid_MEM),
		.reqAddress_MEM(reqAddress_MEM),
		.reqDataOut_MEM(reqDataOut_MEM),
		.reqWen_MEM(reqWen_MEM),

		//From Memory
		.respValid_MEM(respValid_MEM),
		.respDataIn_MEM(respDataIn_MEM),
		
		// From Cache
		.fromCacheData(fromCacheData),
		.fromCacheValidDirty(fromCacheValidDirty),
		
		// From Tag Comparator
		.fromTagComparatorHitVector(hitVector),
		
		// To Cache
		.toCacheReq(toCacheReq),
		.toCacheAddress(toCacheAddress),
		.toCacheData(toCacheData),
		.toCacheWenData(toCacheWenData),
		.toCacheWenTag(toCacheWenTag),
		.toCacheTag(toCacheTag),
		.toCacheValidDirty(toCacheValidDirty)
		);
	
	CacheMemory #(.ADDRESS_WIDTH(ADDRESS_WIDTH), .SETS(SETS), .WAYS(WAYS), .CACHE_LINE_SIZE(CACHE_LINE_SIZE), .TAG_WIDTH(TAG_WIDTH)) cacheMemory
		(
			.clk(clk),
			.rst(rst),
			
			//From Controller
			.req(toCacheReq),
			.address(toCacheAddress),
			.data_in(toCacheData),
			.wen_data(toCacheWenData),
			.wen_tag(toCacheWenTag),
			.tag_in(toCacheTag),
			
			//To Cache Controller
			.valid_dirty_out(fromCacheValidDirty),
			// From Cache Controller
			.valid_dirty_in(toCacheValidDirty),
			
			// To Data Select
			.data_out(data_out_way),
			//To Tag Comparator
			.tag_out(tag_out_way)
		);
		
	TagComparator #(.ADDRESS_WIDTH(ADDRESS_WIDTH), .SETS(SETS), .WAYS(WAYS), .CACHE_LINE_SIZE(CACHE_LINE_SIZE), .TAG_WIDTH(TAG_WIDTH)) tagComparator
		(
			// From Cache
			.tag_in(tag_out_way),
			.valid_dirty(fromCacheValidDirty),
			
			// From Controller
			.address_in(toCacheAddress),
			
			// To Cache Controller
			.hitVector(hitVector),
			
			// To Data select
			.selectLine(selectLine)
		);
		
	
	//Multiplexer
	assign fromCacheData = data_out_way[selectLine];

	//to cache controller
 
endmodule
