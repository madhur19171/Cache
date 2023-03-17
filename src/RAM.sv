`timescale 1ns / 1ps

module Memory import interface_pkg::*; import memory_pkg::*;
	(input clk,
	input rst,
	
	input Memory_Request MemoryRequest,
	output Memory_Response MemoryResponse
	);

	logic [MEMORY_BUS_WIDTH - 1 : 0] RAM [0 : ENTRIES - 1] = '{default:0};
	
	logic [2 : 0] counter;

// 	initial begin
// //	   $readmemh("RAM.mem", RAM);
// 	// for(int i = 0; i < ENTRIES; i++)
// 		RAM[i] = 0;
// 	end
	
	always_ff @(posedge clk) begin 
		if(rst)
			counter <= 0;
		else if(counter == DELAY)
			counter <= 0;
		else if(counter != 0)
			counter++;
		else if(MemoryRequest.valid)
			counter <= 1;
	end

	always_ff @(posedge clk) begin
		if(rst)
			MemoryResponse.valid <= 0;
		else if(MemoryRequest.valid & MemoryResponse.valid)
			MemoryResponse.valid <= 0; // If the request is served, deassert response
		else if(MemoryRequest.valid & counter == (DELAY - 1))
			MemoryResponse.valid <= 1;
	end

	always_ff @(posedge clk) begin
		if(rst)
			MemoryResponse.data <= 0;
		else if(MemoryRequest.valid & MemoryRequest.wen) begin
			for(int i = 0; i < STROBE_WIDTH; i++) begin
				if(MemoryRequest.strobe[i] == 1) begin
					RAM[MemoryRequest.address[ADDRESS_WIDTH - 1 : 2]][i * 8 +: 8] <= MemoryRequest.data[i * 8 +: 8];
				end
			end
		end
		else if(MemoryRequest.valid)
			MemoryResponse.data <= RAM[MemoryRequest.address[ADDRESS_WIDTH - 1 : 2]];
	end

endmodule