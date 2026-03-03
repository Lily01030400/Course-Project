`timescale 1ns / 1ps

module tb_add_comp_slt;

    // 1. Khai báo tín hiệu
    reg clk;
    reg rst;
    reg en_acs;
    reg [1:0] hd1, hd2, hd3, hd4, hd5, hd6, hd7, hd8;

    wire [1:0] prev_st_00, prev_st_10, prev_st_01, prev_st_11;
    wire [1:0] slt_node;

    // 2. Các biến dùng cho Auto Check (Mô hình tham chiếu)
    reg [4:0] shadow_sum00, shadow_sum10, shadow_sum01, shadow_sum11;
    reg [4:0] next_shadow_sum00, next_shadow_sum10, next_shadow_sum01, next_shadow_sum11;
    reg [1:0] exp_prev_st_00, exp_prev_st_10, exp_prev_st_01, exp_prev_st_11;
    integer i;
    integer error_count;

    // 3. Kết nối với DUT (Design Under Test)
    add_comp_slt uut (
        .clk(clk), 
        .rst(rst), 
        .en_acs(en_acs), 
        .hd1(hd1), .hd2(hd2), .hd3(hd3), .hd4(hd4), 
        .hd5(hd5), .hd6(hd6), .hd7(hd7), .hd8(hd8), 
        .prev_st_00(prev_st_00), 
        .prev_st_10(prev_st_10), 
        .prev_st_01(prev_st_01), 
        .prev_st_11(prev_st_11), 
        .slt_node(slt_node)
    );

    // 4. Tạo xung Clock (Chu kỳ 10ns)
    always #5 clk = ~clk;

    // 5. Chương trình chính
    initial begin
        // Khởi tạo
        clk = 0;
        rst = 0;
        en_acs = 0;
        error_count = 0;
        
        // Khởi tạo giá trị input
        {hd1, hd2, hd3, hd4, hd5, hd6, hd7, hd8} = 0;

        // Reset hệ thống
        $display("-------------------------------------------");
        $display("BAT DAU MO PHONG VA AUTO CHECK");
        $display("-------------------------------------------");
        
        #20;
        rst = 1; // Thả reset
        
        // Khởi tạo giá trị shadow sum (giống như trong DUT khi reset)
        shadow_sum00 = 0; shadow_sum10 = 0; shadow_sum01 = 0; shadow_sum11 = 0;

        #10;
        en_acs = 1;

        // Chạy vòng lặp kiểm tra 10 chu kỳ (tương ứng với count tăng dần)
        for (i = 0; i < 10; i = i + 1) begin
            // Tạo dữ liệu ngẫu nhiên cho các khoảng cách Hamming (hd)
            hd1 = $random % 4; hd2 = $random % 4; hd3 = $random % 4; hd4 = $random % 4;
            hd5 = $random % 4; hd6 = $random % 4; hd7 = $random % 4; hd8 = $random % 4;

            // Đợi cạnh lên xung nhịp để DUT xử lý
            @(posedge clk);
            
            // Đợi 1 chút sau cạnh lên để output ổn định (1ns) rồi mới check
            #1; 
            
            // Thực hiện tính toán mẫu và so sánh
            perform_auto_check();
            
            // Cập nhật shadow sums cho vòng lặp tiếp theo
            update_shadow_sums();
        end

        // Kiểm tra kết quả tổng kết (slt_node) khi count >= 8
        // Lưu ý: Logic tìm min trong DUT của bạn có thể cần chỉnh sửa (xem phần góp ý bên dưới)
        // Testbench này sẽ kiểm tra xem logic prev_st có đúng từng bước không.

        #20;
        if (error_count == 0)
            $display("\n---> KET QUA: TEST PASSED! KHONG CO LOI.\n");
        else
            $display("\n---> KET QUA: TEST FAILED! SO LOI: %d\n", error_count);
            
        $finish;
    end

    // ==========================================================
    // TASK: Tính toán giá trị mong đợi và so sánh
    // ==========================================================
    task perform_auto_check;
        reg [4:0] path0, path1;
        begin
            // --- Kiem tra Node 00 ---
            // Nguon: Node 00 (hd1) vs Node 01 (hd5)
            path0 = hd1 + shadow_sum00;
            path1 = hd5 + shadow_sum01;
            
            if (path0 <= path1) begin
                exp_prev_st_00 = 2'b00;
                next_shadow_sum00 = path0;
            end else begin
                exp_prev_st_00 = 2'b01;
                next_shadow_sum00 = path1;
            end

            // --- Kiem tra Node 10 ---
            // Nguon: Node 00 (hd2) vs Node 01 (hd6)
            path0 = hd2 + shadow_sum00;
            path1 = hd6 + shadow_sum01;
            
            if (path0 <= path1) begin
                exp_prev_st_10 = 2'b00;
                next_shadow_sum10 = path0;
            end else begin
                exp_prev_st_10 = 2'b01;
                next_shadow_sum10 = path1;
            end

            // --- Kiem tra Node 01 ---
            // Nguon: Node 10 (hd3) vs Node 11 (hd7)
            path0 = hd3 + shadow_sum10;
            path1 = hd7 + shadow_sum11;
            
            if (path0 <= path1) begin
                exp_prev_st_01 = 2'b10;
                next_shadow_sum01 = path0;
            end else begin
                exp_prev_st_01 = 2'b11;
                next_shadow_sum01 = path1;
            end

            // --- Kiem tra Node 11 ---
            // Nguon: Node 10 (hd4) vs Node 11 (hd8)
            path0 = hd4 + shadow_sum10;
            path1 = hd8 + shadow_sum11;
            
            if (path0 <= path1) begin
                exp_prev_st_11 = 2'b10;
                next_shadow_sum11 = path0;
            end else begin
                exp_prev_st_11 = 2'b11;
                next_shadow_sum11 = path1;
            end

            // --- So sanh Expected vs Actual ---
            if (prev_st_00 !== exp_prev_st_00) begin
                $display("[LOI Node 00] Time %t: Mong doi %b, Thuc te %b", $time, exp_prev_st_00, prev_st_00);
                error_count = error_count + 1;
            end
            if (prev_st_10 !== exp_prev_st_10) begin
                $display("[LOI Node 10] Time %t: Mong doi %b, Thuc te %b", $time, exp_prev_st_10, prev_st_10);
                error_count = error_count + 1;
            end
            if (prev_st_01 !== exp_prev_st_01) begin
                $display("[LOI Node 01] Time %t: Mong doi %b, Thuc te %b", $time, exp_prev_st_01, prev_st_01);
                error_count = error_count + 1;
            end
            if (prev_st_11 !== exp_prev_st_11) begin
                $display("[LOI Node 11] Time %t: Mong doi %b, Thuc te %b", $time, exp_prev_st_11, prev_st_11);
                error_count = error_count + 1;
            end
        end
    endtask

    // ==========================================================
    // TASK: Cập nhật biến shadow sum (mô phỏng thanh ghi)
    // ==========================================================
    task update_shadow_sums;
        begin
            shadow_sum00 = next_shadow_sum00;
            shadow_sum10 = next_shadow_sum10;
            shadow_sum01 = next_shadow_sum01;
            shadow_sum11 = next_shadow_sum11;
        end
    endtask

endmodule
