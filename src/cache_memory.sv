`timescale 1ns / 1ps


// SRAM Array has a 1 clock cycle latency between request and response
module SRAMArray #(
		parameter ENTRIES = 1024, 
		parameter DATA_SIZE = 32
		) (
	input clk,
	input rst,
	input [$clog2(ENTRIES) - 1 : 0] address,
	input [DATA_SIZE - 1 : 0]data_in,
	output reg [DATA_SIZE - 1 : 0] data_out,
	input req,
	input wen
);

	reg [DATA_SIZE - 1 : 0] RAM [ENTRIES - 1 : 0];

	initial begin
		for(int i = 0; i < ENTRIES; i++)
			RAM[i] = 0;
	end

	always@(posedge clk) begin
		if(rst)
			data_out <= 0;
		else if(req & ~wen)
			data_out <= RAM[address];
	end
	
	always@(posedge clk)
		if(req & wen) begin
			RAM[address] <= data_in;
		end
endmodule

// SRAM Array has a 1 clock cycle latency between request and response
// This SRAM has a strobe signal for Data Array
module SRAMArrayStrobed #(
		parameter ENTRIES = 1024, 
		parameter DATA_SIZE = 32
		) (
	input clk,
	input rst,
	input [$clog2(ENTRIES) - 1 : 0] address,
	input [DATA_SIZE - 1 : 0]data_in,
	output reg [DATA_SIZE - 1 : 0] data_out,
	input req,
	input [(DATA_SIZE / 8) - 1 : 0] strobe,
	input wen
);

	reg [DATA_SIZE - 1 : 0] RAM [ENTRIES - 1 : 0];

	initial begin
		for(int i = 0; i < ENTRIES; i++)
			RAM[i] = 0;
	end

	always@(posedge clk) begin
		if(rst)
			data_out <= 0;
		else if(req & ~wen)
			data_out <= RAM[address];
	end
	
	always@(posedge clk)
		if(req & wen) begin
			for(int i = 0; i < (DATA_SIZE / 8); i++) begin
				if(strobe[i] == 1) begin
					RAM[address][i * 8 +: 8] <= data_in[i * 8 +: 8];
				end
			end
		end
endmodule

module WayBlock #(
		parameter ADDRESS_WIDTH = 32, 
		parameter SETS = 1024, 
		parameter WAYS = 2, 
		parameter CACHE_LINE_SIZE = 32,
		parameter TAG_WIDTH = ADDRESS_WIDTH - ($clog2(SETS) + $clog2(CACHE_LINE_SIZE / 8))
		) (
	input clk,
	input rst,
	input [ADDRESS_WIDTH - 1 : 0] address,
	input [CACHE_LINE_SIZE - 1 : 0]data_in,
	input [(CACHE_LINE_SIZE / 8) - 1 : 0] strobe,
	output [1 : 0] valid_dirty_out,   // 0th bit is Valid, 1st bit is Dirty
	output [CACHE_LINE_SIZE - 1 : 0] data_out,
	input [1 : 0] valid_dirty_in,
	input req,
	input wen_data,
	input wen_tag,
	
	output [TAG_WIDTH - 1 : 0]tag_out,
	input [TAG_WIDTH - 1 : 0]tag_in
);

	localparam offset_bits = $clog2(CACHE_LINE_SIZE / 8);
	localparam set_bits = $clog2(SETS);
	
	wire [set_bits - 1 : 0] set_address;
	
	assign set_address = address[offset_bits +: set_bits];


	// SRAM Array has a 1 clock cycle latency between request and response
	SRAMArray #(.ENTRIES(SETS), .DATA_SIZE(2)) valid_dirty_array (
		.clk(clk),
		.rst(rst),
		.address(set_address),
		.data_in(valid_dirty_in),
		.data_out(valid_dirty_out),
		.req(req),
		.wen(wen_tag)
	);
	
	SRAMArray #(.ENTRIES(SETS), .DATA_SIZE(TAG_WIDTH)) tag_array (
		.clk(clk),
		.rst(rst),
		.address(set_address),
		.data_in(tag_in),
		.data_out(tag_out),
		.req(req),
		.wen(wen_tag)
	);
	
	SRAMArrayStrobed #(.ENTRIES(SETS), .DATA_SIZE(CACHE_LINE_SIZE)) data_array (
		.clk(clk),
		.rst(rst),
		.address(set_address),
		.data_in(data_in),
		.data_out(data_out),
		.req(req),
		.wen(wen_data),
		.strobe(strobe)
	);
	
	

endmodule

module CacheMemory #(
		parameter ADDRESS_WIDTH = 32, 
		parameter SETS = 1024, 
		parameter WAYS = 2, 
		parameter CACHE_LINE_SIZE = 32, 
		parameter TAG_WIDTH = ADDRESS_WIDTH - ($clog2(SETS) + $clog2(CACHE_LINE_SIZE / 8))
		) (
	input clk,
	input rst,
	input req,
	input [ADDRESS_WIDTH - 1 : 0] address,
	input [CACHE_LINE_SIZE - 1 : 0]data_in,
	input [(CACHE_LINE_SIZE / 8) - 1 : 0] strobe,
	output reg [CACHE_LINE_SIZE - 1 : 0] data_out [WAYS - 1 : 0],
	output [1 : 0] valid_dirty_out [WAYS - 1 : 0],

	input [1 : 0] valid_dirty_in [WAYS - 1 : 0],
	input [WAYS - 1 : 0] wen_data,
	input [WAYS - 1 : 0] wen_tag,
	
	output [TAG_WIDTH - 1 : 0]tag_out [WAYS - 1 : 0],
	input [TAG_WIDTH - 1 : 0]tag_in
);

	genvar i;
	generate 
		for(i = 0; i < WAYS; i++) begin: WAY_BLOCK_GENERATOR
			WayBlock #(.ADDRESS_WIDTH(ADDRESS_WIDTH), .SETS(SETS), .WAYS(WAYS), .CACHE_LINE_SIZE(CACHE_LINE_SIZE), .TAG_WIDTH(TAG_WIDTH)) way_block_inst
				(.clk(clk),
				.rst(rst),
				
				.address(address),
				
				.valid_dirty_in(valid_dirty_in[i]),
				.data_in(data_in),
				.strobe(strobe),
				.valid_dirty_out(valid_dirty_out[i]),
				.data_out(data_out[i]),
				
				.req(req),
				
				.wen_data(wen_data[i]),
				.wen_tag(wen_tag[i]),
				
				.tag_in(tag_in),
				.tag_out(tag_out[i])
			);
		end
	endgenerate

endmodule

