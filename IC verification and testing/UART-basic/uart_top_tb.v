`timescale 1us/1ns

module uart_top_tb;
    //uart A
    reg rst_n_A;
    reg clk_A;
    reg [7:0] data_in_A;
    reg di_rdy_A;
    wire do_rdy_A;
    wire txd_A;
    wire rxd_A;
    wire [7:0] data_out_A;
    wire parity_error_A;
    wire send_end_A;
    wire baud_tick_A;
    wire [7:0] data_reg_A;
    wire tx_busy_A;

    //uart B
    reg rst_n_B;
    reg clk_B;
    reg [7:0] data_in_B;
    reg di_rdy_B;
    wire do_rdy_B;
    wire txd_B;
    wire [7:0] data_reg_B;
    wire [7:0] data_out_B;
    wire parity_error_B;
    wire send_end_B;
    wire baud_tick_B;
    wire tx_busy_B;

    //config uart in common
    reg [2:0] baud;
    reg parity_en;
    reg parity_type;
    reg [7:0] test_data[0:9];
    integer i;
    integer k;

    //generate clk
    initial begin
        clk_A = 0;
        forever #0.1 clk_A = ~clk_A;
    end
    initial begin
        #0.05 clk_B = 0;
        forever #0.1 clk_B = ~clk_B;
    end

    //UART A
    uart_top uart_A (
        .clk(clk_A),
        .rst_n(rst_n_A),
        .data_in(data_in_A),
        .di_rdy(di_rdy_A),
        .baud(baud),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .txd(txd_A),
        .rxd(rxd_A),
        .data_out(data_out_A),
        .do_rdy(do_rdy_A),
        .parity_error(parity_error_A),
        .send_end(send_end_A),
        .baud_tick(baud_tick_A),
        .data_reg(data_reg_A),
        .tx_busy(tx_busy_A)
    );
    //UART B
    uart_top uart_B (
        .clk(clk_B),
        .rst_n(rst_n_B),
        .data_in(data_in_B),
        .di_rdy(di_rdy_B),
        .baud(baud),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .txd(txd_B),
        .rxd(txd_A),
        .data_out(data_out_B),
        .do_rdy(do_rdy_B),
        .parity_error(parity_error_B),
        .send_end(send_end_B),
        .baud_tick(baud_tick_B),
        .data_reg(data_reg_B),
        .tx_busy(tx_busy_B)
    );

    //TESTING
    initial begin
        //test_data
        test_data[0]=8'b01010101;
        test_data[1]=8'b10100101;
        test_data[2]=8'b00111100;
        test_data[3]=8'b11110000;
        test_data[4]=8'b10011001;
        test_data[5]=8'b00010010;
        test_data[6]=8'b11111110;
        test_data[7]=8'b10000001;
        test_data[8]=8'b01111110;
        test_data[9]=8'b00100000;

        //assign input
        assign baud = 3'd1; //9600
        $display("Time(us)\t\t | TXD_A\t RXD_B\t | data_in_A\t | data_out_B\t | do_rdy_B\t | pairty_err_B");
        //Parity on
        parity_en = 1'b1;
            //EVEN parity
            $display("============TEST: PARITY EVEN============");
            parity_type = 1'b0;
            data_in_A = 0;
            di_rdy_A = 0;
            rst_n_A = 0;
            rst_n_B = 0;
            #20;
            rst_n_A = 1;
            rst_n_B = 1;
            for (i = 0; i < 10; i = i + 1) begin
                @(posedge baud_tick_B);
                data_in_A = test_data[i];
                di_rdy_A = 1'b1;
                @(posedge baud_tick_B);
                di_rdy_A = 0;
                wait (do_rdy_B == 1);
                $display("%8t\t\t | %b\t %b\t | %b\t | %b\t | %b\t | %b", $time, txd_A, txd_A, data_in_A, data_out_B, do_rdy_B, parity_error_B);
                //CHECK di_A ==  do_B?
                if (data_out_B == data_in_A && parity_error_B == 0)
                $display("Frame %d OKE", i);
                else
                $display("Frame %d WRONG, when data_in_A = %b but data_out_B = %b", i, data_in_A, data_out_B);
                #20;
            end
            //ODD parity
            $display("============ TEST: PARITY ODD ============");
            parity_type = 1'b1;
            data_in_A = 0;
            di_rdy_A = 0;
            rst_n_A = 0;
            rst_n_B = 0;
            #20;
            rst_n_A = 1;
            rst_n_B = 1;
            for (i = 0; i < 10; i = i + 1) begin
                @(posedge baud_tick_B);
                data_in_A = test_data[i];
                di_rdy_A = 1'b1;
                @(posedge baud_tick_B);
                di_rdy_A = 0;
                wait (do_rdy_B == 1);
                $display("%8t\t\t | %b\t %b\t | %b\t | %b\t | %b\t | %b", $time, txd_A, txd_A, data_in_A, data_out_B, do_rdy_B, parity_error_B);
                //CHECK di_A ==  do_B?
                if (data_out_B == data_in_A && parity_error_B == 0)
                $display("Frame %d OKE", i);
                else
                $display("Frame %d WRONG, when data_in_A = %b but data_out_B = %b", i, data_in_A, data_out_B);
                #20;
            end
        //Parity off
            $display("============TEST: PARITY OFF============");
            parity_en = 1'b0;
            data_in_A = 0;
            di_rdy_A = 0;
            rst_n_A = 0;
            rst_n_B = 0;
            #20;
            rst_n_A = 1;
            rst_n_B = 1;
            for (i = 0; i < 10; i = i + 1) begin
                @(posedge baud_tick_B);
                data_in_A = test_data[i];
                di_rdy_A = 1'b1;
                @(posedge baud_tick_B);
                di_rdy_A = 0;
                wait (do_rdy_B == 1);
                $display("%8t\t\t | %b\t %b\t | %b\t | %b\t | %b\t | %b", $time, txd_A, txd_A, data_in_A, data_out_B, do_rdy_B, parity_error_B);
                //CHECK di_A ==  do_B?
                if (data_out_B == data_in_A && parity_error_B == 0)
                $display("Frame %d OKE", i);
                else
                $display("Frame %d WRONG, when data_in_A = %b but data_out_B = %b", i, data_in_A, data_out_B);
                #20;
            end
        //Changing baud while running for 7 others baudrate
        $display("============TEST: RESET WHILE RUNNING AND TEST ALL 8 BAUDRATES============");
        parity_en = 1'b1;
        for (k = 0; k < 8; k = k + 1) begin
            if (baud == 0) baud = 3'd7;
            else baud = k - 1;
            rst_n_A = 1;
            rst_n_B = 1;
            #20;
            //transmitting dummy data
            data_in_A = 8'hFF;
            di_rdy_A = 1;
            @(posedge clk_A); di_rdy_A = 0;
            repeat(60) @(posedge baud_tick_A);
            //reset
            rst_n_A = 0;
            rst_n_B = 0;          
            baud = k[2:0];     
            data_in_A = 0;
            di_rdy_A = 0;
            #20;
            rst_n_A = 1;
            rst_n_B = 1;
            #200;
            for (i = 0; i < 10; i = i + 1) begin
                @(posedge baud_tick_B);
                data_in_A = test_data[i];
                di_rdy_A = 1'b1;
                @(posedge baud_tick_B);
                di_rdy_A = 0;
                wait (do_rdy_B == 1);
                $display("%8t\t\t | %b\t %b\t | %b\t | %b\t | %b\t | %b", $time, txd_A, txd_A, data_in_A, data_out_B, do_rdy_B, parity_error_B);
                //CHECK di_A ==  do_B?
                if (data_out_B == data_in_A && parity_error_B == 0)
                $display("Frame %d OKE", i);
                else
                $display("Frame %d WRONG, when data_in_A = %b but data_out_B = %b", i, data_in_A, data_out_B);
                #20;
            end
        end

        //RESET A BEFORE B WITHIN 10 CICLES
        $display("============TEST: RESET A BEFORE B WITHIN 10 CICLES============");
        baud = 3'd1;
        parity_en = 1'b1;
        parity_type = 1'b0;
        //data_in_A = 0;
        rst_n_A = 1;
        rst_n_B = 1;
        #20;
        for (i = 0; i < 10; i = i + 1) begin
            //transmitting dummy data
            @(posedge baud_tick_B);
            data_in_A = test_data[i];
            di_rdy_A = 1'b1;
            @(posedge clk_A); di_rdy_A = 0;
            repeat(60) @(posedge baud_tick_A);
            //reset A before B 10 clk cycles
            rst_n_A = 0;
            repeat(10) @(posedge clk_A);
            rst_n_B = 0;
            #20;
            rst_n_A = 1;
            rst_n_B = 1;
            #200;
            //wait until synchronise
            @(posedge baud_tick_B);
            data_in_A = test_data[i];
            di_rdy_A = 1'b1;
            @(posedge baud_tick_B);
            di_rdy_A = 0;
            wait (do_rdy_B == 1);
            $display("%8t\t\t | %b\t %b\t | %b\t | %b\t | %b\t | %b", $time, txd_A, txd_A, data_in_A, data_out_B, do_rdy_B, parity_error_B);
            //CHECK di_A == do_B?
            if (data_out_B == data_in_A && parity_error_B == 0)
            $display("Frame %d OKE", i);
            else
            $display("Frame %d WRONG, when data_in_A = %b but data_out_B = %b", i, data_in_A, data_out_B);
            #20;
        end        
        #40;
        $finish;        
    end
endmodule