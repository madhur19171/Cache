module ReplacementLogic #(parameter WAYS = 4)(
	input clk,
	input rst,

	input [WAYS - 1 : 0] ValidWays,

	output [WAYS - 1  : 0] replacementWay

);

	wire [7 : 0] LFSROut;

	wire allWaysValid;  // High if all the ways are valid

	logic [$clog2(WAYS) - 1 : 0] invalidWayIndex;   // Index of the first Invalid Way
	wire [$clog2(WAYS) - 1 : 0] replacementWayIndex; // Index of the way to be replaced

	assign allWaysValid = &ValidWays;
	assign replacementWay = 1 << replacementWayIndex;

	// If all the ways are valid, then use the LFSR to choose a random way to replace.
	// If all the ways are not valid, then choose the first invalid way to be replaced.
	assign replacementWayIndex = allWaysValid ? LFSROut[0 +: $clog2(WAYS)] : invalidWayIndex;
 
	LFSR #(.STAGES(8), .INIT(1)) lfsr_8bit (.clk(clk), .rst(rst), .LFSROut(LFSROut));

	// Generating Invalid Way Index
	always_comb begin
		invalidWayIndex = 0;
		for(int i = 0; i < WAYS; i++)
			if(ValidWays[i] == 0)
				invalidWayIndex = i;
	end

endmodule