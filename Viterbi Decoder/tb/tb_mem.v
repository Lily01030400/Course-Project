`timescale 1ns / 1ps

module memory_tb;

    // Inputs
    reg clk;
    reg rst;
    reg en_mem;
    reg [1:0] prev_st_00;
    reg [1:0] prev_st_10;
    reg [1:0] prev_st_01;
    reg [1:0] prev_st_11;
    
    // Outputs
    wire [1:0] bck_prev_st_00;
    wire [1:0] bck_prev_st_10;
    wire [1:0] bck_prev_st_01;
    wire [1:0] bck_prev_st_11;
    
    // Instantiate the Unit Under Test (UUT)
    memory uut (
        .clk(clk),
        .rst(rst),
        .en_mem(en_mem),
        .prev_st_00(prev_st_00),
        .prev_st_10(prev_st_10),
        .prev_st_01(prev_st_01),
        .prev_st_11(prev_st_11),
        .bck_prev_st_00(bck_prev_st_00),
        .bck_prev_st_10(bck_prev_st_10),
        .bck_prev_st_01(bck_prev_st_01),
        .bck_prev_st_11(bck_prev_st_11)
    );
    
    // Clock generation - 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test sequence
    initial begin
        // Initialize inputs
        rst = 0;
        en_mem = 0;
        prev_st_00 = 2'b00;
        prev_st_10 = 2'b00;
        prev_st_01 = 2'b00;
        prev_st_11 = 2'b00;
        
        // Apply reset
        #10;
        rst = 1;
        #10;
        
        // Start memory operation
        en_mem = 1;
        
        // Write mode - 8 cycles (count 0 to 7)
        // Cycle 0 (D0)
        @(posedge clk);
        prev_st_00 = 2'b00;
        prev_st_10 = 2'b00;
        prev_st_01 = 2'b00;
        prev_st_11 = 2'b00;
        
        // Cycle 1 (D1)
        @(posedge clk);
        prev_st_00 = 2'b01;
        prev_st_10 = 2'b01;
        prev_st_01 = 2'b01;
        prev_st_11 = 2'b01;
        
        // Cycle 2 (D2)
        @(posedge clk);
        prev_st_00 = 2'b10;
        prev_st_10 = 2'b10;
        prev_st_01 = 2'b10;
        prev_st_11 = 2'b10;
        
        // Cycle 3 (D3)
        @(posedge clk);
        prev_st_00 = 2'b11;
        prev_st_10 = 2'b11;
        prev_st_01 = 2'b11;
        prev_st_11 = 2'b11;
        
        // Cycle 4 (D4)
        @(posedge clk);
        prev_st_00 = 2'b00;
        prev_st_10 = 2'b00;
        prev_st_01 = 2'b00;
        prev_st_11 = 2'b00;
        
        // Cycle 5 (D5)
        @(posedge clk);
        prev_st_00 = 2'b01;
        prev_st_10 = 2'b01;
        prev_st_01 = 2'b01;
        prev_st_11 = 2'b01;
        
        // Cycle 6 (D6)
        @(posedge clk);
        prev_st_00 = 2'b10;
        prev_st_10 = 2'b10;
        prev_st_01 = 2'b10;
        prev_st_11 = 2'b10;
        
        // Cycle 7 (D7)
        @(posedge clk);
        prev_st_00 = 2'b11;
        prev_st_10 = 2'b11;
        prev_st_01 = 2'b11;
        prev_st_11 = 2'b11;
        
        // Now count = 8, enter read mode
        // The outputs should start showing O7, O6, O5, O4, O3, O2...
        
        // Wait for read cycles
        repeat(8) @(posedge clk);
        
        // End simulation
        #20;
        $display("Simulation completed successfully!");
        $finish;
    end
    
    // Monitor for debugging
    initial begin
        $monitor("Time=%0t rst=%b en_mem=%b | IN: prev_st_00=%b prev_st_10=%b prev_st_01=%b prev_st_11=%b | OUT: bck_prev_st_00=%b bck_prev_st_10=%b bck_prev_st_01=%b bck_prev_st_11=%b", 
                 $time, rst, en_mem, prev_st_00, prev_st_10, prev_st_01, prev_st_11, 
                 bck_prev_st_00, bck_prev_st_10, bck_prev_st_01, bck_prev_st_11);
    end

endmodule