
module traffic_light_fsm (
    input clk,
    input rst,
    input g_end,
    input y_end,
    output reg [2:0] street_a, // output control strA - 3bit for red,yellow,green
    output reg [2:0] street_b
);
// internal state var of fsm
reg [1:0] current_state; 
reg [1:0] next_state;

localparam AG_BR = 2'b00;
localparam AY_BR = 2'b01;
localparam AR_BG = 2'b10;
localparam AR_BY = 2'b11;
// sequential block: to store current state
always @(posedge clk, negedge rst) begin
    if (~rst) begin
        current_state <= AG_BR;
    end else begin
        current_state <= next_state;//update current state  
    end
end
//combinational block: to calc next state based on curr state
always @(current_state or g_end or y_end) begin
    case (current_state)
        AG_BR: begin
            if (g_end) begin
                next_state = AY_BR;
            end else begin
                next_state = AG_BR;
            end
        end 
        AY_BR: begin
            if (y_end) begin
                next_state = AR_BG;
            end else begin
                next_state = AY_BR;
            end
        end
        AR_BG: begin
          if (g_end) begin
            next_state = AR_BY;
          end else begin
            next_state = AR_BG;
          end
        end
        AR_BY: begin
          if (y_end) begin
            next_state = AG_BR;
          end else begin
            next_state = AR_BY;
          end
        end
        default: next_state = AG_BR;
    endcase
end
// combinational block to drive output lights based on curr state
always @(current_state) begin
    case (current_state)
        AG_BR: begin
          street_a = 3'b100;
          street_b = 3'b001;
        end
        AY_BR: begin
          street_a = 3'b010;
          street_b = 3'b001;
        end
        AR_BG: begin
          street_a = 3'b001;
          street_b = 3'b100;
        end
        AR_BY: begin
          street_a = 3'b001;
          street_b = 3'b010;
        end
        default: begin
          street_a = 3'b100;
          street_b = 3'b001;
        end
    endcase
end
endmodule
