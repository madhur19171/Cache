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
     
        // Cache Warm up Start
        #50;
        reqAddress_CPU = 32'h00000000;
        reqValid_CPU = 1;
        reqWen_CPU = 1;
        reqDataIn_CPU = 32'h002342ab;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000010;
        reqValid_CPU = 1;
        reqWen_CPU = 1;
        reqDataIn_CPU = 32'h849292bb;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000020;
        reqValid_CPU = 1;
        reqWen_CPU = 1;
        reqDataIn_CPU = 32'h19475820;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000018;
        reqValid_CPU = 1;
        reqWen_CPU = 1;
        reqDataIn_CPU = 32'h55739084;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000024;
        reqValid_CPU = 1;
        reqWen_CPU = 1;
        reqDataIn_CPU = 32'h47390121;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        // Cache Warm up End
        
        reqWen_CPU = 0;
        reqDataIn_CPU = 32'h00000000;
        
        // Testing Replacement Start
        #10;
        reqAddress_CPU = 32'h00000000;
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
            
        #10;
        reqAddress_CPU = 32'h00000010;
        reqValid_CPU = 1;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000020;
        reqValid_CPU = 1;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        #10;
        reqAddress_CPU = 32'h00000030;
        reqValid_CPU = 1;
        wait(respHit_CPU)
            #10 reqValid_CPU = 0;
            
        // Testing Repalcement Ends
            
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