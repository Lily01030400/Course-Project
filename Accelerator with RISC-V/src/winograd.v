// File: winograd_conv_top.v
/* verilator lint_off DECLFILENAME */
module winograd_conv_top #(
    parameter DATA_WIDTH = 32,
    parameter FRAC_BITS  = 16
)(
    input  wire                  clk,
    input  wire                  rstn,
    input  wire                  start,
    output reg                   ready,
    output reg                   done,
    input  wire [7:0]            num_channels,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  data_valid,
    input  wire [DATA_WIDTH-1:0] filter_in,
    input  wire                  filter_valid,
    output reg  [DATA_WIDTH-1:0] data_out,
    output reg                   data_out_valid,
    output wire [3:0]            current_state
);
/* verilator lint_on DECLFILENAME */

    // ---------------------------------------------------------------
    // FSM States
    // ---------------------------------------------------------------
    localparam STATE_IDLE           = 4'd0;
    localparam STATE_FILTER_LOAD    = 4'd1;
    localparam STATE_FILTER_TRANS   = 4'd2;
    localparam STATE_INPUT_LOAD     = 4'd3;
    localparam STATE_INPUT_TRANS    = 4'd4;
    localparam STATE_ELEM_MULT      = 4'd5;
    localparam STATE_OUTPUT_TRANS   = 4'd6;
    localparam STATE_OUTPUT_COLLECT = 4'd7;
    localparam STATE_DONE           = 4'd8;

    reg [3:0] state;
    assign current_state = state;

    // ---------------------------------------------------------------
    // Incoming data buffers (filled by peripheral before start)
    // ---------------------------------------------------------------
    reg [DATA_WIDTH-1:0] filter_buffer [0:8];
    reg [DATA_WIDTH-1:0] data_buffer   [0:15];
    reg [3:0]            filter_count;
    reg [4:0]            data_count;

    // ---------------------------------------------------------------
    // Filter Transform wires/regs
    // ---------------------------------------------------------------
    reg                  filter_start;
    reg  [DATA_WIDTH-1:0] filter_g_in;
    reg  [3:0]           filter_g_count;
    reg                  filter_load_started;  // flag: đã fire filter_start rồi
    wire                 filter_done;
    wire                 filter_u_valid;
    wire [DATA_WIDTH-1:0] filter_u_out;
    wire [3:0]           filter_u_count;

    reg [DATA_WIDTH-1:0] u_buffer [0:15];

    // ---------------------------------------------------------------
    // Input Transform wires/regs
    // ---------------------------------------------------------------
    reg                  input_start;
    reg  [DATA_WIDTH-1:0] input_d_in;
    reg  [4:0]           input_d_count;  // 5-bit: cần đếm 0..16
    reg                  input_load_started;   // flag: đã fire input_start rồi
    wire                 input_done;
    wire                 input_v_valid;
    wire [DATA_WIDTH-1:0] input_v_out;
    wire [3:0]           input_v_count;

    reg [DATA_WIDTH-1:0] v_buffer [0:15];

    // ---------------------------------------------------------------
    // Element-wise wires/regs
    // ---------------------------------------------------------------
    reg                  elem_start;
    reg  [DATA_WIDTH-1:0] elem_u_in;
    reg  [DATA_WIDTH-1:0] elem_v_in;
    reg  [3:0]           elem_idx;
    reg  [7:0]           elem_ch_idx;
    reg  [7:0]           elem_num_ch;
    reg  [4:0]           elem_counter;
    wire [DATA_WIDTH-1:0] elem_m_out;
    /* verilator lint_off UNUSED */
    wire                 elem_valid_out_unused;
    wire                 elem_all_done_unused;
    /* verilator lint_on UNUSED */

    // ---------------------------------------------------------------
    // Output Transform wires/regs
    // ---------------------------------------------------------------
    reg                  output_start;
    reg  [3:0]           output_m_count;
    reg                  output_trans_started;   // Flag Bug #3: delay 1 cycle trước increment
    wire                 output_done;
    wire                 output_y_valid;          // NEW (Bug #8)
    wire [DATA_WIDTH-1:0] output_y_out;
    /* verilator lint_off UNUSED */
    wire [1:0]           output_y_count;
    /* verilator lint_on UNUSED */

    wire [3:0]            elem_read_idx_w  = output_m_count;
    wire [DATA_WIDTH-1:0] output_m_in_w    = elem_m_out;

    // ---------------------------------------------------------------
    // Sub-module instantiation
    // ---------------------------------------------------------------
    winograd_filter_transform #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_filter (
        .clk        (clk),
        .rstn       (rstn),
        .start      (filter_start),
        .g_in       (filter_g_in),
        .g_count    (filter_g_count),
        .done       (filter_done),
        .u_valid    (filter_u_valid),
        .u_out      (filter_u_out),
        .u_count    (filter_u_count)
    );

    winograd_input_transform #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_input (
        .clk        (clk),
        .rstn       (rstn),
        .start      (input_start),
        .d_in       (input_d_in),
        .d_count    (input_d_count[3:0]),
        .done       (input_done),
        .v_valid    (input_v_valid),
        .v_out      (input_v_out),
        .v_count    (input_v_count)
    );

    winograd_elementwise #(
        .DATA_WIDTH   (DATA_WIDTH),
        .FRAC_BITS    (FRAC_BITS),
        .NUM_ELEMENTS (16)
    ) u_elementwise (
        .clk        (clk),
        .rstn       (rstn),
        .start      (elem_start),
        .u_in       (elem_u_in),
        .v_in       (elem_v_in),
        .elem_idx   (elem_idx),
        .ch_idx     (elem_ch_idx),
        .num_ch     (elem_num_ch),
        .read_idx   (elem_read_idx_w),     // FIX Bug #3: wire
        .m_out      (elem_m_out),
        .valid_out  (elem_valid_out_unused),
        .all_done   (elem_all_done_unused)
    );

    winograd_output_transform #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_output (
        .clk        (clk),
        .rstn       (rstn),
        .start      (output_start),
        .m_in       (output_m_in_w),       // FIX Bug #3: wire
        .m_count    (output_m_count),
        .done       (output_done),
        .y_valid    (output_y_valid),      // FIX Bug #8: connect
        .y_out      (output_y_out),
        .y_count    (output_y_count)
    );

    // ---------------------------------------------------------------
    // Buffer incoming data from peripheral
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            filter_count <= 4'd0;
            data_count   <= 5'd0;
        end else begin
            if (filter_valid && filter_count < 4'd9) begin
                filter_buffer[filter_count] <= filter_in;
                filter_count <= filter_count + 4'd1;
            end
            if (data_valid && data_count < 5'd16) begin
                data_buffer[data_count[3:0]] <= data_in;
                data_count <= data_count + 5'd1;
            end
            // Reset counters khi computation xong (cho lần chạy tiếp)
            if (done) begin
                filter_count <= 4'd0;
                data_count   <= 5'd0;
            end
        end
    end

    
    integer i;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            for (i = 0; i < 16; i = i + 1) begin
                u_buffer[i] <= {DATA_WIDTH{1'b0}};
                v_buffer[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            // u_buffer[0..14] via valid path (offset -1)
            // u_buffer[15]   via done path (1 cycle sau khi done fire)
            if (filter_u_valid && filter_u_count > 4'd0)
                u_buffer[filter_u_count - 4'd1] <= filter_u_out;
            if (filter_done)
                u_buffer[4'd15] <= filter_u_out;

            // v_buffer: cùng logic
            if (input_v_valid && input_v_count > 4'd0)
                v_buffer[input_v_count - 4'd1] <= input_v_out;
            if (input_done)
                v_buffer[4'd15] <= input_v_out;
        end
    end

    // ---------------------------------------------------------------
    // Main FSM
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state                <= STATE_IDLE;
            ready                <= 1'b1;
            done                 <= 1'b0;
            data_out             <= {DATA_WIDTH{1'b0}};
            data_out_valid       <= 1'b0;
            filter_start         <= 1'b0;
            filter_g_in          <= {DATA_WIDTH{1'b0}};
            filter_g_count       <= 4'd0;
            filter_load_started  <= 1'b0;
            input_start          <= 1'b0;
            input_d_in           <= {DATA_WIDTH{1'b0}};
            input_d_count        <= 5'd0;
            input_load_started   <= 1'b0;
            elem_start           <= 1'b0;
            elem_u_in            <= {DATA_WIDTH{1'b0}};
            elem_v_in            <= {DATA_WIDTH{1'b0}};
            elem_idx             <= 4'd0;
            elem_ch_idx          <= 8'd0;
            elem_num_ch          <= 8'd0;
            elem_counter         <= 5'd0;
            output_start         <= 1'b0;
            output_m_count       <= 4'd0;
            output_trans_started <= 1'b0;
        end else begin
            // Default: clear one-shot signals
            data_out_valid <= 1'b0;
            done           <= 1'b0;
            filter_start   <= 1'b0;
            input_start    <= 1'b0;
            elem_start     <= 1'b0;
            output_start   <= 1'b0;

            case (state)

                // -------------------------------------------------------
                STATE_IDLE: begin
                    ready <= 1'b1;
                    if (start && filter_count == 4'd9 && data_count == 5'd16) begin
                        state               <= STATE_FILTER_LOAD;
                        filter_g_count      <= 4'd0;
                        filter_load_started <= 1'b0;   // reset cho lần chạy mới
                        ready               <= 1'b0;
                    end
                end


                STATE_FILTER_LOAD: begin
                    if (!filter_load_started) begin
                        // Cycle 0: gửi start + data[0] cùng lúc
                        filter_start        <= 1'b1;
                        filter_g_in         <= filter_buffer[4'd0];
                        filter_g_count      <= 4'd0;
                        filter_load_started <= 1'b1;
                    end else if (filter_g_count < 4'd8) begin
                        // Cycle 1+: gửi data[1..8]
                        filter_g_count <= filter_g_count + 4'd1;
                        filter_g_in    <= filter_buffer[filter_g_count + 4'd1];
                    end else begin
                        // Đã gửi xong data[8]
                        state <= STATE_FILTER_TRANS;
                    end
                end

                // -------------------------------------------------------
                STATE_FILTER_TRANS: begin
                    if (filter_done) begin
                        state              <= STATE_INPUT_LOAD;
                        input_d_count      <= 5'd0;
                        input_load_started <= 1'b0;   // reset cho lần chạy mới
                    end
                end

  
                STATE_INPUT_LOAD: begin
                    if (!input_load_started) begin
                        // Cycle 0: gửi start + data[0] cùng lúc
                        input_start        <= 1'b1;
                        input_d_in         <= data_buffer[4'd0];
                        input_d_count      <= 5'd0;
                        input_load_started <= 1'b1;
                    end else if (input_d_count < 5'd15) begin
                        // Cycle 1+: gửi data[1..15]
                        input_d_count <= input_d_count + 5'd1;
                        input_d_in    <= data_buffer[input_d_count[3:0] + 4'd1];
                    end else begin
                        // Đã gửi xong data[15]
                        state <= STATE_INPUT_TRANS;
                    end
                end

                // -------------------------------------------------------
                STATE_INPUT_TRANS: begin
                    if (input_done) begin
                        state        <= STATE_ELEM_MULT;
                        elem_counter <= 5'd0;
                        elem_ch_idx  <= 8'd0;
                        elem_num_ch  <= num_channels;
                    end
                end

                // -------------------------------------------------------
                // Element-wise multiply-accumulate
                // -------------------------------------------------------
                STATE_ELEM_MULT: begin
                    if (elem_counter < 5'd16) begin
                        elem_start   <= 1'b1;
                        elem_u_in    <= u_buffer[elem_counter[3:0]];
                        elem_v_in    <= v_buffer[elem_counter[3:0]];
                        elem_idx     <= elem_counter[3:0];
                        elem_counter <= elem_counter + 5'd1;
                    end else begin
                        if (elem_ch_idx + 8'd1 < elem_num_ch) begin
                            elem_ch_idx  <= elem_ch_idx + 8'd1;
                            elem_counter <= 5'd0;
                        end else begin
                            state                <= STATE_OUTPUT_TRANS;
                            output_m_count       <= 4'd0;
                            output_trans_started <= 1'b0;
                        end
                    end
                end

                
                // Timeline:
                //   Cycle 0: start=1, started=0→1, m_count=0 
                //     matrix_output: IDLE → LOAD (next)
                //   Cycle 1: started=1, m_count=0
                //     matrix_output LOAD: m_matrix[0][0] = m_buffer[0] ✓
                //     m_count → 1
                //   Cycle 2: m_count=1
                //     m_matrix[0][1] = m_buffer[1] ✓
                //   ...
                //   Cycle 16: m_count=15
                //     m_matrix[3][3] = m_buffer[15] ✓
                //     matrix_output: m_count==15 → COMPUTE_ATM
                //     → state = OUTPUT_COLLECT
                // -------------------------------------------------------
                STATE_OUTPUT_TRANS: begin
                    if (!output_trans_started) begin
                        output_start         <= 1'b1;
                        output_trans_started <= 1'b1;
                        // output_m_count giữ nguyên 0
                    end else if (output_m_count < 4'd15) begin
                        output_m_count <= output_m_count + 4'd1;
                    end else begin
                        // m_count == 15 đã được gửi, matrix_output tự chuyển COMPUTE
                        state <= STATE_OUTPUT_COLLECT;
                    end
                end

              
                STATE_OUTPUT_COLLECT: begin
                    if (output_y_valid) begin
                        data_out       <= output_y_out;
                        data_out_valid <= 1'b1;
                    end
                    // Capture pixel cuối (y[1][1]) khi done fire
                    // y_out register còn giữ y_matrix[1][1] ở cycle này
                    if (output_done) begin
                        data_out       <= output_y_out;
                        data_out_valid <= 1'b1;
                        state          <= STATE_DONE;
                    end
                end

                // -------------------------------------------------------
                STATE_DONE: begin
                    done  <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;

            endcase
        end
    end

endmodule
