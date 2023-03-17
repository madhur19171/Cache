`timescale 1ns / 1ps

module MemorySystem import interface_pkg::*;
(input clk, input rst,
					// From CPU
					input CPU_Request CPURequest,
					//To CPU
					output CPU_Response CPUResponse
				); 
				
	Memory_Request MemoryRequest;
	Memory_Response MemoryResponse;
	

	PhysicalCache PhysicalCache_inst 
	(   .clk(clk), .rst(rst),

		// From CPU
		.CPURequest(CPURequest),
		//To CPU
		.CPUResponse(CPUResponse),

		// To Memory
		.MemoryRequest(MemoryRequest),

		//From Memory
		.MemoryResponse(MemoryResponse)
	);

	Memory Memory_inst
	(
		.clk(clk), .rst(rst),

		// To Memory
		.MemoryRequest(MemoryRequest),

		//From Memory
		.MemoryResponse(MemoryResponse)
	);

endmodule