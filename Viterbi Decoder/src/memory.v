`timescale 1ns / 1ps

module memory(
    input clk,
    input rst,
    input en_mem,
    input [1:0] prev_st_00,
    input [1:0] prev_st_10,
    input [1:0] prev_st_01,
    input [1:0] prev_st_11,
    output reg [1:0] bck_prev_st_00,
    output reg [1:0] bck_prev_st_10,
    output reg [1:0] bck_prev_st_01,
    output reg [1:0] bck_prev_st_11
    );


reg [3:0] count; 
reg [1:0] trellis_diagr[0:3][0:7];
reg [2:0] trace; 

integer i;
integer k;

always @ (posedge clk or negedge rst)
begin
    if (rst == 0)
    begin 
        count <= 0; 
        trace <= 7;
        for (i = 0; i < 4; i = i + 1) begin // tuong duong voi 4 x 8 phep gan 32 phan tu 
            for (k = 0; k < 8; k = k + 1) begin
                trellis_diagr[i][k] <= 2'b00; // quy ve nut 00
            end
        end
    end
    else 
    begin
        if (en_mem == 1)  
        begin
            if(count < 8)
            begin
            trellis_diagr[0][count] <= prev_st_00; 
            trellis_diagr[2][count] <= prev_st_10; 
            trellis_diagr[1][count] <= prev_st_01;
            trellis_diagr[3][count] <= prev_st_11;
            count <= count + 1;
            end

            if(count == 8)
            begin
                bck_prev_st_00 <= trellis_diagr[0][trace]; 
                bck_prev_st_10 <= trellis_diagr[2][trace]; 
                bck_prev_st_01 <= trellis_diagr[1][trace]; 
                bck_prev_st_11 <= trellis_diagr[3][trace];
                if (trace != 0)
                trace <= trace - 1;
            end
        end
    end
end

endmodule


