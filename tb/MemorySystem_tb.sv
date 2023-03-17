`timescale 1ns / 1ps

import interface_pkg::*;

module MemorySystem_tb;

	logic clk, rst;
	
	// CPU Interface
	CPU_Request CPURequest;
	CPU_Response CPUResponse;
	
	MemorySystem MemorySystem_inst (.*);
	
	always #5 clk = ~clk;
	
	initial begin
		clk = 0;
		rst = 1;
		
		CPURequest.valid = 0;
		CPURequest.address = 0;
		CPURequest.data = 0;
		CPURequest.wen = 0;
		CPURequest.strobe = 0;
		
		#10 rst = 0;
	end

	task CacheRead(input [31 : 0] address);
		CPURequest.address = address;
		CPURequest.valid = 1;
		CPURequest.wen = 0;
		CPURequest.data = 32'h00000000;
		wait(CPUResponse.hit)
			#10 CPURequest.valid = 0;
	endtask

	task CacheWrite(input [31 : 0] address, input [31 : 0] data, input [3 : 0] strobe);
		CPURequest.address = address;
		CPURequest.valid = 1;
		CPURequest.wen = 1;
		CPURequest.data = data;
		CPURequest.strobe = strobe;
		wait(CPUResponse.hit)
			#10 CPURequest.valid = 0;
	endtask
	
	initial begin
	
		// Cache Warm up Start
		#50 CacheWrite(32'h00000000, 32'h002342ab, 4'b1111);
		#10 CacheWrite(32'h00000010, 32'h849292bb, 4'b0110);
		#10 CacheWrite(32'h00000020, 32'h19475820, 4'b1111);
		#10 CacheWrite(32'h00000018, 32'h55739084, 4'b1111);
		#10 CacheWrite(32'h00000024, 32'h47390121, 4'b1111);
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

		#100 $finish;
	end
	
	initial begin
		$dumpfile("MemorySystem_tb.vcd");
		$dumpvars(0, MemorySystem_tb); 
	end
	 

endmodule
