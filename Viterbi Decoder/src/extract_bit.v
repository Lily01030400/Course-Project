`timescale 1ns / 1ps

module extract_bit(rst,clk,en_ext,i_data,o_rx);

input rst, clk, en_ext;
input [15:0] i_data;

output reg [1:0] o_rx;

reg [3:0] count;

always @ (posedge clk or negedge rst)  
begin
    if (rst == 0)
    begin
        count <= 4'b1111; // MSB to LSB 
        o_rx <= 2'b00;
    end
    else 
    begin
        if (en_ext == 1)
        begin
            o_rx <= {i_data[count], i_data[count - 1]};
            count <= count - 2; 
        end
	else if(en_ext == 0)
        begin
            o_rx <= 2'b00;
            count <= count;
        end

    end
end
endmodule

