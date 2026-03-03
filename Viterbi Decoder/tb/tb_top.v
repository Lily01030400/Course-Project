`timescale 1ns / 1ps

module viterbi_decoder_tb();

reg clk, rst, en;
reg [15:0] i_data;

wire [7:0] o_data;
wire o_done;

reg [5:0] count;
reg [12:0] index;
integer file_outputs;
integer error_count;  // Thêm biến đếm lỗi

reg [15:0] in_ram [0:1024];
reg [7:0] expected_ram [0:1024];  // Thêm mảng chứa kết quả mong đợi

viterbi_decoder vd1 (
    .clk(clk),
    .rst(rst),
    .en(en),
    .i_data(i_data),
    .o_data(o_data),
    .o_done(o_done)
);

always #5 clk = ~clk;

initial begin
    // Khởi tạo tín hiệu
    clk = 0;
    rst = 1;
    en = 1;
    
    // Reset
    #10 rst = 0;
    #1 rst = 1;
end

initial begin
    index <= 1;
    error_count = 0;  // Khởi tạo biến đếm lỗi
    
    $readmemb("C:/vlsi_src/viterbi_data/input.txt", in_ram);
    $readmemb("C:/vlsi_src/viterbi_data/output.txt", expected_ram);  // Đọc file kết quả mong đợi
    
    file_outputs = $fopen("C:/vlsi_src/viterbi_data/output_real.txt_", "w");
    i_data = in_ram[0];
end

always @(posedge o_done) begin
    // Ghi output
    $fwrite(file_outputs, "%b\n", o_data);
    
    // So sánh với kết quả mong đợi
    if (o_data !== expected_ram[index-1]) begin
        $display("[ERROR] Line %d: Expected %b, Got %b", index, expected_ram[index-1], o_data);
        error_count = error_count + 1;
    end else begin
        $display("[PASS]  Line %d: %b", index, o_data);
    end
    
    index <= index + 1;
    i_data <= in_ram[index];
    rst = 0;
    #1 rst = 1;
    
    if (index >= 1026) begin
        $fclose(file_outputs);
        
        // Hiển thị tổng kết
        $display("\n========== TEST SUMMARY ==========");
        $display("Total tests: %d", index-1);
        $display("Passed: %d", (index-1) - error_count);
        $display("Failed: %d", error_count);
        if (error_count == 0)
            $display("Result: ALL TESTS PASSED!");
        else
            $display("Result: SOME TESTS FAILED!");
        $display("==================================\n");
        
        $finish;
    end
end

endmodule