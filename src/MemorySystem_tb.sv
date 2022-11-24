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
     
     initial begin
        #50;
        reqAddress_CPU = 32'h00000000;
        reqValid_CPU = 1;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000004;
        reqValid_CPU = 1;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000008;
        reqValid_CPU = 1;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h0000000c;
        reqValid_CPU = 1;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000010;
        reqValid_CPU = 1;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000000;
        reqValid_CPU = 1;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
     end
     

endmodule