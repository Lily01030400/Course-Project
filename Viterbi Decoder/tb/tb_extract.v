`timescale 1ns/1ps

module tb_extract();

    reg clk;
    reg rst;
    reg en_ext;
    reg [15:0] i_data;
    wire [1:0] o_rx;

    extract_bit uut (
        .rst(rst),
        .clk(clk),
        .en_ext(en_ext),
        .i_data(i_data),
        .o_rx(o_rx)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        i_data = 16'b1101_1001_0001_0111;
        rst = 0;
        en_ext = 0;
    // reset
        #20;
        rst = 1;
        @(posedge clk);
    // start extract
        en_ext = 1;

        repeat(8) begin
            @(posedge clk);
            $display("time %0t: o_rx = %b", $time, o_rx);
        end

        en_ext = 0;
        @(posedge clk);

        $finish;
    end

endmodule
