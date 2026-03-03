// File: interface.v  (DP2 Multi-Channel Winograd Peripheral)
//
// DP2 Approach: CPU loop qua từng channel bên ngoài, hardware chỉ xử lý 1 channel/lần.
//
// Flow cho C channels:
//   CLEAR_ACC (1 lần): ghi CTRL[4]=1 → acc_buffer = 0
//   for ch = 0..C-1:
//     ghi filter[ch] vào FILTER_BUF (0x200-0x220)
//     ghi input[ch]  vào INPUT_BUF  (0x100-0x13C)
//     ghi CTRL = START | ACCUM_EN   (0x09)
//     poll STATUS[0] == 0  (BUSY)
//   đọc acc_buffer (0x400-0x40C) → kết quả tích lũy tất cả channels
//
// Tính đúng vì: Σ_ch A^T*(U[ch]⊙V[ch])*A = A^T*(Σ_ch U[ch]⊙V[ch])*A
//
// Register map (base = 0x9000000):
//   0x000  CTRL:   [0]=START [1]=RESET [2]=IRQ_EN [3]=ACCUM_EN [4]=CLEAR_ACC
//   0x004  STATUS: [0]=BUSY  [1]=DONE
//   0x100-0x13C  INPUT_BUF  (16 × 4 bytes)
//   0x200-0x220  FILTER_BUF (9  × 4 bytes)
//   0x300-0x30C  OUTPUT_BUF (4  × 4 bytes, channel cuối)
//   0x400-0x40C  ACC_BUF    (4  × 4 bytes, tích lũy tất cả channels)
//
/* verilator lint_off DECLFILENAME */
module winograd_peripheral #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 28,
    parameter FRAC_BITS  = 16
)(
    input  wire                  clk,
    input  wire                  rstn,

    /* verilator lint_off UNUSED */
    input  wire [ADDR_WIDTH-1:0] data_addr,
    /* verilator lint_on UNUSED */
    input  wire [1:0]            data_write_n,
    input  wire [1:0]            data_read_n,
    input  wire [DATA_WIDTH-1:0] data_in,
    /* verilator lint_off UNUSED */
    input  wire                  data_read_complete,
    /* verilator lint_on UNUSED */

    output reg  [DATA_WIDTH-1:0] data_out,
    output reg                   data_ready,
    output reg                   winograd_irq
);
/* verilator lint_on DECLFILENAME */

    // ---------------------------------------------------------------
    // Address map constants
    // ---------------------------------------------------------------
    localparam CTRL_REG_OFFSET   = 12'h000;
    localparam STATUS_REG_OFFSET = 12'h004;
    localparam CONFIG_REG_OFFSET = 12'h008;   // backward compat (read/write, general purpose)
    localparam INPUT_BUF_OFFSET  = 12'h100;
    localparam FILTER_BUF_OFFSET = 12'h200;
    localparam OUTPUT_BUF_OFFSET = 12'h300;
    localparam ACC_BUF_OFFSET    = 12'h400;

    localparam CTRL_START_BIT     = 0;
    localparam CTRL_RESET_BIT     = 1;  // unused, reserved
    localparam CTRL_IRQ_EN_BIT    = 2;
    localparam CTRL_ACCUM_EN_BIT  = 3;  // cộng output vào acc_buffer
    localparam CTRL_CLEAR_ACC_BIT = 4;  // pulse: xóa acc_buffer

    localparam STATUS_BUSY_BIT = 0;
    localparam STATUS_DONE_BIT = 1;

    // ---------------------------------------------------------------
    // Internal registers
    // ---------------------------------------------------------------
    reg [DATA_WIDTH-1:0] ctrl_reg;
    reg [DATA_WIDTH-1:0] status_reg;
    reg [DATA_WIDTH-1:0] config_reg;   // general purpose config (backward compat)

    reg [DATA_WIDTH-1:0] input_buffer_0,  input_buffer_1,  input_buffer_2,  input_buffer_3;
    reg [DATA_WIDTH-1:0] input_buffer_4,  input_buffer_5,  input_buffer_6,  input_buffer_7;
    reg [DATA_WIDTH-1:0] input_buffer_8,  input_buffer_9,  input_buffer_10, input_buffer_11;
    reg [DATA_WIDTH-1:0] input_buffer_12, input_buffer_13, input_buffer_14, input_buffer_15;

    reg [DATA_WIDTH-1:0] filter_buffer_0, filter_buffer_1, filter_buffer_2;
    reg [DATA_WIDTH-1:0] filter_buffer_3, filter_buffer_4, filter_buffer_5;
    reg [DATA_WIDTH-1:0] filter_buffer_6, filter_buffer_7, filter_buffer_8;

    reg [DATA_WIDTH-1:0] output_buffer_0, output_buffer_1,
                         output_buffer_2, output_buffer_3;

    reg signed [DATA_WIDTH-1:0] acc_buffer_0, acc_buffer_1,
                                acc_buffer_2, acc_buffer_3;

    // ---------------------------------------------------------------
    // Address decode
    // ---------------------------------------------------------------
    wire is_wino_addr  = (data_addr[27:20] == 8'h90);
    wire [11:0] laddr  = data_addr[11:0];

    wire is_ctrl       = (laddr == CTRL_REG_OFFSET);
    wire is_status     = (laddr == STATUS_REG_OFFSET);
    wire is_config     = (laddr == CONFIG_REG_OFFSET);
    wire is_input_buf  = (laddr >= INPUT_BUF_OFFSET)  && (laddr < INPUT_BUF_OFFSET  + 12'd64);
    wire is_filter_buf = (laddr >= FILTER_BUF_OFFSET) && (laddr < FILTER_BUF_OFFSET + 12'd36);
    wire is_output_buf = (laddr >= OUTPUT_BUF_OFFSET) && (laddr < OUTPUT_BUF_OFFSET + 12'd16);
    wire is_acc_buf    = (laddr >= ACC_BUF_OFFSET)    && (laddr < ACC_BUF_OFFSET    + 12'd16);

    /* verilator lint_off WIDTH */
    wire [3:0] input_idx  = (laddr - INPUT_BUF_OFFSET)  >> 2;
    wire [3:0] filter_idx = (laddr - FILTER_BUF_OFFSET) >> 2;
    wire [1:0] output_idx = (laddr - OUTPUT_BUF_OFFSET) >> 2;
    wire [1:0] acc_idx    = (laddr - ACC_BUF_OFFSET)    >> 2;
    /* verilator lint_on WIDTH */

    wire write_req = is_wino_addr && (data_write_n != 2'b11);
    wire read_req  = is_wino_addr && (data_read_n  != 2'b11);

    // ---------------------------------------------------------------
    // Winograd core wires
    // ---------------------------------------------------------------
    wire wino_start        = (feed_state == FEED_START);
    wire wino_filter_valid = (feed_state == FEED_FILTER);
    wire wino_data_valid   = (feed_state == FEED_INPUT);
    wire wino_done;
    /* verilator lint_off UNUSED */
    wire wino_ready;
    wire [3:0] wino_state;
    /* verilator lint_on UNUSED */
    wire wino_data_out_valid;
    wire [DATA_WIDTH-1:0] wino_data_out;

    reg [DATA_WIDTH-1:0] wino_filter_in;
    reg [DATA_WIDTH-1:0] wino_data_in;

    // Feed FSM
    reg [2:0] feed_state;
    reg [3:0] feed_counter;
    reg       feed_active;
    reg       wino_done_latched;

    localparam FEED_IDLE    = 3'd0;
    localparam FEED_FILTER  = 3'd1;
    localparam FEED_INPUT   = 3'd2;
    localparam FEED_START   = 3'd3;
    localparam FEED_WAIT    = 3'd4;
    localparam FEED_COLLECT = 3'd5;

    winograd_conv_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_BITS (FRAC_BITS)
    ) winograd_core (
        .clk           (clk),
        .rstn          (rstn),
        .start         (wino_start),
        .ready         (wino_ready),
        .done          (wino_done),
        .num_channels  (8'd1),
        .data_in       (wino_data_in),
        .data_valid    (wino_data_valid),
        .filter_in     (wino_filter_in),
        .filter_valid  (wino_filter_valid),
        .data_out      (wino_data_out),
        .data_out_valid(wino_data_out_valid),
        .current_state (wino_state)
    );

    // Mux filter → core
    always @(*) begin
        case (feed_counter[3:0])
            4'd0: wino_filter_in = filter_buffer_0;
            4'd1: wino_filter_in = filter_buffer_1;
            4'd2: wino_filter_in = filter_buffer_2;
            4'd3: wino_filter_in = filter_buffer_3;
            4'd4: wino_filter_in = filter_buffer_4;
            4'd5: wino_filter_in = filter_buffer_5;
            4'd6: wino_filter_in = filter_buffer_6;
            4'd7: wino_filter_in = filter_buffer_7;
            4'd8: wino_filter_in = filter_buffer_8;
            default: wino_filter_in = {DATA_WIDTH{1'b0}};
        endcase
    end

    // Mux input → core
    always @(*) begin
        case (feed_counter[3:0])
            4'd0:  wino_data_in = input_buffer_0;
            4'd1:  wino_data_in = input_buffer_1;
            4'd2:  wino_data_in = input_buffer_2;
            4'd3:  wino_data_in = input_buffer_3;
            4'd4:  wino_data_in = input_buffer_4;
            4'd5:  wino_data_in = input_buffer_5;
            4'd6:  wino_data_in = input_buffer_6;
            4'd7:  wino_data_in = input_buffer_7;
            4'd8:  wino_data_in = input_buffer_8;
            4'd9:  wino_data_in = input_buffer_9;
            4'd10: wino_data_in = input_buffer_10;
            4'd11: wino_data_in = input_buffer_11;
            4'd12: wino_data_in = input_buffer_12;
            4'd13: wino_data_in = input_buffer_13;
            4'd14: wino_data_in = input_buffer_14;
            4'd15: wino_data_in = input_buffer_15;
            default: wino_data_in = {DATA_WIDTH{1'b0}};
        endcase
    end

    // ---------------------------------------------------------------
    // Write handler
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            ctrl_reg        <= 32'h0;
            config_reg      <= 32'h0;
            input_buffer_0  <= 32'h0; input_buffer_1  <= 32'h0;
            input_buffer_2  <= 32'h0; input_buffer_3  <= 32'h0;
            input_buffer_4  <= 32'h0; input_buffer_5  <= 32'h0;
            input_buffer_6  <= 32'h0; input_buffer_7  <= 32'h0;
            input_buffer_8  <= 32'h0; input_buffer_9  <= 32'h0;
            input_buffer_10 <= 32'h0; input_buffer_11 <= 32'h0;
            input_buffer_12 <= 32'h0; input_buffer_13 <= 32'h0;
            input_buffer_14 <= 32'h0; input_buffer_15 <= 32'h0;
            filter_buffer_0 <= 32'h0; filter_buffer_1 <= 32'h0;
            filter_buffer_2 <= 32'h0; filter_buffer_3 <= 32'h0;
            filter_buffer_4 <= 32'h0; filter_buffer_5 <= 32'h0;
            filter_buffer_6 <= 32'h0; filter_buffer_7 <= 32'h0;
            filter_buffer_8 <= 32'h0;
        end else begin
            // Auto-clear START và CLEAR_ACC sau 1 cycle
            if (ctrl_reg[CTRL_START_BIT] && feed_active)
                ctrl_reg[CTRL_START_BIT] <= 1'b0;
            if (ctrl_reg[CTRL_CLEAR_ACC_BIT])
                ctrl_reg[CTRL_CLEAR_ACC_BIT] <= 1'b0;

            if (write_req) begin
                if (is_ctrl) begin
                    ctrl_reg <= data_in;
                end else if (is_config) begin
                    config_reg <= data_in;
                end else if (is_input_buf) begin
                    case (input_idx)
                        4'd0:  input_buffer_0  <= data_in;
                        4'd1:  input_buffer_1  <= data_in;
                        4'd2:  input_buffer_2  <= data_in;
                        4'd3:  input_buffer_3  <= data_in;
                        4'd4:  input_buffer_4  <= data_in;
                        4'd5:  input_buffer_5  <= data_in;
                        4'd6:  input_buffer_6  <= data_in;
                        4'd7:  input_buffer_7  <= data_in;
                        4'd8:  input_buffer_8  <= data_in;
                        4'd9:  input_buffer_9  <= data_in;
                        4'd10: input_buffer_10 <= data_in;
                        4'd11: input_buffer_11 <= data_in;
                        4'd12: input_buffer_12 <= data_in;
                        4'd13: input_buffer_13 <= data_in;
                        4'd14: input_buffer_14 <= data_in;
                        4'd15: input_buffer_15 <= data_in;
                        default: ;
                    endcase
                end else if (is_filter_buf) begin
                    case (filter_idx[3:0])
                        4'd0: filter_buffer_0 <= data_in;
                        4'd1: filter_buffer_1 <= data_in;
                        4'd2: filter_buffer_2 <= data_in;
                        4'd3: filter_buffer_3 <= data_in;
                        4'd4: filter_buffer_4 <= data_in;
                        4'd5: filter_buffer_5 <= data_in;
                        4'd6: filter_buffer_6 <= data_in;
                        4'd7: filter_buffer_7 <= data_in;
                        4'd8: filter_buffer_8 <= data_in;
                        default: ;
                    endcase
                end
            end
        end
    end

    // ---------------------------------------------------------------
    // Read handler
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            data_out   <= 32'h0;
            data_ready <= 1'b0;
        end else begin
            data_ready <= 1'b0;
            if (read_req) begin
                data_ready <= 1'b1;
                if (is_ctrl) begin
                    data_out <= ctrl_reg;
                end else if (is_status) begin
                    data_out <= status_reg;
                end else if (is_config) begin
                    data_out <= config_reg;
                end else if (is_input_buf) begin
                    case (input_idx)
                        4'd0:  data_out <= input_buffer_0;
                        4'd1:  data_out <= input_buffer_1;
                        4'd2:  data_out <= input_buffer_2;
                        4'd3:  data_out <= input_buffer_3;
                        4'd4:  data_out <= input_buffer_4;
                        4'd5:  data_out <= input_buffer_5;
                        4'd6:  data_out <= input_buffer_6;
                        4'd7:  data_out <= input_buffer_7;
                        4'd8:  data_out <= input_buffer_8;
                        4'd9:  data_out <= input_buffer_9;
                        4'd10: data_out <= input_buffer_10;
                        4'd11: data_out <= input_buffer_11;
                        4'd12: data_out <= input_buffer_12;
                        4'd13: data_out <= input_buffer_13;
                        4'd14: data_out <= input_buffer_14;
                        4'd15: data_out <= input_buffer_15;
                        default: data_out <= 32'h0;
                    endcase
                end else if (is_filter_buf) begin
                    case (filter_idx[3:0])
                        4'd0: data_out <= filter_buffer_0;
                        4'd1: data_out <= filter_buffer_1;
                        4'd2: data_out <= filter_buffer_2;
                        4'd3: data_out <= filter_buffer_3;
                        4'd4: data_out <= filter_buffer_4;
                        4'd5: data_out <= filter_buffer_5;
                        4'd6: data_out <= filter_buffer_6;
                        4'd7: data_out <= filter_buffer_7;
                        4'd8: data_out <= filter_buffer_8;
                        default: data_out <= 32'h0;
                    endcase
                end else if (is_output_buf) begin
                    case (output_idx)
                        2'd0: data_out <= output_buffer_0;
                        2'd1: data_out <= output_buffer_1;
                        2'd2: data_out <= output_buffer_2;
                        2'd3: data_out <= output_buffer_3;
                        default: data_out <= 32'h0;
                    endcase
                end else if (is_acc_buf) begin
                    case (acc_idx)
                        2'd0: data_out <= acc_buffer_0;
                        2'd1: data_out <= acc_buffer_1;
                        2'd2: data_out <= acc_buffer_2;
                        2'd3: data_out <= acc_buffer_3;
                        default: data_out <= 32'h0;
                    endcase
                end else begin
                    data_out <= 32'hDEADBEEF;
                end
            end
        end
    end

    // ---------------------------------------------------------------
    // Feed FSM
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            feed_state   <= FEED_IDLE;
            feed_counter <= 4'd0;
            feed_active  <= 1'b0;
        end else begin
            case (feed_state)
                FEED_IDLE: begin
                    feed_active <= 1'b0;
                    if (ctrl_reg[CTRL_START_BIT] && !status_reg[STATUS_BUSY_BIT]) begin
                        feed_state   <= FEED_FILTER;
                        feed_counter <= 4'd0;
                        feed_active  <= 1'b1;
                    end
                end

                FEED_FILTER: begin
                    if (feed_counter == 4'd8) begin
                        feed_state   <= FEED_INPUT;
                        feed_counter <= 4'd0;
                    end else
                        feed_counter <= feed_counter + 4'd1;
                end

                FEED_INPUT: begin
                    if (feed_counter == 4'd15) begin
                        feed_state   <= FEED_START;
                        feed_counter <= 4'd0;
                    end else
                        feed_counter <= feed_counter + 4'd1;
                end

                FEED_START: begin
                    feed_state <= FEED_WAIT;
                end

                FEED_WAIT: begin
                    // data_out_valid có thể fire TRƯỚC hoặc CÙNG cycle wino_done
                    // Bắt valid ngay từ FEED_WAIT để không bỏ lỡ
                    if (wino_data_out_valid) begin
                        case (feed_counter[1:0])
                            2'd0: output_buffer_0 <= wino_data_out;
                            2'd1: output_buffer_1 <= wino_data_out;
                            2'd2: output_buffer_2 <= wino_data_out;
                            2'd3: output_buffer_3 <= wino_data_out;
                            default: ;
                        endcase
                        feed_counter <= feed_counter + 4'd1;
                    end
                    if (wino_done)
                        feed_state <= FEED_COLLECT;
                end

                FEED_COLLECT: begin
                    // Tiếp tục bắt valid nếu còn chưa đủ 4 pixels từ FEED_WAIT
                    if (wino_data_out_valid) begin
                        case (feed_counter[1:0])
                            2'd0: output_buffer_0 <= wino_data_out;
                            2'd1: output_buffer_1 <= wino_data_out;
                            2'd2: output_buffer_2 <= wino_data_out;
                            2'd3: output_buffer_3 <= wino_data_out;
                            default: ;
                        endcase
                        feed_counter <= feed_counter + 4'd1;
                    end
                    // Chuyển IDLE khi đã nhận đủ 4 pixels (counter[2]=1 → ≥4)
                    // hoặc khi không còn valid và done đã latched
                    if (feed_counter[2] || (!wino_data_out_valid && wino_done_latched))
                        feed_state <= FEED_IDLE;
                end

                default: feed_state <= FEED_IDLE;
            endcase
        end
    end

    // ---------------------------------------------------------------
    // Latch done
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wino_done_latched <= 1'b0;
        end else begin
            if (wino_done)
                wino_done_latched <= 1'b1;
            else if (feed_state == FEED_IDLE)
                wino_done_latched <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Accumulator (DP2 core logic)
    // acc_buffer tự động cộng dồn MỌI lần COLLECT xảy ra.
    // CPU dùng CLEAR_ACC để xóa trước khi bắt đầu chuỗi channel mới.
    // Không cần ACCUM_EN — CPU kiểm soát bằng CLEAR_ACC timing.
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            acc_buffer_0 <= {DATA_WIDTH{1'b0}};
            acc_buffer_1 <= {DATA_WIDTH{1'b0}};
            acc_buffer_2 <= {DATA_WIDTH{1'b0}};
            acc_buffer_3 <= {DATA_WIDTH{1'b0}};
        end else begin
            if (ctrl_reg[CTRL_CLEAR_ACC_BIT]) begin
                acc_buffer_0 <= {DATA_WIDTH{1'b0}};
                acc_buffer_1 <= {DATA_WIDTH{1'b0}};
                acc_buffer_2 <= {DATA_WIDTH{1'b0}};
                acc_buffer_3 <= {DATA_WIDTH{1'b0}};
            end else begin
            if (wino_data_out_valid
                && (feed_state == FEED_WAIT || feed_state == FEED_COLLECT)
                && ctrl_reg[CTRL_ACCUM_EN_BIT]) begin
                case (feed_counter[1:0])
                    2'd0: acc_buffer_0 <= $signed(acc_buffer_0) + $signed(wino_data_out);
                    2'd1: acc_buffer_1 <= $signed(acc_buffer_1) + $signed(wino_data_out);
                    2'd2: acc_buffer_2 <= $signed(acc_buffer_2) + $signed(wino_data_out);
                    2'd3: acc_buffer_3 <= $signed(acc_buffer_3) + $signed(wino_data_out);
                    default: ;
                endcase
            end
        end
        end
    end

    // ---------------------------------------------------------------
    // Status
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            status_reg <= 32'h0;
        else begin
            status_reg[STATUS_BUSY_BIT] <= feed_active;
            status_reg[STATUS_DONE_BIT] <= wino_done_latched;
        end
    end

    // ---------------------------------------------------------------
    // IRQ
    // ---------------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            winograd_irq <= 1'b0;
        end else begin
            if (ctrl_reg[CTRL_IRQ_EN_BIT] && wino_done_latched)
                winograd_irq <= 1'b1;
            else if (write_req && is_status)
                winograd_irq <= 1'b0;
        end
    end

endmodule
