// File: matrix_input.v  (module: winograd_input_transform)
/* verilator lint_off DECLFILENAME */
module winograd_input_transform #(
    parameter DATA_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rstn,
    input  wire                     start,
    input  wire [DATA_WIDTH-1:0]    d_in,
    input  wire [3:0]               d_count,
    output reg                      done,
    output reg                      v_valid,
    output reg  [DATA_WIDTH-1:0]    v_out,
    output reg  [3:0]               v_count
);
/* verilator lint_on DECLFILENAME */

    // B^T = | 1   0  -1   0 |
    //       | 0   1   1   0 |
    //       | 0  -1   1   0 |
    //       | 0   1   0  -1 |

    // All arrays 4×4: index [1:0]×[1:0]
    reg [DATA_WIDTH-1:0] d_matrix    [0:3][0:3];
    reg [DATA_WIDTH-1:0] temp_matrix [0:3][0:3];
    reg [DATA_WIDTH-1:0] v_matrix    [0:3][0:3];

    reg [2:0] state;
    reg [1:0] row, col;   // 2-bit: covers 0..3

    localparam IDLE         = 3'd0;
    localparam LOAD         = 3'd1;
    localparam COMPUTE_BTD  = 3'd2;
    localparam COMPUTE_BTDB = 3'd3;
    localparam OUTPUT       = 3'd4;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state   <= IDLE;
            done    <= 1'b0;
            row     <= 2'd0;
            col     <= 2'd0;
            v_count <= 4'd0;
            v_valid <= 1'b0;
            v_out   <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state)

                IDLE: begin
                    done    <= 1'b0;
                    v_valid <= 1'b0;
                    v_count <= 4'd0;
                    if (start) begin
                        // FIX Bug #2: capture d_matrix[0][0] ngay cycle start=1.
                        // winograd gửi d_count=0, d_in=data_buffer[0] cùng cycle start.
                        // Cycle tiếp theo vào LOAD bắt đầu từ d_count=1.
                        d_matrix[0][0] <= d_in;
                        state <= LOAD;
                        row   <= 2'd0;
                        col   <= 2'd0;
                    end
                end

                LOAD: begin
                    // d_count bắt đầu từ 1 (vì [0][0] đã capture trong IDLE)
                    if (d_count >= 4'd1)
                        d_matrix[d_count[3:2]][d_count[1:0]] <= d_in;
                    if (d_count == 4'd15) begin
                        state <= COMPUTE_BTD;
                        row   <= 2'd0;
                        col   <= 2'd0;
                    end
                end

                // temp = B^T * d  (element per clock)
                // row0: d[0][c] - d[2][c]
                // row1: d[1][c] + d[2][c]
                // row2: d[2][c] - d[1][c]
                // row3: d[1][c] - d[3][c]
                // Suppress WIDTH on 2-bit row/col indexing 4-deep [0:3] arrays
                COMPUTE_BTD: begin
                    /* verilator lint_off WIDTH */
                    case (row)
                        2'd0: temp_matrix[0][col] <=
                                  $signed(d_matrix[0][col]) - $signed(d_matrix[2][col]);
                        2'd1: temp_matrix[1][col] <=
                                  $signed(d_matrix[1][col]) + $signed(d_matrix[2][col]);
                        2'd2: temp_matrix[2][col] <=
                                  $signed(d_matrix[2][col]) - $signed(d_matrix[1][col]);
                        2'd3: temp_matrix[3][col] <=
                                  $signed(d_matrix[1][col]) - $signed(d_matrix[3][col]);
                        default: ;
                    endcase
                    /* verilator lint_on WIDTH */

                    if (col == 2'd3) begin
                        col <= 2'd0;
                        if (row == 2'd3) begin
                            row   <= 2'd0;
                            state <= COMPUTE_BTDB;
                        end else
                            row <= row + 2'd1;
                    end else
                        col <= col + 2'd1;
                end

                // v = temp * B
                // col0: temp[r][0] - temp[r][2]
                // col1: temp[r][1] + temp[r][2]
                // col2: temp[r][2] - temp[r][1]
                // col3: temp[r][1] - temp[r][3]
                COMPUTE_BTDB: begin
                    /* verilator lint_off WIDTH */
                    case (col)
                        2'd0: v_matrix[row][0] <=
                                  $signed(temp_matrix[row][0]) - $signed(temp_matrix[row][2]);
                        2'd1: v_matrix[row][1] <=
                                  $signed(temp_matrix[row][1]) + $signed(temp_matrix[row][2]);
                        2'd2: v_matrix[row][2] <=
                                  $signed(temp_matrix[row][2]) - $signed(temp_matrix[row][1]);
                        2'd3: v_matrix[row][3] <=
                                  $signed(temp_matrix[row][1]) - $signed(temp_matrix[row][3]);
                        default: ;
                    endcase
                    /* verilator lint_on WIDTH */

                    if (col == 2'd3) begin
                        col <= 2'd0;
                        if (row == 2'd3) begin
                            row     <= 2'd0;
                            state   <= OUTPUT;
                            v_count <= 4'd0;
                        end else
                            row <= row + 2'd1;
                    end else
                        col <= col + 2'd1;
                end

                OUTPUT: begin
                    v_valid <= 1'b1;
                    v_out   <= v_matrix[v_count[3:2]][v_count[1:0]];
                    if (v_count == 4'd15) begin
                        v_valid <= 1'b0;
                        done    <= 1'b1;
                        state   <= IDLE;
                        v_count <= 4'd0;
                    end else
                        v_count <= v_count + 4'd1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
