`timescale 1ns/1ps

module tb_branch_metric;

    reg rst, en_brch;
    reg [1:0] i_rx;

    wire [1:0] hd1, hd2, hd3, hd4, hd5, hd6, hd7, hd8;

    // Instantiate DUT
    branch_metric DUT (
        .rst(rst),
        .en_brch(en_brch),
        .i_rx(i_rx),
        .hd1(hd1), .hd2(hd2), .hd3(hd3), .hd4(hd4),
        .hd5(hd5), .hd6(hd6), .hd7(hd7), .hd8(hd8)
    );

    initial begin
        // Khởi tạo tín hiệu
        rst = 0;
        en_brch = 0;
        i_rx = 2'b00;

        #20 rst = 1;        // Release reset
        #10 en_brch = 1;    // Enable branch metric

        // ---- Test Case 1: i_rx = 00 ----
        i_rx = 2'b00; #20;
        $display("i_rx=00 => hd1=%0d hd2=%0d hd3=%0d hd4=%0d hd5=%0d hd6=%0d hd7=%0d hd8=%0d",
                 hd1,hd2,hd3,hd4,hd5,hd6,hd7,hd8);

        // ---- Test Case 2: i_rx = 01 ----
        i_rx = 2'b01; #20;
        $display("i_rx=01 => hd1=%0d hd2=%0d hd3=%0d hd4=%0d hd5=%0d hd6=%0d hd7=%0d hd8=%0d",
                 hd1,hd2,hd3,hd4,hd5,hd6,hd7,hd8);

        // ---- Test Case 3: i_rx = 10 ----
        i_rx = 2'b10; #20;
        $display("i_rx=10 => hd1=%0d hd2=%0d hd3=%0d hd4=%0d hd5=%0d hd6=%0d hd7=%0d hd8=%0d",
                 hd1,hd2,hd3,hd4,hd5,hd6,hd7,hd8);

        // ---- Test Case 4: i_rx = 11 ----
        i_rx = 2'b11; #20;
        $display("i_rx=11 => hd1=%0d hd2=%0d hd3=%0d hd4=%0d hd5=%0d hd6=%0d hd7=%0d hd8=%0d",
                 hd1,hd2,hd3,hd4,hd5,hd6,hd7,hd8);

        // ---- Disable test ----
        en_brch = 0; #20;
        $display("Disable => hd1=%0d hd2=%0d hd3=%0d hd4=%0d hd5=%0d hd6=%0d hd7=%0d hd8=%0d",
                 hd1,hd2,hd3,hd4,hd5,hd6,hd7,hd8);

        $finish;
    end

endmodule

