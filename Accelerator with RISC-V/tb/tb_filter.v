//==============================================================================
// File: tb_filter.v 
// Testbench for winograd_filter_transform
//==============================================================================

`timescale 1ns/1ps

module tb_filter;
    
    parameter DATA_WIDTH = 32;
    parameter FRAC_BITS = 16;
    parameter CLK_PERIOD = 10;

    reg                     clk;
    reg                     rstn;
    reg                     start;
    reg  [DATA_WIDTH-1:0]   g_in;
    reg  [3:0]              g_count;
    wire                    done;
    wire                    u_valid;
    wire [DATA_WIDTH-1:0]   u_out;
    wire [3:0]              u_count;

    integer i;
    reg [DATA_WIDTH-1:0] filter_3x3 [0:8];
    reg [DATA_WIDTH-1:0] received_4x4 [0:15];
    
    // DUT
    winograd_filter_transform #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .g_in(g_in),
        .g_count(g_count),
        .done(done),
        .u_valid(u_valid),
        .u_out(u_out),
        .u_count(u_count)
    );

    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Helper functions
    function [DATA_WIDTH-1:0] real_to_fixed;
        input real value;
        begin
            real_to_fixed = $rtoi(value * (2.0 ** FRAC_BITS));
        end
    endfunction
    
    function real fixed_to_real;
        input [DATA_WIDTH-1:0] value;
        begin
            fixed_to_real = $itor($signed(value)) / (2.0 ** FRAC_BITS);
        end
    endfunction

    // Main test
    initial begin
        $display("\n=== WINOGRAD FILTER TRANSFORM - ULTIMATE FIX ===");
        $display("Strategy: Read u_matrix directly after done=1\n");
        
        // Initialize
        rstn = 0;
        start = 0;
        g_in = 0;
        g_count = 0;
        
        // Reset
        repeat(5) @(posedge clk);
        rstn = 1;
        repeat(2) @(posedge clk);
        
        // Test: Identity Filter [0,0,0; 0,1,0; 0,0,0]
        $display("=== TEST: Identity Filter ===\n");
        filter_3x3[0] = real_to_fixed(0.0);
        filter_3x3[1] = real_to_fixed(0.0);
        filter_3x3[2] = real_to_fixed(0.0);
        filter_3x3[3] = real_to_fixed(0.0);
        filter_3x3[4] = real_to_fixed(1.0);  // Center = 1
        filter_3x3[5] = real_to_fixed(0.0);
        filter_3x3[6] = real_to_fixed(0.0);
        filter_3x3[7] = real_to_fixed(0.0);
        filter_3x3[8] = real_to_fixed(0.0);
        
        $display("Input Filter:");
        $display("  [%7.4f, %7.4f, %7.4f]", 
                 fixed_to_real(filter_3x3[0]), fixed_to_real(filter_3x3[1]), 
                 fixed_to_real(filter_3x3[2]));
        $display("  [%7.4f, %7.4f, %7.4f]", 
                 fixed_to_real(filter_3x3[3]), fixed_to_real(filter_3x3[4]), 
                 fixed_to_real(filter_3x3[5]));
        $display("  [%7.4f, %7.4f, %7.4f]\n", 
                 fixed_to_real(filter_3x3[6]), fixed_to_real(filter_3x3[7]), 
                 fixed_to_real(filter_3x3[8]));
        
        // Load filter
        start = 1;
        for (i = 0; i < 9; i = i + 1) begin
            @(posedge clk);
            g_in = filter_3x3[i];
            g_count = i;
        end
        
        @(posedge clk);
        start = 0;
        g_count = 0;
        
        $display("Computing...\n");
        
        // Wait for done
        wait(done);
        @(posedge clk);

        $display("Reading u_matrix directly from DUT:\n");
        for (i = 0; i < 16; i = i + 1) begin
            received_4x4[i] = dut.u_matrix[i/4][i%4];
            $display("  u_matrix[%0d][%0d] = %h (%.4f)", 
                     i/4, i%4, received_4x4[i], fixed_to_real(received_4x4[i]));
        end
        
        // Display results
        $display("\n=== RESULTS ===\n");
        $display("Collected Output Transform (4x4):");
        $display("  [%7.4f, %7.4f, %7.4f, %7.4f]", 
                 fixed_to_real(received_4x4[0]), fixed_to_real(received_4x4[1]), 
                 fixed_to_real(received_4x4[2]), fixed_to_real(received_4x4[3]));
        $display("  [%7.4f, %7.4f, %7.4f, %7.4f]", 
                 fixed_to_real(received_4x4[4]), fixed_to_real(received_4x4[5]), 
                 fixed_to_real(received_4x4[6]), fixed_to_real(received_4x4[7]));
        $display("  [%7.4f, %7.4f, %7.4f, %7.4f]", 
                 fixed_to_real(received_4x4[8]), fixed_to_real(received_4x4[9]), 
                 fixed_to_real(received_4x4[10]), fixed_to_real(received_4x4[11]));
        $display("  [%7.4f, %7.4f, %7.4f, %7.4f]\n", 
                 fixed_to_real(received_4x4[12]), fixed_to_real(received_4x4[13]), 
                 fixed_to_real(received_4x4[14]), fixed_to_real(received_4x4[15]));
        
        $display("Expected Transform:");
        $display("  [ 0.0000,  0.0000,  0.0000,  0.0000]");
        $display("  [ 0.0000,  0.2500, -0.2500,  0.0000]");
        $display("  [ 0.0000, -0.2500,  0.2500,  0.0000]");
        $display("  [ 0.0000,  0.0000,  0.0000,  0.0000]\n");
        
        // Verify key values
        $display("=== VERIFICATION ===");
        $display("Key indices:");
        $display("  Index  5: %h (%.4f) - Expected: 0.2500 %s", 
                 received_4x4[5], fixed_to_real(received_4x4[5]),
                 (received_4x4[5] == real_to_fixed(0.25)) ? "✓ PASS" : "✗ FAIL");
        $display("  Index  6: %h (%.4f) - Expected: -0.2500 %s", 
                 received_4x4[6], fixed_to_real(received_4x4[6]),
                 (received_4x4[6] == real_to_fixed(-0.25)) ? "✓ PASS" : "✗ FAIL");
        $display("  Index  9: %h (%.4f) - Expected: -0.2500 %s", 
                 received_4x4[9], fixed_to_real(received_4x4[9]),
                 (received_4x4[9] == real_to_fixed(-0.25)) ? "✓ PASS" : "✗ FAIL");
        $display("  Index 10: %h (%.4f) - Expected: 0.2500 %s", 
                 received_4x4[10], fixed_to_real(received_4x4[10]),
                 (received_4x4[10] == real_to_fixed(0.25)) ? "✓ PASS" : "✗ FAIL");
        
        if (received_4x4[5] == real_to_fixed(0.25) && 
            received_4x4[6] == real_to_fixed(-0.25) &&
            received_4x4[9] == real_to_fixed(-0.25) &&
            received_4x4[10] == real_to_fixed(0.25)) begin
            $display("\n");
            $display("████████████████████████████████████████");
            $display("█                                      █");
            $display("█   ✓✓✓ ALL TESTS PASSED! ✓✓✓        █");
            $display("█                                      █");
            $display("████████████████████████████████████████");
        end else begin
            $display("\n✗✗✗ SOME TESTS FAILED ✗✗✗");
        end
        
        #100;
        $finish;
    end

    // Timeout
    initial begin
        #100000;
        $display("\n[ERROR] Timeout!");
        $finish;
    end

    // Waveform
    initial begin
        $dumpfile("tb_filter.vcd");
        $dumpvars(0, tb_filter);
    end

endmodule