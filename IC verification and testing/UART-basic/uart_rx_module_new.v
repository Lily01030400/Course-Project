module uart_rx_module (
	input wire clk,
	input wire rst_n,
	input wire baud_tick,       //16 baud_tick = symbol
	input wire rxd,
	input wire parity_en_reg,   //on to check parity
	input wire parity_type_reg, //0:even, 1:odd
	output reg [7:0] data_out,
	output reg do_rdy,
	output reg parity_error,
	output reg [7:0] data_reg
);

	reg [3:0] cnt_symbol;
	//reg [7:0] data_reg;
	reg parity_bit;
	reg rx_busy;
	reg [3:0] cnt_tick;	   //count tick for each symbol

	//loop for cnt_tick
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) cnt_tick <= 0;
		else if (baud_tick) begin
			if (cnt_tick == 15) cnt_tick <= 0;
			else cnt_tick <= cnt_tick + 1; 
		end
	end

	//main process of rx_module
	always @(posedge clk or negedge rst_n) begin
	    //RESET
	    if (!rst_n) begin
		rx_busy <= 0;
		do_rdy <= 0;
		parity_error <= 0;
		cnt_symbol <= 0;
	    end

	    //ACTIVE
	    else begin
			do_rdy <= 0;

			//1. START_BIT DETECTED, rxd from idle to 0
			if (!rx_busy && !rxd) begin
					rx_busy <= 1;
					cnt_symbol <= 0;
					parity_bit <= 0;		
			end

			//2. SAMPLING when cnt_tick == 7
			else if (rx_busy && baud_tick && cnt_tick == 7) begin
				case (cnt_symbol)
					//START_bit
					0,1: begin
						if (!rxd) begin
							rx_busy <= 1'b1;
							do_rdy <= 0;
						end
						else rx_busy <= 1'b0;
					end
					//DATA
					2,3,4,5,6,7,8,9: begin
						data_reg <= {rxd, data_reg[7:1]};
						parity_bit <= parity_bit ^ rxd;
					end
					//PARITY
					10: begin
						if (parity_en_reg) begin
							if (!parity_type_reg)
								parity_error <= (rxd != parity_bit);
							else
								parity_error <= (rxd != ~parity_bit);
						end
						else parity_error <= 0;
					end
					//STOP_bit
					11:	begin
							data_out <= data_reg;
							do_rdy <= 1'b1;
							rx_busy <= 0;
					end
					default: cnt_symbol <= 0; 
				endcase
				cnt_symbol <= cnt_symbol + 1;
			end
		end
	end
endmodule
