`timescale 1ns / 1ps

module Memory #(
		parameter ADDRESS_WIDTH = 32,
		parameter LINE_SIZE = 32,
		parameter ENTRIES = 1024,
		parameter DELAY = 4)
	(input clk,
	input rst,
	
	input reqValid,
	input [ADDRESS_WIDTH - 1 : 0] reqAddress,
	input [LINE_SIZE -1 : 0]reqDataIn,
	input reqWen,
	input [(LINE_SIZE / 8) -1 : 0] reqStrobe,
	//From Memory
	output logic respValid,
	output logic [LINE_SIZE - 1 : 0] respDataOut
	);

	reg [LINE_SIZE - 1 : 0] RAM [0 : ENTRIES - 1];
	
	integer counter;

    initial begin
//	   $readmemh("RAM.mem", RAM);
    for(int i = 0; i < ENTRIES; i++)
        RAM[i] = 0;
	end
	
	always_ff @(posedge clk) begin 
	   if(rst)
	       counter <= 0;
	   else if(counter == DELAY)
	       counter <= 0;
	   else if(counter != 0)
	       counter++;
	   else if(reqValid)
	       counter <= 1;
	end

	always_ff @(posedge clk) begin
		if(rst)
			respValid <= 0;
		else if(reqValid & respValid)
			respValid <= 0; // If the request is served, deassert response
		else if(reqValid & counter == (DELAY - 1))
			respValid <= 1;
	end

	always_ff @(posedge clk) begin
		if(rst)
			respDataOut <= 0;
		else if(reqValid & reqWen) begin
			for(int i = 0; i < (LINE_SIZE / 8); i++) begin
				if(reqStrobe[i] == 1) begin
					RAM[reqAddress[ADDRESS_WIDTH - 1 : 2]][i * 8 +: 8] <= reqDataIn[i * 8 +: 8];
				end
			end
		end
		else if(reqValid)
			respDataOut <= RAM[reqAddress[ADDRESS_WIDTH - 1 : 2]];
	end

endmodule