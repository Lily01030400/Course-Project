`timescale 1ns / 1ps

module viterbi_decoder(clk,rst,en,i_data,o_data,o_done);

input clk,rst,en;
input [15:0] i_data;

output [7:0] o_data;
output o_done;

wire en_e,en_b,en_a,en_m,en_t;
wire [1:0] rx;
wire [1:0] hd1,hd2,hd3,hd4,hd5,hd6,hd7,hd8;
wire [1:0] prv_st_00,prv_st_10,prv_st_01,prv_st_11;
wire [1:0] node;
wire [1:0] bck_prv_st_00,bck_prv_st_10,bck_prv_st_01,bck_prv_st_11;

control c1 (.clk(clk),
            .rst(rst),
            .en(en),
            .en_ext(en_e),
            .en_brch(en_b),
            .en_acs(en_a),
            .en_mem(en_m),
            .en_trbk(en_t));

extract_bit ex1 (.rst(rst),
                 .clk(clk),
                 .en_ext(en_e),
                 .i_data(i_data),
                 .o_rx(rx));
                 
branch_metric br1 (.rst(rst),
                   .en_brch(en_b),
                   .i_rx(rx),
                   .hd1(hd1),
                   .hd2(hd2),
                   .hd3(hd3),
                   .hd4(hd4),
                   .hd5(hd5),
                   .hd6(hd6),
                   .hd7(hd7),
                   .hd8(hd8));

add_comp_slt add1 (.clk(clk),
                   .rst(rst),
                   .en_acs(en_a),
                   .hd1(hd1),
                   .hd2(hd2),
                   .hd3(hd3),
                   .hd4(hd4),
                   .hd5(hd5),
                   .hd6(hd6),
      	           .hd7(hd7),
                   .hd8(hd8),
                   .prev_st_00(prv_st_00),
                   .prev_st_10(prv_st_10),
                   .prev_st_01(prv_st_01),
                   .prev_st_11(prv_st_11),
                   .slt_node(node));

 memory m1 (.clk(clk),
            .rst(rst),
            .en_mem(en_m),
            .prev_st_00(prv_st_00),
            .prev_st_10(prv_st_10),
            .prev_st_01(prv_st_01),
            .prev_st_11(prv_st_11),
            .bck_prev_st_00(bck_prv_st_00),
            .bck_prev_st_10(bck_prv_st_10),
            .bck_prev_st_01(bck_prv_st_01),
            .bck_prev_st_11(bck_prv_st_11));

traceback tr1 (.clk(clk),
               .rst(rst),
               .en_trbk(en_t),
               .slt_node(node),
               .bck_prev_st_00(bck_prv_st_00),
               .bck_prev_st_10(bck_prv_st_10),
               .bck_prev_st_01(bck_prv_st_01),
               .bck_prev_st_11(bck_prv_st_11),
               .o_data(o_data),
               .o_done(o_done));

endmodule

