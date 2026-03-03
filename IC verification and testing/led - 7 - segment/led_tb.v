`timescale 1ns/1ps
module led7thanh_tb;

reg [3:0] bcd;
wire [6:0] seg;

led7thanh uut(
    .bcd(bcd),
    .seg(seg)
);
integer i;
initial begin
    for (i = 0 ; i <= 9 ; i = i + 1 ) begin
        bcd = i[3:0];
        #10;
        $display("%8t %d %7b", $time, bcd, seg);
    end
    // TH bcd >9, ex: bcd = 10 
    bcd = 4'd10;
    #10;
    $display("%8t %d %7b", $time, bcd, seg);
    $finish;
end

endmodule