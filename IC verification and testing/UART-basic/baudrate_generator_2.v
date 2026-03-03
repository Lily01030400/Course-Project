module baud_generator #(
    parameter fclk = 5000000,     // 5MHz
    parameter OVERSAMPLE = 16     // 16tick = 1 baud_cycle
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [2:0] baud,
    output reg  tick,
    output reg  [15:0] baud_cycle
);

    reg [31:0] tick_cycle;   // n clk_cycle = 1 tick cycle
    reg [31:0] cnt_tick;

    always @(baud) begin
        case (baud)
            3'd0: tick_cycle = fclk / (4800  * OVERSAMPLE);    
            3'd1: tick_cycle = fclk / (9600  * OVERSAMPLE);    
            3'd2: tick_cycle = fclk / (19200 * OVERSAMPLE);   
            3'd3: tick_cycle = fclk / (38400 * OVERSAMPLE);  
            3'd4: tick_cycle = fclk / (57600 * OVERSAMPLE);   
            3'd5: tick_cycle = fclk / (115200 * OVERSAMPLE);  
            3'd6: tick_cycle = fclk / (230400 * OVERSAMPLE);  
            3'd7: tick_cycle = fclk / (460800 * OVERSAMPLE);  
            default: tick_cycle = fclk / (9600 * OVERSAMPLE);
        endcase
    end
    always @(OVERSAMPLE) begin
        baud_cycle <= OVERSAMPLE;
    end

    //generate tick pulse
    always @(posedge clk or negedge rst_n) begin
	    if (!rst_n) begin
	        cnt_tick <= 0;
	        tick <= 0;
	    end
	    else begin
	        if (cnt_tick < tick_cycle - 1) begin
		        cnt_tick <= cnt_tick + 1;
		        tick <= 1'b0;
	        end
	        else begin
		        cnt_tick <= 0;
		        tick <= 1'b1;
	        end
	    end
    end
endmodule



