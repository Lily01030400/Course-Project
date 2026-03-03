`timescale 1ns / 1ps

module branch_metric(rst,en_brch,i_rx,hd1,hd2,hd3,hd4,hd5,hd6,hd7,hd8);

input rst, en_brch;
input [1:0] i_rx;

output reg [1:0] hd1,hd2,hd3,hd4,hd5,hd6,hd7,hd8;

always @(negedge rst or i_rx or en_brch)  
if(rst == 0)
begin
    hd1 = 0;
    hd2 = 0;
    hd3 = 0;
    hd4 = 0;
    hd5 = 0;
    hd6 = 0;
    hd7 = 0;
    hd8 = 0;
end
else
begin
        if (en_brch == 1) // en_branch_delay
        begin
            case (i_rx)
            2'b00:
            begin
                hd1 = 2'd0;
                hd2 = 2'd2;
                hd3 = 2'd1;
                hd4 = 2'd1;
                hd5 = 2'd2;
                hd6 = 2'd0;
                hd7 = 2'd1;
                hd8 = 2'd1;
            end
            
            2'b01:
            begin
                hd1 = 2'd1;
                hd2 = 2'd1;
                hd3 = 2'd2;
                hd4 = 2'd0;
                hd5 = 2'd1;
                hd6 = 2'd1;
                hd7 = 2'd0;
                hd8 = 2'd2;
            end
            
            2'b10:
            begin
                hd1 = 2'd1;
                hd2 = 2'd1;
                hd3 = 2'd0;
                hd4 = 2'd2;
                hd5 = 2'd1;
                hd6 = 2'd1;
                hd7 = 2'd2;
                hd8 = 2'd0;
            end
            
            2'b11:
            begin
                hd1 = 2'd2;
                hd2 = 2'd0;
                hd3 = 2'd1;
                hd4 = 2'd1;
                hd5 = 2'd0;
                hd6 = 2'd2;
                hd7 = 2'd1;
                hd8 = 2'd1;
            end
                
            endcase
        end
        else 
        begin
            hd1 = 0;
            hd2 = 0;
            hd3 = 0;
            hd4 = 0;
            hd5 = 0;
            hd6 = 0;
            hd7 = 0;
            hd8 = 0;
    end
end

endmodule

