`timescale 1ns / 1ps

module MemorySystem (input clk, input rst,
                    // From CPU
                    input reqValid_CPU,
                    input [31 : 0] reqAddress_CPU,
                    input [31 : 0]reqDataIn_CPU,
                    input reqWen_CPU,
                    //To CPU
                    output [31 : 0] respDataOut_CPU,    // Connect to from cache data
                    output respHit_CPU
                ); 
                
    wire [31 : 0] reqAddress_MEM, reqDataOut_MEM, respDataIn_MEM;
    wire reqWen_MEM, respValid_MEM, reqValid_MEM;
    

    PhysicalCache PhysicalCache_inst 
    (   .clk(clk), .rst(rst),

        .reqValid_CPU(reqValid_CPU),
        .address_in_CPU(reqAddress_CPU),
        .data_in_CPU(reqDataIn_CPU),
        .wen_CPU(reqWen_CPU),
        
        .data_out_CPU(respDataOut_CPU),
        .hit_CPU(respHit_CPU),

        .reqValid_MEM(reqValid_MEM),
        .reqAddress_MEM(reqAddress_MEM),
        .reqDataOut_MEM(reqDataOut_MEM),
        .reqWen_MEM(reqWen_MEM),

        .respValid_MEM(respValid_MEM),
        .respDataIn_MEM(respDataIn_MEM)
    );

    Memory Memory_inst
    (
        .clk(clk), .rst(rst),

        .reqValid(reqValid_MEM),
        .reqAddress(reqAddress_MEM),
        .reqDataIn(reqDataOut_MEM),
        .reqWen(reqWen_MEM),

        .respValid(respValid_MEM),
        .respDataOut(respDataIn_MEM)
    );

endmodule