`timescale 1ns / 1ps
// testbench for matrix_input

module tb_input;

    parameter DATA_WIDTH = 32;
    parameter FRAC_BITS = 16;
    parameter CLK_PERIOD = 10; // clk 100MHZ
    
    reg clk, rstn, start;
    reg [DATA_WIDTH-1:0] d_in;
    reg [3:0] d_count;
    wire done;
    wire v_valid;
    wire [DATA_WIDTH-1:0] v_out;
    wire [3:0] v_count;
    // data array for testing
    reg [DATA_WIDTH-1:0] input_tile [0:15];
    reg [DATA_WIDTH-1:0] expected [0:15]; // to compare
    integer i, errors; // i for loop, error for counting error test
    
    // instance dut
    winograd_input_transform #(.DATA_WIDTH(DATA_WIDTH))
    dut (
        .clk(clk), 
        .rstn(rstn), 
        .start(start), 
        .d_in(d_in), 
        .d_count(d_count),
        .done(done), 
        .v_valid(v_valid),
        .v_out(v_out), 
        .v_count(v_count)
    );
    
    // clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    //convert fixed_poit to real to display
    function real fixed_to_real;
        input [DATA_WIDTH-1:0] val;
        begin
            fixed_to_real = $itor($signed(val)) / (1 << FRAC_BITS);
        end
    endfunction
    
    function [DATA_WIDTH-1:0] real_to_fixed;
        input real val;
        begin
            real_to_fixed = $rtoi(val * (1 << FRAC_BITS));
        end
    endfunction
    
    // Task: Load data with CORRECT timing
    task load_data;
        begin
            @(posedge clk);
            start = 1;
            
            @(posedge clk);
            start = 0;
            
            // Load 16 values
            for (i = 0; i < 16; i = i + 1) begin
                @(posedge clk);
                d_in = input_tile[i];
                d_count = i;
            end
            
            // CRITICAL: Keep d_count=15 for one more clock
            // so module can detect it and transition state
            @(posedge clk);
            
            // Now safe to reset
            d_in = 0;
            d_count = 0;
            
            $display("  Data loaded (with correct timing)");
        end
    endtask
    
    initial begin
        $display("\n============================================================");
        $display("Winograd Input Transform");
        $display("============================================================");
        
        rstn = 0; start = 0; d_in = 0; d_count = 0;
        repeat(5) @(posedge clk);
        rstn = 1;
        repeat(2) @(posedge clk);
        
        //==============================================================
        // TEST 1: All-Ones
        //==============================================================
        $display("\nTEST 1: All-Ones Input");
        $display("------------------------------------------------------------");
        
        for (i = 0; i < 16; i = i + 1)
            input_tile[i] = real_to_fixed(1.0);
        
        for (i = 0; i < 16; i = i + 1)
            expected[i] = real_to_fixed(0.0);
        expected[5] = real_to_fixed(4.0);
        
        $display("  Input: All 1.0");
        $display("  Expected: V[1][1] = 4.0");
        
        load_data();
        
        $display("  Waiting for computation...");
        wait(done);
        repeat(5) @(posedge clk);
        
        $display("  Actual: V[1][1] = %8.4f", 
                 fixed_to_real(dut.v_matrix[1][1]));
        
        if (dut.v_matrix[1][1] == expected[5])
            $display("PASS\n");
        else
            $display("FAIL\n");
        
        //==============================================================
        // TEST 2: Identity
        //==============================================================
        repeat(10) @(posedge clk);
        $display("TEST 2: Identity Input");
        $display("------------------------------------------------------------");
        
        for (i = 0; i < 16; i = i + 1)
            input_tile[i] = (i % 5 == 0) ? real_to_fixed(1.0) : real_to_fixed(0.0);
        
        expected[0]  = real_to_fixed(2.0);
        expected[5]  = real_to_fixed(2.0);
        expected[10] = real_to_fixed(2.0);
        expected[15] = real_to_fixed(2.0);
        
        $display("  Input: Identity matrix");
        $display("  Expected: Diagonal = 2.0");
        
        load_data();
        
        wait(done);
        repeat(5) @(posedge clk);
        
        $display("  Actual diagonal:");
        $display("    V[0][0] = %8.4f", fixed_to_real(dut.v_matrix[0][0]));
        $display("    V[1][1] = %8.4f", fixed_to_real(dut.v_matrix[1][1]));
        $display("    V[2][2] = %8.4f", fixed_to_real(dut.v_matrix[2][2]));
        $display("    V[3][3] = %8.4f", fixed_to_real(dut.v_matrix[3][3]));
        
        errors = 0;
        if (dut.v_matrix[0][0] != expected[0]) errors = errors + 1;
        if (dut.v_matrix[1][1] != expected[5]) errors = errors + 1;
        if (dut.v_matrix[2][2] != expected[10]) errors = errors + 1;
        if (dut.v_matrix[3][3] != expected[15]) errors = errors + 1;
        
        if (errors == 0)
            $display("PASS\n");
        else
            $display("FAIL (%0d errors)\n", errors);
        
        //==============================================================
        // TEST 3: Sequential
        //==============================================================
        repeat(10) @(posedge clk);
        $display("TEST 3: Sequential 1-16");
        $display("------------------------------------------------------------");
        
        for (i = 0; i < 16; i = i + 1)
            input_tile[i] = real_to_fixed($itor(i + 1));
        
        expected[1]  = real_to_fixed(-16.0);
        expected[5]  = real_to_fixed(34.0);
        expected[9]  = real_to_fixed(8.0);
        expected[13] = real_to_fixed(-16.0);
        
        $display("  Input: [1..16]");
        $display("  Expected: V[1][1] = 34.0");
        
        load_data();
        
        wait(done);
        repeat(5) @(posedge clk);
        
        $display("  Actual key values:");
        $display("    V[0][1] = %8.4f (exp: -16.0)", 
                 fixed_to_real(dut.v_matrix[0][1]));
        $display("    V[1][1] = %8.4f (exp:  34.0)", 
                 fixed_to_real(dut.v_matrix[1][1]));
        $display("    V[2][1] = %8.4f (exp:   8.0)", 
                 fixed_to_real(dut.v_matrix[2][1]));
        
        errors = 0;
        if (dut.v_matrix[0][1] != expected[1]) errors = errors + 1;
        if (dut.v_matrix[1][1] != expected[5]) errors = errors + 1;
        if (dut.v_matrix[2][1] != expected[9]) errors = errors + 1;
        
        if (errors == 0)
            $display("PASS\n");
        else
            $display("FAIL (%0d errors)\n", errors);
        
        //==============================================================
        $display("============================================================");
        $display("All tests completed");
        $display("============================================================\n");
        
        $finish;
    end
    
    // Timeout
    initial begin
        #100000;
        $display("\nTIMEOUT!");
        $finish;
    end
    
    // Waveform
    initial begin
        $dumpfile("tb_input.vcd");
        $dumpvars(0, tb_input);
    end

endmodule