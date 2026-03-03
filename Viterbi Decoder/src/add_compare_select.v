`timescale 1ns / 1ps

module add_comp_slt(clk, rst, en_acs,
                    hd1, hd2, hd3, hd4, hd5, hd6, hd7, hd8,
                    prev_st_00, prev_st_10, prev_st_01, prev_st_11,
                    slt_node);

input clk, rst, en_acs;
input [1:0] hd1, hd2, hd3, hd4, hd5, hd6, hd7, hd8;
output reg [1:0] prev_st_00, prev_st_01, prev_st_10, prev_st_11; 
output reg [1:0] slt_node;
reg [4:0] sum00, sum10, sum01, sum11; 
reg [4:0] min_sum;
reg [3:0] count;
reg [1:0] min_node;

always @(posedge clk or negedge rst)
begin
    if(rst == 0)
    begin
        count <= 3'b000;
        sum00 <= 5'b00000;  
        sum10 <= 5'b00000;
        sum01 <= 5'b00000;
        sum11 <= 5'b00000;
        prev_st_00 <= 2'b00;
        prev_st_01 <= 2'b00;
        prev_st_10 <= 2'b00;
        prev_st_11 <= 2'b00;
        slt_node <= 2'b00;
    end
    else 
    begin
    if(en_acs == 1)  
    begin   
	// xet cho next node 00
                if(((hd1 + sum00) == (hd5 + sum01)) || ((hd1 + sum00) < (hd5 + sum01)))
                begin
                    sum00 <= hd1 + sum00;
                    prev_st_00 <= 2'b00; 
                end
                else if((hd1 + sum00) > (hd5 + sum01))
                begin
                    sum00 <= hd5 + sum01; 
                    prev_st_00 <= 2'b01;
                end
       // xet cho next node 10
                if(((hd2 + sum00) == (hd6 + sum01)) || ((hd2 + sum00) < (hd6 + sum01)))
                begin
                    sum10 <= hd2 + sum00;
                    prev_st_10 <= 2'b00;
                end
                else
                begin
                    sum10 <= hd6 + sum01;
                    prev_st_10 <= 2'b01;
                end
       // xet cho next node 01
         	if(((hd3 + sum10) == (hd7 + sum11)) || ((hd3 + sum10) < (hd7 + sum11)))
                begin
                    sum01 <= hd3 + sum10;
                    prev_st_01 <= 2'b10;
                end
                else
                begin
                    sum01 <= hd7 + sum11;
                    prev_st_01 <= 2'b11;
                end
       // xet cho next node 11    
                if(((hd4 + sum10) == (hd8 + sum11)) || ((hd4 + sum10) < (hd8 + sum11)))
                begin
                    sum11 <= hd4 + sum10; 
                    prev_st_11 <= 2'b10;
                end
                else
                begin
                    sum11 <= hd8 + sum11;
                    prev_st_11 <= 2'b11;
                end
        slt_node <= min_node;
        count <= count + 1;
    end
    else
    begin
        count <= count;
        sum00 <= sum00;  
        sum10 <= sum10;
        sum01 <= sum01;
        sum11 <= sum11;
        prev_st_00 <= 2'b00;
        prev_st_01 <= 2'b00;
        prev_st_10 <= 2'b00;
        prev_st_11 <= 2'b00;
        slt_node <= 2'b00;
    end
end
end


always @ (*) // combinational logic
begin
    if(rst == 0)
    begin 
        min_sum = 5'b11111;
        min_node = 2'b00;
    end
    if(count == 8 || count > 8)  
        begin 
        if(sum00 < min_sum) // thu tu uu tien neu bang nhau: 00 > 10 > 01 > 11
        begin
            min_sum = sum00;
            min_node = 2'b00;
        end
        if(sum10 < min_sum) 
        begin
            min_sum = sum10;
            min_node = 2'b10;
        end
        if(sum01 < min_sum)
        begin
            min_sum = sum01;
            min_node = 2'b01;
        end
        if(sum11 < min_sum)
        begin
            min_sum = sum11;
            min_node = 2'b11;
        end
        end
end

endmodule
