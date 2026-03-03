module traffic_light_top (
    input clk,
    input rst,
    output [2:0] street_a,
    output [2:0] street_b
);
wire g_end;
wire y_end;
traffic_light_fsm traffic_light_fsm(
    .clk(clk),
    .rst(rst),
    .street_a(street_a),
    .street_b(street_b),
    .g_end(g_end),
    .y_end(y_end)
);
counter #(
    .green_time(30),
    .yellow_time(3)
)counter(
    .clk(clk),
    .rst(rst),
    .street_a(street_a),
    .street_b(street_b),
    .g_end(g_end),
    .y_end(y_end)
); 
endmodule
