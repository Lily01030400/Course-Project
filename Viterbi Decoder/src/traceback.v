`timescale 1ns / 1ps

module traceback(
    input clk,
    input rst,
    input en_trbk,
    input [1:0] slt_node,
    input [1:0] bck_prev_st_00,
    input [1:0] bck_prev_st_10,
    input [1:0] bck_prev_st_01,
    input [1:0] bck_prev_st_11,
    output reg [7:0] o_data,
    output reg o_done
);

    reg [7:0] select_bit_out;
    reg [3:0] count;
    
    // Tín hiệu nội bộ cho logic tổ hợp
    reg in_bit_comb;
    reg [1:0] nxt_slt_node_comb;

    localparam [1:0] s0 = 2'b00;
    localparam [1:0] s1 = 2'b01;
    localparam [1:0] s2 = 2'b10;
    localparam [1:0] s3 = 2'b11;

    reg [1:0] curr_slt_node;

    // -----------------------------------------------------------
    // KHỐI 1: Combinational Logic (Tính toán trạng thái kế tiếp và bit đầu vào)
    // -----------------------------------------------------------
    always @(*) 
    begin
        // Giá trị mặc định để tránh tạo Latch
        nxt_slt_node_comb = curr_slt_node;
        in_bit_comb = 0;

        case (curr_slt_node)
            s0: // 00 
            begin 
                if (bck_prev_st_00 == 2'b00)
                    nxt_slt_node_comb = s0;
                else
                    nxt_slt_node_comb = s1;
                
                in_bit_comb = 0;
            end
            
            s1: // 01
            begin
                if (bck_prev_st_01 == 2'b10)
                    nxt_slt_node_comb = s2;
                else
                    nxt_slt_node_comb = s3;
                
                in_bit_comb = 0;
            end
            
            s2: // 10
            begin
                if (bck_prev_st_10 == 2'b00)
                    nxt_slt_node_comb = s0;
                else
                    nxt_slt_node_comb = s1;
                
                in_bit_comb = 1;
            end
            
            s3: // 11
            begin
                if (bck_prev_st_11 == 2'b10)
                    nxt_slt_node_comb = s2;
                else
                    nxt_slt_node_comb = s3;
                
                in_bit_comb = 1;
            end
            
            default: begin
                nxt_slt_node_comb = s0;
                in_bit_comb = 0;
            end
        endcase
    end

    // -----------------------------------------------------------
    // KHỐI 2: Sequential Logic (Cập nhật thanh ghi theo Clock)
    // -----------------------------------------------------------
    always @(posedge clk or negedge rst)
    begin
        if (rst == 0)
        begin
            o_data <= 0;
            o_done <= 0;
            select_bit_out <= 8'b00000000;
            count <= 0;
            curr_slt_node <= s0;
        end
        else
        begin
            if (en_trbk == 1) 
            begin
                // Nếu chưa đủ 8 bit, tiếp tục traceback
                if (count < 8) begin
                    // Cập nhật trạng thái
                    curr_slt_node <= nxt_slt_node_comb;
                    
                    // Ghi bit vào vị trí count
                    select_bit_out[count] <= in_bit_comb;
                    
                    // Tăng biến đếm
                    count <= count + 1;
                    
                    o_done <= 0; // Chưa xong
                end
                else if (count == 8) begin
                    // Khi đã đủ 8 bit, xuất dữ liệu ra
                    o_data <= select_bit_out;
                    o_done <= 1;
                    
                    // Reset count về 0 để chuẩn bị cho lần sau (hoặc giữ nguyên tùy logic của bạn)
                    count <= 0; 
                end
            end
            else
            begin 
                // Khi không enable traceback, load giá trị khởi đầu
                curr_slt_node <= slt_node; 
                count <= 0;
                select_bit_out <= 8'b00000000;
                o_done <= 0;
            end
        end
    end

endmodule 