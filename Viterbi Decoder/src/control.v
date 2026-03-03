`timescale 1ns / 1ps

module control(clk,rst,en,en_ext,en_brch,en_acs,en_mem,en_trbk);

input clk,rst,en;

output reg en_ext,en_brch,en_acs,en_mem,en_trbk;

reg [2:0] state, nxt_state;
reg [3:0] count;

localparam [2:0] s0 = 3'b000; // reset 
localparam [2:0] s1 = 3'b001; // extract
localparam [2:0] s2 = 3'b010; // branch and add
localparam [2:0] s3 = 3'b011; // memory
localparam [2:0] s4 = 3'b100; // traceback

always @ (posedge clk or negedge rst)
begin
    if (rst == 0)
    begin
        count <= 0;
        state <= s0;
    end
    else
    begin
        if (en == 1)
        begin
            count <= count + 1; 
            state <= nxt_state;
        end
        else 
        begin
            count <= count;
            state <= state; 
        end
    end
    
end

always @ (negedge rst or state or count or en or posedge clk) 
begin
    case(state)
    s0:
    begin
        en_ext=0; en_brch=0; en_acs=0; en_mem=0; en_trbk=0;
        if (en == 1)
            nxt_state = s1;
        else
            nxt_state = state;
    end
    
    s1:
    begin
        en_ext=1; en_brch=0; en_acs=0; en_mem=0; en_trbk=0;
        nxt_state = s2;
    end
    
    s2:
    begin
        en_ext=1; en_brch=1; en_acs=1; en_mem=0; en_trbk=0;
        nxt_state = s3;
    end
    
    s3:
    begin
        en_ext=1; en_brch=1; en_acs=1; en_mem=1; en_trbk=0;
        if(count < 11)
            nxt_state = s3;
        else 
            nxt_state = s4;
    end
    
    s4:
    begin
        en_ext=0; en_brch=0; en_acs=0; en_mem=1; en_trbk=1; // tat cac module khong dung den
        nxt_state = s4;
    end
    endcase
    
end


endmodule

