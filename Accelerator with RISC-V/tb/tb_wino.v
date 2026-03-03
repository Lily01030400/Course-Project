//==============================================================================
// Testbench: tb_winograd_conv_top.v
//==============================================================================

`timescale 1ns/1ps

module tb_winograd_conv_top;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter DATA_WIDTH = 32;
    parameter FRAC_BITS = 16;
    parameter CLK_PERIOD = 10; // 100MHz
    
    //==========================================================================
    // DUT Signals
    //==========================================================================
    reg                     clk;
    reg                     rstn;
    
    // Control
    reg                     start;
    wire                    ready;
    wire                    done;
    
    // Configuration
    reg  [7:0]              num_channels;
    // Data input
    reg  [DATA_WIDTH-1:0]   data_in;
    reg                     data_valid;
    
    // Filter input
    reg  [DATA_WIDTH-1:0]   filter_in;
    reg                     filter_valid;
    
    // Output
    wire [DATA_WIDTH-1:0]   data_out;
    wire                    data_out_valid;
    
    // Status
    wire [3:0]              current_state;
    
    //==========================================================================
    // Test Variables
    //==========================================================================
    integer i;
    integer error_count;
    integer test_count;
    integer timeout;
    
    // Test data
    reg [DATA_WIDTH-1:0] test_filter [0:8];
    reg [DATA_WIDTH-1:0] test_input [0:15];
    reg [DATA_WIDTH-1:0] collected_output [0:3];
    integer output_count;
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    winograd_conv_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .ready(ready),
        .done(done),
        .num_channels(num_channels),
        .data_in(data_in),
        .data_valid(data_valid),
        .filter_in(filter_in),
        .filter_valid(filter_valid),
        .data_out(data_out),
        .data_out_valid(data_out_valid),
        .current_state(current_state)
    );
    
    //==========================================================================
    // Test Tasks
    //==========================================================================
    
    // Task: Initialize test data
    task init_test_data;
        begin
            // Simple test pattern: 3x3 filter (all 1s in fixed-point)
            // Fixed-point 1.0 = 0x00010000 (with FRAC_BITS=16)
            for (i = 0; i < 9; i = i + 1) begin
                test_filter[i] = 32'h00010000; // 1.0 in Q16.16
            end
            
            // 4x4 input tile (sequential values)
            for (i = 0; i < 16; i = i + 1) begin
                test_input[i] = (i + 1) << 16; // 1.0, 2.0, 3.0, ... 16.0
            end
            
            $display("[%0t] Test data initialized", $time);
            $display("  Filter: All 1.0 (0x00010000)");
            $display("  Input: 1.0 to 16.0");
        end
    endtask
    
    // Task: Load filter data
    task load_filter;
        begin
            $display("[%0t] Loading filter (9 values)...", $time);
            for (i = 0; i < 9; i = i + 1) begin
                @(posedge clk);
                filter_in = test_filter[i];
                filter_valid = 1'b1;
                $display("  Filter[%0d] = 0x%08h", i, test_filter[i]);
            end
            @(posedge clk);
            filter_valid = 1'b0;
            filter_in = 32'h0;
            $display("[%0t] Filter loading complete", $time);
        end
    endtask
    
    // Task: Load input data
    task load_input;
        begin
            $display("[%0t] Loading input (16 values)...", $time);
            for (i = 0; i < 16; i = i + 1) begin
                @(posedge clk);
                data_in = test_input[i];
                data_valid = 1'b1;
                $display("  Input[%0d] = 0x%08h", i, test_input[i]);
            end
            @(posedge clk);
            data_valid = 1'b0;
            data_in = 32'h0;
            $display("[%0t] Input loading complete", $time);
        end
    endtask
    
    // Task: Collect outputs
    task collect_outputs;
        begin
            output_count = 0;
            $display("[%0t] Waiting for outputs...", $time);
            
            timeout = 0;
            while (output_count < 4 && timeout < 100000) begin
                @(posedge clk);
                if (data_out_valid) begin
                    collected_output[output_count] = data_out;
                    $display("  Output[%0d] = 0x%08h", output_count, data_out);
                    output_count = output_count + 1;
                end
                timeout = timeout + 1;
            end
            
            if (timeout >= 100000) begin
                $display("[%0t] ERROR: Timeout waiting for outputs!", $time);
                error_count = error_count + 1;
            end else begin
                $display("[%0t] All outputs collected", $time);
            end
        end
    endtask
    
    // Task: Wait for done signal
    task wait_for_done;
        begin
            timeout = 0;
            $display("[%0t] Waiting for done signal...", $time);
            
            while (!done && timeout < 100000) begin
                @(posedge clk);
                timeout = timeout + 1;
                
                // Show state progress
                if (timeout % 1000 == 0) begin
                    $display("  State: %0d, Timeout: %0d", current_state, timeout);
                end
            end
            
            if (done) begin
                $display("[%0t] Done signal asserted!", $time);
            end else begin
                $display("[%0t] ERROR: Done timeout! State stuck at %0d", $time, current_state);
                error_count = error_count + 1;
            end
        end
    endtask
    
    //==========================================================================
    // Monitor for data_out_valid
    //==========================================================================
    always @(posedge clk) begin
        if (data_out_valid) begin
            $display("[%0t] [MONITOR] data_out_valid=1, data_out=0x%08h, state=%0d", 
                     $time, data_out, current_state);
        end
    end
    
    //==========================================================================
    // Main Test
    //==========================================================================
    initial begin
        // Initialize
        error_count = 0;
        test_count = 0;
        
        $display("\n========================================");
        $display("Winograd Conv Top Testbench");
        $display("Testing wrapper with 4 sub-modules");
        $display("========================================\n");
        
        // Reset
        rstn = 0;
        start = 0;
        num_channels = 8'd0;
        data_in = 32'h0;
        data_valid = 1'b0;
        filter_in = 32'h0;
        filter_valid = 1'b0;
        
        #(CLK_PERIOD * 10);
        rstn = 1;
        #(CLK_PERIOD * 5);
        
        //======================================================================
        // TEST 1: Check Initial State
        //======================================================================
        $display("\n--- TEST 1: Initial State Check ---");
        test_count = test_count + 1;
        
        if (ready == 1'b1) begin
            $display("PASS: Module ready after reset");
        end else begin
            $display("FAIL: Module not ready");
            error_count = error_count + 1;
        end
        
        if (current_state == 4'd0) begin
            $display("PASS: State = IDLE (0)");
        end else begin
            $display("FAIL: State = %0d (expected 0)", current_state);
            error_count = error_count + 1;
        end
        
        #(CLK_PERIOD * 10);
        
        //======================================================================
        // TEST 2: Load Filter and Input
        //======================================================================
        $display("\n--- TEST 2: Load Data ---");
        test_count = test_count + 1;
        
        // Initialize test data
        init_test_data();
        
        // Set configuration
        num_channels = 8'd1;  // Single channel
        
        // Load filter (9 values)
        load_filter();
        
        // Load input (16 values)
        load_input();
        
        $display("PASS: Data loaded successfully");
        
        #(CLK_PERIOD * 10);
        
        //======================================================================
        // TEST 3: Start Computation
        //======================================================================
        $display("\n--- TEST 3: Start Computation ---");
        test_count = test_count + 1;
        
        // Assert start
        @(posedge clk);
        start = 1'b1;
        $display("[%0t] START asserted", $time);
        
        @(posedge clk);
        start = 1'b0;
        
        // Check ready goes low
        #(CLK_PERIOD * 2);
        if (ready == 1'b0) begin
            $display("PASS: Ready deasserted during computation");
        end else begin
            $display("FAIL: Ready still high");
            error_count = error_count + 1;
        end
        
        //======================================================================
        // TEST 4: Monitor State Transitions
        //======================================================================
        $display("\n--- TEST 4: State Machine Progress ---");
        test_count = test_count + 1;
        
        // Monitor for a while
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            if (i % 10 == 0) begin
                $display("  Cycle %0d: State=%0d, Ready=%0b, Done=%0b", 
                         i, current_state, ready, done);
            end
        end
        
        $display("PASS: State machine running");
        
        //======================================================================
        // TEST 5: Collect Outputs
        //======================================================================
        $display("\n--- TEST 5: Collect Outputs ---");
        test_count = test_count + 1;
        
        collect_outputs();
        
        if (output_count == 4) begin
            $display("PASS: Collected 4 outputs");
        end else begin
            $display("FAIL: Only collected %0d outputs", output_count);
            error_count = error_count + 1;
        end
        
        //======================================================================
        // TEST 6: Wait for Done
        //======================================================================
        $display("\n--- TEST 6: Done Signal ---");
        test_count = test_count + 1;
        
        wait_for_done();
        
        if (done) begin
            $display("PASS: Done signal asserted");
        end else begin
            $display("FAIL: Done not asserted");
            error_count = error_count + 1;
        end
        
        // Wait and check ready returns
        #(CLK_PERIOD * 10);
        
        if (ready == 1'b1) begin
            $display("PASS: Ready returned after done");
        end else begin
            $display("FAIL: Ready not returned");
            error_count = error_count + 1;
        end
        
        #(CLK_PERIOD * 20);
        
        //======================================================================
        // TEST 7: Second Run (Back to Back)
        //======================================================================
        $display("\n--- TEST 7: Second Computation ---");
        test_count = test_count + 1;
        
        // Load new data
        for (i = 0; i < 9; i = i + 1) begin
            test_filter[i] = 32'h00008000; // 0.5
        end
        for (i = 0; i < 16; i = i + 1) begin
            test_input[i] = 32'h00020000; // 2.0
        end
        
        load_filter();
        load_input();
        
        // Start
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        
        // Collect outputs
        collect_outputs();
        
        if (output_count == 4) begin
            $display("PASS: Second run successful");
        end else begin
            $display("FAIL: Second run failed");
            error_count = error_count + 1;
        end
        
        #(CLK_PERIOD * 50);
        
        //======================================================================
        // Final Summary
        //======================================================================
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Errors:      %0d", error_count);
        
        if (error_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end else begin
            $display("\n*** %0d TESTS FAILED ***\n", error_count);
        end
        
        $display("Simulation Time: %0t", $time);
        $display("========================================\n");
        
        $finish;
    end
    
    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #200000000; // 200ms timeout
        $display("\n*** ERROR: SIMULATION TIMEOUT ***");
        $display("Final State: %0d", current_state);
        $display("Ready: %0b, Done: %0b\n", ready, done);
        $finish;
    end
    
    //==========================================================================
    // VCD Dump (optional - comment out if not needed)
    //==========================================================================
    initial begin
        $dumpfile("tb_winograd_conv_top.vcd");
        $dumpvars(0, tb_winograd_conv_top);
    end

endmodule