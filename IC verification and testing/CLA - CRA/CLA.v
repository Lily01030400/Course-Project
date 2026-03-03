module Carry_lookahead(
  input [3:0] a, 
  input [3:0] b, 
  input cin,
  output [3:0] sum,
  output cout
);
  wire [3:0] ci; 

  assign sum = a ^ b ^ ci;
  
  assign ci[0] = cin;

  assign ci[1] = (a[0] & b[0]) | ((a[0]^b[0]) & ci[0]);

  assign ci[2] = (a[1] & b[1]) | ((a[1]^b[1]) & ((a[0] & b[0]) | ((a[0]^b[0]) & ci[0])));

  assign ci[3] = (a[2] & b[2]) | ((a[2]^b[2]) & ((a[1] & b[1]) | ((a[1]^b[1]) & ((a[0] & b[0]) | ((a[0]^b[0]) & ci[0])))));
  
  assign cout  = (a[3] & b[3]) | ((a[3]^b[3]) & ((a[2] & b[2]) | ((a[2]^b[2]) & ((a[1] & b[1]) | ((a[1]^b[1]) & ((a[0] & b[0]) | ((a[0]^b[0]) & ci[0])))))));

  
endmodule