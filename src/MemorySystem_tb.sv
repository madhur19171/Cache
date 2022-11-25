`timescale 1ns / 1ps

module MemorySystem_tb;

	logic clk, rst;
	
	// From CPU
	logic reqValid_CPU;
	logic [31 : 0] reqAddress_CPU;
	logic [31 : 0]reqDataIn_CPU;
	logic reqWen_CPU;
	//To CPU
	wire [31 : 0] respDataOut_CPU;    // Connect to from cache data
	wire respHit_CPU;
	
	MemorySystem MemorySystem_inst (.*);
	
	always #5 clk = ~clk;
	
	initial begin
		clk = 0;
		rst = 1;
		
		reqValid_CPU = 0;
		reqAddress_CPU = 0;
		reqDataIn_CPU = 0;
		reqWen_CPU = 0;
		
		#10 rst = 0;
	end

	task CacheRead(input [31 : 0] address);
		reqAddress_CPU = address;
		reqValid_CPU = 1;
		reqWen_CPU = 0;
		reqDataIn_CPU = 32'h00000000;
		wait(respHit_CPU)
			#10 reqValid_CPU = 0;
	endtask

	task CacheWrite(input [31 : 0] address, input [31 : 0] data);
		reqAddress_CPU = address;
		reqValid_CPU = 1;
		reqWen_CPU = 1;
		reqDataIn_CPU = data;
		wait(respHit_CPU)
			#10 reqValid_CPU = 0;
	endtask
	
	initial begin
	
		// Cache Warm up Start
		#50 CacheWrite(32'h00000000, 32'h002342ab);
		#10 CacheWrite(32'h00000010, 32'h849292bb);
		#10 CacheWrite(32'h00000020, 32'h19475820);
		#10 CacheWrite(32'h00000018, 32'h55739084);
		#10 CacheWrite(32'h00000024, 32'h47390121);
		// Cache Warm up End

		// Testing Replacement Start
		#10 CacheRead(32'h00000000);
		#10 CacheRead(32'h00000010);
		#10 CacheRead(32'h00000000);
		#10 CacheRead(32'h00000010);
		#10 CacheRead(32'h00000020);
		#10 CacheRead(32'h00000030);
		// Testing Repalcement Ends
			
		#10 CacheRead(32'h00000004);
		#10 CacheRead(32'h00000008);
		#10 CacheRead(32'h0000000C);
		#10 CacheRead(32'h00000010);
		#10 CacheRead(32'h00000000);
	end
	 

endmodule