`timescale 1ns/1ps

module traffic_light_tb();
//inputs, output
reg          clk;
reg          rst;
wire  [2:0]  street_a;
wire  [2:0]  street_b;

  // ==== Kết nối module cần test (DUT - Device Under Test) ====
  traffic_light_top uut (
    .clk       (clk),
    .rst       (rst),
    .street_a  (street_a),
    .street_b  (street_b)
  );

  // ==== Tạo tín hiệu clock ====
  always begin
    #5 clk = ~clk;    // Mỗi 5ns đảo mức 1 lần → chu kỳ clock = 10ns
  end

  // ==== Khối khởi tạo và reset ====
  initial begin
    clk = 1'b0;
    rst = 1'b0;        // Giữ reset ban đầu
    #10;
    rst = 1'b1;        // Thả reset sau 10ns
    #5000;
    $finish;           // Kết thúc mô phỏng sau 5000ns
  end

  // ==== In ra thông tin để quan sát ====
  initial begin
    $display("==============================================");
    $display(" Thoi gian (ns) |  street_a  |  street_b ");
    $display("  bit[2]=Xanh  bit[1]=Vang  bit[0]=Do ");
    $display("==============================================");
    $monitor("%8t ns     |    %b    |    %b", $time, street_a, street_b);
  end

endmodule
