// Galois LFSR Implementation for high clock rate
// Reference: http://rdsl.csit-sun.pub.ro/docs/PROIECTARE%20cu%20FPGA%20CURS/lecture6[1].pdf
module LFSR #(parameter STAGES = 8, parameter INIT = 1)(
	input clk, input rst,
	output [STAGES - 1 : 0] LFSROut
);

	logic [STAGES - 1 : 0] Q = INIT, D = 0;

	always_ff @(posedge clk) begin
		if(rst)
			Q <= INIT;
		else 
			Q <= D;
	end

	always_comb begin
		D[STAGES - 1] = Q[0];
		for(int i = STAGES - 2; i >= 0; i--)
			if(i % 2 == 0)
				D[i] = Q[i + 1] ^ Q[0];
			else
				D[i] = Q[i + 1];
	end
	
	assign LFSROut = Q;

endmodule