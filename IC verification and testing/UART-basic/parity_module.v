module parity_module (
    input  wire clk,
    input  wire rst_n,
    input  wire parity_en,
    input  wire parity_type,   // 0 = even, 1 = odd
    output reg  parity_en_reg,
    output reg  parity_type_reg
);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            parity_en_reg   <= 1'b0;
            parity_type_reg <= 1'b0;
        end else begin
            parity_en_reg   <= parity_en;
            parity_type_reg <= parity_type;
        end
endmodule
