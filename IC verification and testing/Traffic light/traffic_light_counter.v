module counter #(
    parameter green_time = 30,
    parameter yellow_time = 3
)
(
    input clk,
    input rst,
    input [2:0] street_a,
    input [2:0] street_b,
    output g_end,
    output y_end
);

reg [$clog2(green_time) - 1 : 0] count ;                // giá trị bộ đếm tgian hiện tại
reg [$clog2(green_time) - 1 : 0] count_next ;
wire fsm_g;                                               // tín hiệu cho biết hệ thống đang ở đèn nào
wire fsm_y;

assign fsm_g = street_a[2] | street_b[2];                   //strA hoặc B có đèn xanh thì fsm_g = 1
assign fsm_y = street_a[1] | street_b[1];                       // để biết đèn đang ở pha nào


assign g_end = fsm_g & (count == green_time - 1 );          
assign y_end = fsm_y & (count == yellow_time - 1); // khi đèn xanh (fsm_g = 1) và bộ đếm đạt TIME_G - 1, thì g_end = 1.//→ báo đã hết thời gian đèn xanh.
                                                        
//store curr counter value at each clu cycle                                                 
always @(posedge clk or negedge rst) begin
    if (~rst) begin
        count <= 'b0;
    end else begin
        count <= count_next;
    end
end
always @(g_end or y_end or count) begin
    if (g_end | y_end) begin
    // If the green or yellow light ends, reset the counter
        count_next = 'b0;
    end
    else begin
    // Otherwise, increment the counter by 1
        count_next = count + 1'b1;
    end

end
 
endmodule
