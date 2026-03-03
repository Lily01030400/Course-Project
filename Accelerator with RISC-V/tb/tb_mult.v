`timescale 1ns/1ps

module tb_elementwise_v3;

    parameter DATA_WIDTH = 32;
    parameter FRAC_BITS = 16;
    parameter NUM_ELEMENTS = 16;
    parameter CLK_PERIOD = 10;

    reg                     clk;
    reg                     rstn;
    reg                     start;
    reg  [DATA_WIDTH-1:0]   u_in;
    reg  [DATA_WIDTH-1:0]   v_in;
    reg  [3:0]              elem_idx;
    reg  [7:0]              ch_idx;
    reg  [7:0]              num_ch;
    reg  [3:0]              read_idx;
    wire [DATA_WIDTH-1:0]   m_out;
    wire                    valid_out;
    wire                    all_done;

    integer errors;
    integer test_num;
    integer i, j;
    real received_val, expected_val, error;
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // DUT - New interface
    winograd_elementwise #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .NUM_ELEMENTS(NUM_ELEMENTS)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .u_in(u_in),
        .v_in(v_in),
        .elem_idx(elem_idx),
        .ch_idx(ch_idx),
        .num_ch(num_ch),
        .read_idx(read_idx),
        .m_out(m_out),
        .valid_out(valid_out),
        .all_done(all_done)
    );

    function [DATA_WIDTH-1:0] real_to_fp;
        input real val;
        begin
            real_to_fp = $rtoi(val * (2.0 ** FRAC_BITS));
        end
    endfunction

    function real fp_to_real;
        input signed [DATA_WIDTH-1:0] fp_val;
        begin
            fp_to_real = $itor($signed(fp_val)) / (2.0 ** FRAC_BITS);
        end
    endfunction

    real expected_results [0:NUM_ELEMENTS-1];

    initial begin
        $display("========================================================");
        $display("  Winograd Element-wise V3 Testbench");
        $display("  New Interface: start, ch_idx, num_ch, read_idx, all_done");
        $display("========================================================");
        
        errors = 0;
        test_num = 0;
        
        rstn = 0;
        start = 0;
        u_in = 0;
        v_in = 0;
        elem_idx = 0;
        ch_idx = 0;
        num_ch = 0;
        read_idx = 0;
        
        repeat(10) @(posedge clk);
        rstn = 1;
        repeat(5) @(posedge clk);
        
        test_single_channel();
        test_multi_channel();
        
        repeat(10) @(posedge clk);
        $display("\n========================================================");
        $display("  TEST SUMMARY");
        $display("========================================================");
        $display("  Total Tests: %0d", test_num);
        $display("  Errors:      %0d", errors);
        if (errors == 0) begin
            $display("  Result:      ALL TESTS PASSED!");
        end else begin
            $display("  Result:      SOME TESTS FAILED!");
        end
        $display("========================================================\n");
        
        $finish;
    end

    // Test 1: Single channel (simplest case)
    task test_single_channel;
        integer elem;
        begin
            test_num = test_num + 1;
            $display("\n========================================================");
            $display("  TEST %0d: Single Channel (num_ch=1)", test_num);
            $display("========================================================");
            
            num_ch = 8'd1;
            
            // Calculate expected: u * v for each element
            for (elem = 0; elem < NUM_ELEMENTS; elem = elem + 1) begin
                expected_results[elem] = 2.0 * 3.0;  // Simple: u=2, v=3
            end
            
            // Send data for all 16 elements, channel 0 (only channel)
            $display("\n[INFO] Sending data for 16 elements, 1 channel...");
            for (elem = 0; elem < NUM_ELEMENTS; elem = elem + 1) begin
                @(posedge clk);
                start = 1'b1;
                elem_idx = elem;
                ch_idx = 8'd0;  // Only channel
                u_in = real_to_fp(2.0);
                v_in = real_to_fp(3.0);
                
                @(posedge clk);
                start = 1'b0;
                
                $display("  [Send] elem=%2d, ch=0/0, u=2.0, v=3.0", elem);
            end
            
            // Wait for all_done
            $display("\n[INFO] Waiting for all_done...");
            wait(all_done == 1'b1);
            $display("[INFO] all_done asserted!");
            
            // Read back results
            $display("\n[INFO] Reading results from buffer...");
            for (elem = 0; elem < NUM_ELEMENTS; elem = elem + 1) begin
                @(posedge clk);
                read_idx = elem;
                @(posedge clk);  // Wait 1 cycle for combinational read
                
                received_val = fp_to_real(m_out);
                expected_val = expected_results[elem];
                error = received_val - expected_val;
                
                $display("  [Read] idx=%2d, value=%f, expected=%f, error=%f %s",
                         elem, received_val, expected_val, error,
                         (error < 0.01 && error > -0.01) ? "PASS" : "FAIL");
                
                if (error > 0.01 || error < -0.01) begin
                    errors = errors + 1;
                end
            end
            
            repeat(5) @(posedge clk);
            $display("\n[INFO] Test 1 Complete\n");
        end
    endtask

    // Test 2: Multiple channels
    task test_multi_channel;
        integer elem, ch;
        real u_val, v_val, temp_sum;
        begin
            test_num = test_num + 1;
            $display("\n========================================================");
            $display("  TEST %0d: Multiple Channels (num_ch=4)", test_num);
            $display("========================================================");
            
            num_ch = 8'd4;
            
            // Calculate expected: sum of u*v across 4 channels
            for (elem = 0; elem < NUM_ELEMENTS; elem = elem + 1) begin
                temp_sum = 0.0;
                for (ch = 0; ch < 4; ch = ch + 1) begin
                    u_val = 1.0 + elem*0.1 + ch*0.01;
                    v_val = 2.0 + elem*0.2 + ch*0.02;
                    temp_sum = temp_sum + (u_val * v_val);
                end
                expected_results[elem] = temp_sum;
            end
            
            // Send data: 16 elements x 4 channels = 64 operations
            $display("\n[INFO] Sending data for 16 elements, 4 channels...");
            for (ch = 0; ch < 4; ch = ch + 1) begin
                $display("  [Channel %0d]", ch);
                for (elem = 0; elem < NUM_ELEMENTS; elem = elem + 1) begin
                    @(posedge clk);
                    start = 1'b1;
                    elem_idx = elem;
                    ch_idx = ch;
                    u_val = 1.0 + elem*0.1 + ch*0.01;
                    v_val = 2.0 + elem*0.2 + ch*0.02;
                    u_in = real_to_fp(u_val);
                    v_in = real_to_fp(v_val);
                    
                    @(posedge clk);
                    start = 1'b0;
                    
                    if (elem % 4 == 0) begin
                        $display("    [Send] elem=%2d, ch=%0d/%0d, u=%f, v=%f",
                                 elem, ch, num_ch-1, u_val, v_val);
                    end
                end
            end
            
            // Wait for all_done
            $display("\n[INFO] Waiting for all_done...");
            wait(all_done == 1'b1);
            $display("[INFO] all_done asserted!");
            
            // Read back results
            $display("\n[INFO] Reading results from buffer...");
            for (elem = 0; elem < NUM_ELEMENTS; elem = elem + 1) begin
                @(posedge clk);
                read_idx = elem;
                @(posedge clk);  // Wait for combinational read
                
                received_val = fp_to_real(m_out);
                expected_val = expected_results[elem];
                error = received_val - expected_val;
                
                $display("  [Read] idx=%2d, value=%f, expected=%f, error=%f %s",
                         elem, received_val, expected_val, error,
                         (error < 0.05 && error > -0.05) ? "PASS" : "FAIL");
                
                if (error > 0.05 || error < -0.05) begin
                    errors = errors + 1;
                end
            end
            
            repeat(5) @(posedge clk);
            $display("\n[INFO] Test 2 Complete\n");
        end
    endtask

    // Timeout
    initial begin
        #(CLK_PERIOD * 50000);
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule