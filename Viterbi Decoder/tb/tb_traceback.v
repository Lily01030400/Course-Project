`timescale 1ns/1ps

module tb_traceback();
    // Signals
    reg clk, rst, en_trbk;
    reg [1:0] slt_node;
    reg [1:0] bck_prev_st_00, bck_prev_st_10, bck_prev_st_01, bck_prev_st_11;
    wire [7:0] o_data;
    wire o_done;
    
    // Instantiate DUT
    traceback uut (
        .clk(clk),
        .rst(rst),
        .en_trbk(en_trbk),
        .slt_node(slt_node),
        .bck_prev_st_00(bck_prev_st_00),
        .bck_prev_st_10(bck_prev_st_10),
        .bck_prev_st_01(bck_prev_st_01),
        .bck_prev_st_11(bck_prev_st_11),
        .o_data(o_data),
        .o_done(o_done)
    );
    
    // Clock - 10ns period, sườn dương
    always #5 clk = ~clk;
    
    // Monitor
    initial begin
        $display("\n=== TRACEBACK TESTBENCH ===");
        $display("Time | en rst | slt curr | cnt | done | o_data");
        $monitor("%4t |  %b  %b  | %2b   %2b  | %2d  |  %b   | %h", 
                 $time, en_trbk, rst, slt_node, uut.curr_slt_node, 
                 uut.count, o_done, o_data);
    end
    
    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        en_trbk = 0;
        slt_node = 2'b00;
        {bck_prev_st_00, bck_prev_st_10, bck_prev_st_01, bck_prev_st_11} = 8'h00;
        
        // Test 1: Reset
        #15 rst = 1;
        #10;
        $display("\n[TEST 1] Reset: %s", (o_done==0 && o_data==0) ? "PASS" : "FAIL");
        
        // Test 2: Traceback path S0->S0->S1->S2->S0->S1->S2->S0 //s1 la 10 traceback
        // Expected: 8'b01000100 = 0x44
        $display("\n[TEST 2] Predefined path traceback");
        slt_node = 2'b00;
        en_trbk = 1;
        
        bck_prev_st_00 = 2'b00; bck_prev_st_01 = 2'b10; 
        bck_prev_st_10 = 2'b00; bck_prev_st_11 = 2'b10;
        #10;
        
        bck_prev_st_00 = 2'b01; #10;  // S0<-S1
        bck_prev_st_01 = 2'b10; #10;  // S1<-S2
        bck_prev_st_10 = 2'b00; #10;  // S2<-S0
        bck_prev_st_00 = 2'b01; #10;  // S0<-S1
        bck_prev_st_01 = 2'b10; #10;  // S1<-S2
        bck_prev_st_10 = 2'b00; #10;  // S2<-S0
        bck_prev_st_00 = 2'b00; #10;  // S0<-S0
        #10;  // Wait for count=8
        
        $display("Result: o_done=%b, o_data=0x%h (expected 0x44)", o_done, o_data);
        $display("Status: %s", (o_done==1 && o_data==8'h44) ? "PASS" : "FAIL");
        
        // Test 3: Start from S2
        $display("\n[TEST 3] Start from state S2");
        en_trbk = 0; #10;
        slt_node = 2'b10;
        bck_prev_st_00 = 2'b00; bck_prev_st_01 = 2'b10; 
        bck_prev_st_10 = 2'b01; bck_prev_st_11 = 2'b10;
        en_trbk = 1;
        #90;
        $display("Result: o_done=%b, o_data=0x%h", o_done, o_data);
        $display("Status: %s", (o_done==1) ? "PASS" : "FAIL");
        
        // Test 4: Disable during operation
        $display("\n[TEST 4] Disable during operation");
        en_trbk = 0; rst = 0; #10;
        rst = 1; #10;
        slt_node = 2'b00; en_trbk = 1;
        #40;  // 4 cycles
        en_trbk = 0; #20;
        $display("Status: %s", (uut.count==0 && o_done==0) ? "PASS" : "FAIL");
        
        // Test 5: All zeros path
        $display("\n[TEST 5] All zeros output");
        en_trbk = 0; rst = 0; #10; rst = 1; #10;
        slt_node = 2'b00;
        bck_prev_st_00 = 2'b00; bck_prev_st_01 = 2'b10; 
        bck_prev_st_10 = 2'b00; bck_prev_st_11 = 2'b10;
        en_trbk = 1;
        #90;
        $display("Result: o_data=0x%h", o_data);
        $display("Status: %s", (o_done==1 && o_data==8'h00) ? "PASS" : "FAIL");
        
        $display("\n=== TESTBENCH COMPLETED ===\n");
        #20 $finish;
    end
    
endmodule