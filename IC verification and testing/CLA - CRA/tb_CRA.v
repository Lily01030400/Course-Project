`timescale 1ns/1ps
module tb_CRA;
   parameter N = 4;
   reg [N-1:0] a;
   reg [N-1:0] b;
   reg cin;
   wire [N-1: 0] sum;
   wire cout;

ripple_carry #(N) uut(
    .a(a),
    .b(b),
    .cin(cin),
    .sum(sum),
    .cout(cout)
);
initial begin
    $monitor("Time = %0t | a = %4b b = %4b cin = %b | sum = %4b cout = %b",
              $time, a, b, cin, sum, cout);

    a = 4'b0000; b = 4'b0000; cin = 0; #10;
    a = 4'b0010; b = 4'b0100; cin = 1; #10;
    a = 4'b1011; b = 4'b0110; cin = 0; #10;
    a = 4'b0101; b = 4'b0011; cin = 1; #10;
end

endmodule
