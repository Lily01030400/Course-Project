module uart_tx_module (
    input  wire clk,
    input  wire rst_n,
    input  wire baud_tick,
    input  wire [7:0] data_in,
    input  wire di_rdy,
    input  wire parity_en_reg,
    input  wire parity_type_reg,
    output reg  txd,
    output reg  send_end,
	output reg 	tx_busy
);
    reg [3:0] cnt_symbol;
    reg [7:0] data_reg;
    reg [3:0] cnt_tick;
    reg parity_bit;
    
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) cnt_tick <= 0;
		else if (baud_tick) begin
			if (cnt_tick == 15) cnt_tick <= 0;
			else cnt_tick <= cnt_tick + 1; 
		end
	end

    //Processing
    always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
	    txd <= 1'b1;
	    send_end <= 0;
	    cnt_symbol <= 0;
	    cnt_tick <= 0;
	    parity_bit <= 0;
	    tx_busy <= 0;
	    data_reg <= 0;
	end
	else begin
	    send_end <= 0;

	    //1. START transmiting data
	    if (di_rdy && !tx_busy && txd) begin
		data_reg <= data_in;
		parity_bit <= 0;
		tx_busy <= 1;
		cnt_symbol <= 0;
		cnt_tick <= 0;
		txd <= 1'b0; //start bit
	    end

	    //2. RANSMITING
	    else if (tx_busy && baud_tick && cnt_tick == 15) begin
		    //state	
		    case (cnt_symbol)
			//START_bit 
			0: begin
			    txd <= 0;
			    send_end <= 0;
				tx_busy <= 1'b1;
			end
			//DATA
			1,2,3,4,5,6,7,8: begin
			    txd <= data_reg [0];
			    parity_bit <= parity_bit ^ data_reg[0];
			    data_reg <= {1'b0, data_reg[7:1]};
			end
			//PARITY
			9: begin
			    if (parity_en_reg) begin
			   		if (parity_type_reg) txd <= ~parity_bit;
					else txd <= parity_bit;
			    end
			    else begin //go straight to stopbit if parity_bit is unenable	
				txd <= 1'b1;
				send_end <= 1;
				tx_busy <= 0;
			    end
			end
			//STOP_bit
			10: begin
			    txd <= 1'b1;
				tx_busy <= 0;
				send_end <= 1;
			end
			default: begin
			    txd <= 1'b1; //idle
			end
		    endcase
		cnt_symbol <= cnt_symbol + 1;
		end
	end
	end
endmodule
    
