module full_adder(
    input a,
    input b,
    input cin,
    output cout,
    output sum
);
assign sum = a ^ b ^ cin;
assign cout = a & b | a & cin | b & cin;
endmodule

module ripple_carry #(
    parameter N = 4
) (
    input [N-1:0] a,
    input [N-1:0] b,
    input cin,
    output [N-1:0] sum,
    output  cout
);
wire [N-1:0] carry;
full_adder fa0(
    .a(a[0]),
    .b(b[0]),
    .cin(cin), 
    .sum(sum[0]),
    .cout(carry[0])
);
genvar i;
generate
    for (i = 1; i < N ; i = i + 1 ) begin
        full_adder fa(
            .a(a[i]),
            .b(b[i]),
            .cin(carry[i-1]),
            .sum(sum[i]),
            .cout(carry[i])
        );
    end
endgenerate

assign cout = carry[N-1];   

endmodule
