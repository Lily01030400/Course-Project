/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Winograd Convolution Accelerator Peripheral
// Renamed from tqvp_example to tqvp_winograd.
// Also update tt_wrapper.v: change tqvp_example → tqvp_winograd
module tqvp_winograd (
    input         clk,
    input         rst_n,

    input  [7:0]  ui_in,
    output [7:0]  uo_out,

    input [5:0]   address,
    input [31:0]  data_in,

    input [1:0]   data_write_n,
    input [1:0]   data_read_n,

    output [31:0] data_out,
    output        data_ready,

    output        user_interrupt
);

    // ---------------------------------------------------------------
    // Address remapping: 6-bit address → 12-bit laddr
    //
    // winograd_peripheral register map (byte offset):
    //   0x000 = CTRL, 0x004 = STATUS, 0x008 = CONFIG
    //   0x100..0x13C = INPUT_BUF  (16 words)
    //   0x200..0x220 = FILTER_BUF (9 words)
    //   0x300..0x30C = OUTPUT_BUF (4 words)
    //   0x400..0x40C = ACC_BUF    (4 words)
    //
    // 6-bit address từ template → byte offset:
    //   address[5:4] = bank select
    //   address[3:0] = word index trong bank
    //   byte offset  = bank_base + index*4
    //
    // FIX: dùng cộng số học thay vì ghép bits để tránh lỗi width mismatch
    // ---------------------------------------------------------------
    reg [11:0] laddr_mapped;

    always @(*) begin
        case (address[5:4])
            // Bank 0: CTRL(0x000) / STATUS(0x004) / CONFIG(0x008)
            2'b00: laddr_mapped = 12'h000 + {6'b0, address[3:0], 2'b00};

            // Bank 1: INPUT_BUF 0x100..0x13C (16 words)
            2'b01: laddr_mapped = 12'h100 + {6'b0, address[3:0], 2'b00};

            // Bank 2: FILTER_BUF 0x200..0x220 (9 words)
            2'b10: laddr_mapped = 12'h200 + {6'b0, address[3:0], 2'b00};

            // Bank 3: OUTPUT_BUF(addr[3]=0) hoặc ACC_BUF(addr[3]=1)
            2'b11: begin
                if (!address[3])
                    laddr_mapped = 12'h300 + {7'b0, address[2:0], 2'b00};
                else
                    laddr_mapped = 12'h400 + {7'b0, address[2:0], 2'b00};
            end
        endcase
    end

    // Full 28-bit address: bits[27:20]=0x90 (winograd base), bits[11:0]=laddr
    wire [27:0] full_addr = {8'h90, 8'h00, laddr_mapped};

    // ---------------------------------------------------------------
    // Instantiate winograd_peripheral (từ interface.v)
    // ---------------------------------------------------------------
    wire [31:0] wino_data_out;
    wire        wino_data_ready;
    wire        wino_irq;

    winograd_peripheral #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(28),
        .FRAC_BITS (16)
    ) u_winograd (
        .clk               (clk),
        .rstn              (rst_n),
        .data_addr         (full_addr),
        .data_write_n      (data_write_n),
        .data_read_n       (data_read_n),
        .data_in           (data_in),
        .data_read_complete(1'b0),
        .data_out          (wino_data_out),
        .data_ready        (wino_data_ready),
        .winograd_irq      (wino_irq)
    );

    // ---------------------------------------------------------------
    // Outputs
    // ---------------------------------------------------------------
    assign data_out       = wino_data_out;
    assign data_ready     = wino_data_ready;
    assign user_interrupt = wino_irq;

    // uo_out: bit0 = interrupt/done, bit1..7 = 0
    assign uo_out = {7'b0, wino_irq};

    // Suppress unused warning
    wire _unused = &{ui_in, 1'b0};

endmodule
