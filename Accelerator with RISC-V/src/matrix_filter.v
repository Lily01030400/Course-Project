// File: matrix_filter.v  (module: winograd_filter_transform)
module winograd_filter_transform #(
    parameter DATA_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rstn,
    input  wire                     start,
    input  wire [DATA_WIDTH-1:0]    g_in,
    input  wire [3:0]               g_count,
    output reg                      done,
    output reg                      u_valid,
    output reg  [DATA_WIDTH-1:0]    u_out,
    output reg  [3:0]               u_count
);
/* verilator lint_on DECLFILENAME */

    // Flattened 1D arrays — avoids iverilog 2D variable-index bug
    // g_flat[r*3+c]     : 3×3 = 9  elements
    // temp_flat[r*3+c]  : 4×3 = 12 elements
    // u_flat[r*4+c]     : 4×4 = 16 elements
    reg signed [DATA_WIDTH-1:0] g_flat    [0:8];
    reg signed [DATA_WIDTH-1:0] temp_flat [0:11];
    reg signed [DATA_WIDTH-1:0] u_flat    [0:15];

    reg [2:0] state;
    reg [1:0] row, col;

    localparam IDLE         = 3'd0;
    localparam LOAD         = 3'd1;
    localparam COMPUTE_GG   = 3'd2;
    localparam COMPUTE_GGGT = 3'd3;
    localparam OUTPUT       = 3'd4;

    // Index helpers (combinational, based on current row/col)

    wire [3:0] t_rc     = (row == 2'd0) ? {2'b00, col} :
                          (row == 2'd1) ? (4'd3  + {2'b0, col}) :
                          (row == 2'd2) ? (4'd6  + {2'b0, col}) :
                                         (4'd9  + {2'b0, col});

    wire [3:0] u_rc     = (row == 2'd0) ? {2'b00, col} :
                          (row == 2'd1) ? (4'd4  + {2'b0, col}) :
                          (row == 2'd2) ? (4'd8  + {2'b0, col}) :
                                         (4'd12 + {2'b0, col});

    // Sums for COMPUTE_GG: g column = col (=current col reg)
    // g_flat[0*3+col], g_flat[1*3+col], g_flat[2*3+col]
    wire [3:0] gc0 = {2'b00, col};          // g[0][col]
    wire [3:0] gc1 = 4'd3 + {2'b0, col};   // g[1][col]
    wire [3:0] gc2 = 4'd6 + {2'b0, col};   // g[2][col]

    /* verilator lint_off UNUSED */
    wire signed [DATA_WIDTH+1:0] gg_sum =
        $signed({{2{g_flat[gc0][DATA_WIDTH-1]}}, g_flat[gc0]})
      + $signed({{2{g_flat[gc1][DATA_WIDTH-1]}}, g_flat[gc1]})
      + $signed({{2{g_flat[gc2][DATA_WIDTH-1]}}, g_flat[gc2]});

    wire signed [DATA_WIDTH+1:0] gg_dif =
        $signed({{2{g_flat[gc0][DATA_WIDTH-1]}}, g_flat[gc0]})
      - $signed({{2{g_flat[gc1][DATA_WIDTH-1]}}, g_flat[gc1]})
      + $signed({{2{g_flat[gc2][DATA_WIDTH-1]}}, g_flat[gc2]});

    // Sums for COMPUTE_GGGT: temp row = row reg, cols 0,1,2
    wire [3:0] tr0 = (row==2'd0)?4'd0:(row==2'd1)?4'd3:(row==2'd2)?4'd6:4'd9;
    wire [3:0] tr1 = tr0 + 4'd1;
    wire [3:0] tr2 = tr0 + 4'd2;

    wire signed [DATA_WIDTH+1:0] gt_sum =
        $signed({{2{temp_flat[tr0][DATA_WIDTH-1]}}, temp_flat[tr0]})
      + $signed({{2{temp_flat[tr1][DATA_WIDTH-1]}}, temp_flat[tr1]})
      + $signed({{2{temp_flat[tr2][DATA_WIDTH-1]}}, temp_flat[tr2]});

    wire signed [DATA_WIDTH+1:0] gt_dif =
        $signed({{2{temp_flat[tr0][DATA_WIDTH-1]}}, temp_flat[tr0]})
      - $signed({{2{temp_flat[tr1][DATA_WIDTH-1]}}, temp_flat[tr1]})
      + $signed({{2{temp_flat[tr2][DATA_WIDTH-1]}}, temp_flat[tr2]});
    /* verilator lint_on UNUSED */

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state   <= IDLE;
            done    <= 1'b0;
            u_valid <= 1'b0;
            row     <= 2'd0;
            col     <= 2'd0;
            u_count <= 4'd0;
            u_out   <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state)

                IDLE: begin
                    done    <= 1'b0;
                    u_valid <= 1'b0;
                    u_count <= 4'd0;
                    if (start) begin
                        // FIX Bug #1: capture g_flat[0] ngay cycle start=1.
                        // winograd gửi g_count=0, g_in=filter_buffer[0] cùng cycle start.
                        // Cycle tiếp theo vào LOAD bắt đầu từ g_count=1.
                        g_flat[0] <= $signed(g_in);
                        state <= LOAD;
                        row   <= 2'd0;
                        col   <= 2'd0;
                    end
                end

                LOAD: begin
                    // g_count bắt đầu từ 1 (vì [0] đã capture trong IDLE)
                    if (g_count >= 4'd1 && g_count <= 4'd8)
                        g_flat[g_count] <= $signed(g_in);
                    if (g_count == 4'd8) begin
                        state <= COMPUTE_GG;
                        row   <= 2'd0;
                        col   <= 2'd0;
                    end
                end

                // temp_flat[row*3+col] = G_int[row] · g[:,col]  / 2
                COMPUTE_GG: begin
                    /* verilator lint_off WIDTH */
                    case (row)
                        // row0: temp[0][c] = g[0][c]
                        2'd0: temp_flat[t_rc] <= g_flat[gc0];
                        // row1: temp[1][c] = (g[0][c]+g[1][c]+g[2][c]) >> 1
                        2'd1: temp_flat[t_rc] <= gg_sum[DATA_WIDTH:1];
                        // row2: temp[2][c] = (g[0][c]-g[1][c]+g[2][c]) >> 1
                        2'd2: temp_flat[t_rc] <= gg_dif[DATA_WIDTH:1];
                        // row3: temp[3][c] = g[2][c]
                        2'd3: temp_flat[t_rc] <= g_flat[gc2];
                        default: ;
                    endcase
                    /* verilator lint_on WIDTH */

                    if (col == 2'd2) begin
                        col <= 2'd0;
                        if (row == 2'd3) begin
                            row   <= 2'd0;
                            state <= COMPUTE_GGGT;
                        end else
                            row <= row + 2'd1;
                    end else
                        col <= col + 2'd1;
                end

                // u_flat[row*4+col] = temp[row,:] · G_int^T[:,col]  / 2
                COMPUTE_GGGT: begin
                    /* verilator lint_off WIDTH */
                    case (col)
                        // col0: u[r][0] = temp[r][0]
                        2'd0: u_flat[u_rc] <= temp_flat[tr0];
                        // col1: u[r][1] = (temp[r][0]+[1]+[2]) >> 1
                        2'd1: u_flat[u_rc] <= gt_sum[DATA_WIDTH:1];
                        // col2: u[r][2] = (temp[r][0]-[1]+[2]) >> 1
                        2'd2: u_flat[u_rc] <= gt_dif[DATA_WIDTH:1];
                        // col3: u[r][3] = temp[r][2]
                        2'd3: u_flat[u_rc] <= temp_flat[tr2];
                        default: ;
                    endcase
                    /* verilator lint_on WIDTH */

                    if (col == 2'd3) begin
                        col <= 2'd0;
                        if (row == 2'd3) begin
                            row     <= 2'd0;
                            state   <= OUTPUT;
                            u_count <= 4'd0;
                        end else
                            row <= row + 2'd1;
                    end else
                        col <= col + 2'd1;
                end

                OUTPUT: begin
                    u_valid <= 1'b1;
                    u_out   <= u_flat[u_count];
                    if (u_count < 4'd15)
                        u_count <= u_count + 4'd1;
                    else begin
                        u_valid <= 1'b0;
                        done    <= 1'b1;
                        state   <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Expose u_matrix as 2D for testbench hierarchical access
    // u_flat[r*4+c] → u_matrix[r][c]
    /* verilator lint_off UNUSED */
    wire signed [DATA_WIDTH-1:0] u_matrix [0:3][0:3];
    assign u_matrix[0][0]=u_flat[0];  assign u_matrix[0][1]=u_flat[1];
    assign u_matrix[0][2]=u_flat[2];  assign u_matrix[0][3]=u_flat[3];
    assign u_matrix[1][0]=u_flat[4];  assign u_matrix[1][1]=u_flat[5];
    assign u_matrix[1][2]=u_flat[6];  assign u_matrix[1][3]=u_flat[7];
    assign u_matrix[2][0]=u_flat[8];  assign u_matrix[2][1]=u_flat[9];
    assign u_matrix[2][2]=u_flat[10]; assign u_matrix[2][3]=u_flat[11];
    assign u_matrix[3][0]=u_flat[12]; assign u_matrix[3][1]=u_flat[13];
    assign u_matrix[3][2]=u_flat[14]; assign u_matrix[3][3]=u_flat[15];
    /* verilator lint_on UNUSED */

endmodule
