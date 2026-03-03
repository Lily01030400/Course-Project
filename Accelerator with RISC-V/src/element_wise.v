// File: winograd_elementwise.v
//
// BUG FIX #6: elem_complete không bao giờ được reset giữa các lần chạy.
// Nguyên nhân: chỉ clear trong rstn block. Khi start lần 2, elem_complete
// vẫn = all-1 từ lần trước → all_done assert ngay lập tức → sai hoàn toàn.
// Fix: reset elem_complete[elem_idx] = 0 khi ch_idx == 0 (bắt đầu tính mới).
// Điều này an toàn vì ch_idx==0 luôn là lần đầu tiên process element đó.
//
// Ngoài ra: xóa $display để tránh simulation noise.

/* verilator lint_off DECLFILENAME */
module winograd_elementwise #(
    parameter DATA_WIDTH   = 32,
    parameter FRAC_BITS    = 16,
    parameter NUM_ELEMENTS = 16
)(
    input  wire                  clk,
    input  wire                  rstn,
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] u_in,
    input  wire [DATA_WIDTH-1:0] v_in,
    input  wire [3:0]            elem_idx,
    input  wire [7:0]            ch_idx,
    input  wire [7:0]            num_ch,
    input  wire [3:0]            read_idx,
    output reg  [DATA_WIDTH-1:0] m_out,
    output reg                   valid_out,
    output wire                  all_done
);
/* verilator lint_on DECLFILENAME */

    reg [DATA_WIDTH-1:0]   m_buffer     [0:NUM_ELEMENTS-1];
    reg [NUM_ELEMENTS-1:0] elem_complete;

    // Q16.16 fixed-point multiply
    /* verilator lint_off UNUSED */
    function [DATA_WIDTH-1:0] fp_mult;
        input signed [DATA_WIDTH-1:0] a, b;
        reg   signed [2*DATA_WIDTH-1:0] tmp;
        begin
            tmp     = $signed(a) * $signed(b);
            fp_mult = tmp[DATA_WIDTH+FRAC_BITS-1:FRAC_BITS];
        end
    endfunction
    /* verilator lint_on UNUSED */

    integer i;

    // Combinational read
    always @(*) m_out = m_buffer[read_idx];

    assign all_done = &elem_complete;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            valid_out     <= 1'b0;
            elem_complete <= {NUM_ELEMENTS{1'b0}};
            for (i = 0; i < NUM_ELEMENTS; i = i + 1)
                m_buffer[i] <= {DATA_WIDTH{1'b0}};
        end else begin
            valid_out <= 1'b0;

            if (start) begin
                if (ch_idx == 8'd0) begin
                    // FIX: clear complete flag khi bắt đầu element mới.
                    // Thiếu dòng này khiến lần chạy thứ 2 có all_done=1 ngay.
                    elem_complete[elem_idx] <= 1'b0;
                    m_buffer[elem_idx]      <= fp_mult(u_in, v_in);
                end else begin
                    m_buffer[elem_idx] <= m_buffer[elem_idx] + fp_mult(u_in, v_in);
                end

                if (ch_idx == num_ch - 8'd1) begin
                    elem_complete[elem_idx] <= 1'b1;
                    valid_out               <= 1'b1;
                end
            end
        end
    end

endmodule
