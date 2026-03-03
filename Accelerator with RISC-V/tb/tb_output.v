// Testbench for winograd_output_transform

`timescale 1ns/1ps

module tb_output;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 10ns = 100MHz
    
    // Signals
    reg                     clk;
    reg                     rstn;
    reg                     start;
    reg  [DATA_WIDTH-1:0]   m_in;
    reg  [3:0]              m_count;
    wire                    done;
    wire [DATA_WIDTH-1:0]   y_out;
    wire [1:0]              y_count;
    
    // Test data storage
    reg [DATA_WIDTH-1:0] test_m [0:15];
    reg [DATA_WIDTH-1:0] expected_output [0:3];
    reg [DATA_WIDTH-1:0] actual_output [0:3];
    integer output_idx;
    integer i, errors;
    integer test_num;
    
    // DUT instantiation
    winograd_output_transform #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .m_in(m_in),
        .m_count(m_count),
        .done(done),
        .y_out(y_out),
        .y_count(y_count)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Helper function: Convert real to fixed-point Q16.16
    function [DATA_WIDTH-1:0] real_to_fp;
        input real val;
        integer temp_int;
        begin
            temp_int = val * 65536.0;
            real_to_fp = temp_int;
        end
    endfunction
    
    // Helper function: Convert fixed-point to real (for display only)
    function real fp_to_real;
        input [DATA_WIDTH-1:0] fp_val;
        begin
            fp_to_real = $itor($signed(fp_val)) / 65536.0;
        end
    endfunction
    
    // Task: Apply reset
    task apply_reset;
        begin
            rstn = 0;
            start = 0;
            m_in = 0;
            m_count = 0;
            #(CLK_PERIOD * 2);
            rstn = 1;
            #(CLK_PERIOD);
            $display("[%0t] Reset completed", $time);
        end
    endtask
    
    // Task: Load M matrix (4x4)
    task load_m_matrix;
        begin
            $display("[%0t] Loading M matrix...", $time);
            start = 1;
            #(CLK_PERIOD);
            start = 0;
            
            for (i = 0; i < 16; i = i + 1) begin
                m_count = i;
                m_in = test_m[i];
                #(CLK_PERIOD);
                $display("  M[%0d][%0d] = %f (0x%h)", i/4, i%4, 
                        fp_to_real(test_m[i]), test_m[i]);
            end
        end
    endtask
    
    // Task: Wait for completion and collect outputs
    task wait_and_collect;
        begin
            output_idx = 0;
            $display("[%0t] Waiting for computation to complete...", $time);
            
            // Wait for OUTPUT state (after PRE_OUTPUT)
            // OUTPUT = 3'd5 (localparam in winograd_output_transform)
            wait(dut.state == 3'd5);
            $display("[%0t] Entered OUTPUT state", $time);
            
            // CRITICAL: Wait 2 cycles for first y_out to be ready
            // Cycle 1: y_out <= y_matrix[0][0] is scheduled
            // Cycle 2: y_out has the correct value
            @(posedge clk);
            @(posedge clk);
            
            // Collect all 4 outputs
            while (output_idx < 4) begin
                actual_output[output_idx] = y_out;
                $display("[%0t] Y[%0d][%0d] = %f (0x%h)", 
                        $time, output_idx/2, output_idx%2,
                        fp_to_real(y_out), y_out);
                output_idx = output_idx + 1;
                
                if (output_idx < 4) begin
                    @(posedge clk);
                end
            end
            
            // Wait for done signal
            wait(done == 1);
            $display("[%0t] Computation done!", $time);
            #(CLK_PERIOD);
        end
    endtask
    
    // Task: Compare outputs
    task compare_results;
        real tolerance;
        real expected_val, actual_val, diff;
        begin
            errors = 0;
            tolerance = 0.01; // Allow 1% error
            
            $display("\n========== VERIFICATION ==========");
            for (i = 0; i < 4; i = i + 1) begin
                expected_val = fp_to_real(expected_output[i]);
                actual_val = fp_to_real(actual_output[i]);
                diff = expected_val - actual_val;
                if (diff < 0) diff = -diff;
                
                $display("Output[%0d][%0d]:", i/2, i%2);
                $display("  Expected: %f (0x%h)", expected_val, expected_output[i]);
                $display("  Actual:   %f (0x%h)", actual_val, actual_output[i]);
                $display("  Diff:     %f", diff);
                
                if (diff > tolerance) begin
                    $display("  [FAIL] Error exceeds tolerance!");
                    errors = errors + 1;
                end else begin
                    $display("  [PASS]");
                end
            end
            
            $display("\n========== SUMMARY ==========");
            if (errors == 0) begin
                $display("ALL TESTS PASSED!");
            end else begin
                $display("TESTS FAILED: %0d errors", errors);
            end
            $display("=============================\n");
        end
    endtask
    
    // Main test
    initial begin
        $dumpfile("winograd_output.vcd");
        $dumpvars(0, tb_output);
        
        $display("\n========================================");
        $display("Winograd Output Transform Testbench");
        $display("FIXED VERSION with PRE_OUTPUT state");
        $display("========================================\n");
        
        // ============================
        // Test Case 1: Tridiagonal-like matrix
        // ============================
        test_num = 1;
        $display("\n========== TEST CASE %0d ==========", test_num);
        $display("Tridiagonal-like matrix");
        
        apply_reset();
        
        // M matrix (4x4)
        test_m[0]  = real_to_fp(1.0);    test_m[1]  = real_to_fp(0.5);
        test_m[2]  = real_to_fp(0.0);    test_m[3]  = real_to_fp(0.0);
        test_m[4]  = real_to_fp(0.5);    test_m[5]  = real_to_fp(1.0);
        test_m[6]  = real_to_fp(0.5);    test_m[7]  = real_to_fp(0.0);
        test_m[8]  = real_to_fp(0.0);    test_m[9]  = real_to_fp(0.5);
        test_m[10] = real_to_fp(1.0);    test_m[11] = real_to_fp(0.5);
        test_m[12] = real_to_fp(0.0);    test_m[13] = real_to_fp(0.0);
        test_m[14] = real_to_fp(0.5);    test_m[15] = real_to_fp(1.0);
        
        expected_output[0] = real_to_fp(5.0);
        expected_output[1] = real_to_fp(0.0);
        expected_output[2] = real_to_fp(0.0);
        expected_output[3] = real_to_fp(3.0);
        
        load_m_matrix();
        wait_and_collect();
        compare_results();
        
        // ============================
        // Test Case 2: All zeros
        // ============================
        test_num = 2;
        $display("\n========== TEST CASE %0d ==========", test_num);
        $display("All zeros test");
        
        apply_reset();
        
        for (i = 0; i < 16; i = i + 1) begin
            test_m[i] = real_to_fp(0.0);
        end
        
        expected_output[0] = real_to_fp(0.0);
        expected_output[1] = real_to_fp(0.0);
        expected_output[2] = real_to_fp(0.0);
        expected_output[3] = real_to_fp(0.0);
        
        load_m_matrix();
        wait_and_collect();
        compare_results();
        
        // ============================
        // Test Case 3: Identity matrix
        // ============================
        test_num = 3;
        $display("\n========== TEST CASE %0d ==========", test_num);
        $display("Identity matrix test");
        
        apply_reset();
        
        test_m[0]  = real_to_fp(1.0);    test_m[1]  = real_to_fp(0.0);
        test_m[2]  = real_to_fp(0.0);    test_m[3]  = real_to_fp(0.0);
        test_m[4]  = real_to_fp(0.0);    test_m[5]  = real_to_fp(1.0);
        test_m[6]  = real_to_fp(0.0);    test_m[7]  = real_to_fp(0.0);
        test_m[8]  = real_to_fp(0.0);    test_m[9]  = real_to_fp(0.0);
        test_m[10] = real_to_fp(1.0);    test_m[11] = real_to_fp(0.0);
        test_m[12] = real_to_fp(0.0);    test_m[13] = real_to_fp(0.0);
        test_m[14] = real_to_fp(0.0);    test_m[15] = real_to_fp(1.0);
        
        expected_output[0] = real_to_fp(3.0);
        expected_output[1] = real_to_fp(0.0);
        expected_output[2] = real_to_fp(0.0);
        expected_output[3] = real_to_fp(3.0);
        
        load_m_matrix();
        wait_and_collect();
        compare_results();
        
        // ============================
        // Test Case 4: All ones matrix
        // ============================
        test_num = 4;
        $display("\n========== TEST CASE %0d ==========", test_num);
        $display("All ones matrix");
        
        apply_reset();
        
        for (i = 0; i < 16; i = i + 1) begin
            test_m[i] = real_to_fp(1.0);
        end
        
        expected_output[0] = real_to_fp(9.0);
        expected_output[1] = real_to_fp(-3.0);
        expected_output[2] = real_to_fp(-3.0);
        expected_output[3] = real_to_fp(1.0);
        
        load_m_matrix();
        wait_and_collect();
        compare_results();
        
        #(CLK_PERIOD * 10);
        $display("\n========================================");
        $display("Simulation completed!");
        $display("========================================\n");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 20000);
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule