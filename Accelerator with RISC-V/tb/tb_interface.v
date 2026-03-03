//==============================================================================
// Testbench: tb_interface.v
// Test DP2 multi-channel accumulation via winograd_peripheral
//==============================================================================
`timescale 1ns/1ps

module tb_interface;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 28;
    parameter FRAC_BITS  = 16;
    parameter CLK_PERIOD = 10;

    // Q16.16 fixed-point helper: real → hex
    // float_to_fixed(x) = int(x * 65536)

    //==========================================================================
    // DUT signals
    //==========================================================================
    reg                     clk;
    reg                     rstn;
    reg  [ADDR_WIDTH-1:0]   data_addr;
    reg  [1:0]              data_write_n;
    reg  [1:0]              data_read_n;
    reg  [DATA_WIDTH-1:0]   data_in;
    reg                     data_read_complete;
    wire [DATA_WIDTH-1:0]   data_out;
    wire                    data_ready;
    wire                    winograd_irq;

    //==========================================================================
    // Test variables
    //==========================================================================
    integer i, ch;
    integer error_count;
    reg [31:0] read_val;
    reg [31:0] status_val;
    integer timeout;

    // Base address
    localparam BASE        = 28'h9000000;
    localparam CTRL_ADDR   = BASE + 28'h000;
    localparam STATUS_ADDR = BASE + 28'h004;
    localparam INPUT_BASE  = BASE + 28'h100;
    localparam FILTER_BASE = BASE + 28'h200;
    localparam OUTPUT_BASE = BASE + 28'h300;
    localparam ACC_BASE    = BASE + 28'h400;

    // CTRL bits
    localparam CTRL_START     = 32'h01;
    localparam CTRL_ACCUM_EN  = 32'h08;
    localparam CTRL_CLEAR_ACC = 32'h10;
    localparam CTRL_START_ACCUM = 32'h09; // START | ACCUM_EN

    //==========================================================================
    // Clock
    //==========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //==========================================================================
    // DUT instantiation
    //==========================================================================
    winograd_peripheral #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FRAC_BITS (FRAC_BITS)
    ) dut (
        .clk               (clk),
        .rstn              (rstn),
        .data_addr         (data_addr),
        .data_write_n      (data_write_n),
        .data_read_n       (data_read_n),
        .data_in           (data_in),
        .data_read_complete(data_read_complete),
        .data_out          (data_out),
        .data_ready        (data_ready),
        .winograd_irq      (winograd_irq)
    );

    //==========================================================================
    // Tasks
    //==========================================================================

    // Write 32-bit word
    task write_reg;
        input [27:0] addr;
        input [31:0] wdata;
        begin
            @(posedge clk); #1;
            data_addr    = addr;
            data_in      = wdata;
            data_write_n = 2'b10;
            data_read_n  = 2'b11;
            @(posedge clk); #1;
            data_write_n = 2'b11;
            @(posedge clk); #1;
        end
    endtask

    // Read 32-bit word
    task read_reg;
        input  [27:0] addr;
        output [31:0] rdata;
        begin
            @(posedge clk); #1;
            data_addr    = addr;
            data_write_n = 2'b11;
            data_read_n  = 2'b10;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rdata       = data_out;
            data_read_n = 2'b11;
            @(posedge clk); #1;
        end
    endtask

    // Poll STATUS.BUSY == 0 - chờ ít nhất 5 cycles trước khi poll để BUSY kịp set
    task wait_done;
        begin
            // Chờ đủ lâu để feed_active kịp set (2-3 cycles sau START)
            repeat(5) @(posedge clk);
            timeout = 0;
            read_reg(STATUS_ADDR, status_val);
            while (status_val[0] == 1'b1 && timeout < 20000) begin
                @(posedge clk);
                read_reg(STATUS_ADDR, status_val);
                timeout = timeout + 1;
            end
            if (timeout >= 20000) begin
                $display("  ERROR: Timeout waiting for BUSY=0!");
                error_count = error_count + 1;
            end
        end
    endtask

    //==========================================================================
    // Helper: chạy 1 channel (ghi filter + input, trigger, chờ xong)
    //==========================================================================
    // filter_vals[0..8], input_vals[0..15] là fixed-point Q16.16
    reg [31:0] filter_vals [0:8];
    reg [31:0] input_vals  [0:15];

    task run_one_channel;
        input with_accum;  // 1 = ACCUM_EN, 0 = chỉ output (không cộng)
        integer k;
        begin
            // Ghi filter
            for (k = 0; k < 9; k = k + 1)
                write_reg(FILTER_BASE + (k * 4), filter_vals[k]);
            // Ghi input
            for (k = 0; k < 16; k = k + 1)
                write_reg(INPUT_BASE + (k * 4), input_vals[k]);
            // Trigger
            if (with_accum)
                write_reg(CTRL_ADDR, CTRL_START_ACCUM);
            else
                write_reg(CTRL_ADDR, CTRL_START);
            // Chờ xong
            wait_done();
        end
    endtask

    //==========================================================================
    // Main test
    //==========================================================================
    initial begin
        error_count       = 0;
        data_addr         = 28'h0;
        data_in           = 32'h0;
        data_write_n      = 2'b11;
        data_read_n       = 2'b11;
        data_read_complete= 1'b0;

        $display("\n============================================================");
        $display("  TB: Multi-channel Accumulation (DP2)");
        $display("============================================================");

        // Reset
        rstn = 0;
        #(CLK_PERIOD * 10);
        rstn = 1;
        #(CLK_PERIOD * 5);

        //======================================================================
        // TEST 1: Single channel, NO accumulation
        // filter = all 1.0, input = 1..16
        // Expected: [54, 63, 90, 99] (Q16.16: 0x00360000 ...)
        //======================================================================
        $display("\n--- TEST 1: Single channel (no accumulation) ---");

        for (i = 0; i < 9;  i = i + 1) filter_vals[i] = 32'h00010000; // 1.0
        for (i = 0; i < 16; i = i + 1) input_vals[i]  = (i+1) << 16;  // 1.0..16.0

        run_one_channel(0); // không accum

        // Đọc output_buffer
        read_reg(OUTPUT_BASE + 0,  read_val);
        $display("  output[0] = %f (raw 0x%08h)", $itor(read_val) / 65536.0, read_val);
        if (read_val != 32'h00360000) begin
            $display("FAIL: output[0] expected 0x00360000 (54.0), got 0x%08h", read_val);
            error_count = error_count + 1;
        end else $display("PASS: output[0] = 54.0");

        read_reg(OUTPUT_BASE + 4,  read_val);
        if (read_val != 32'h003F0000) begin
            $display("FAIL: output[1] expected 0x003F0000 (63.0), got 0x%08h", read_val);
            error_count = error_count + 1;
        end else $display("PASS: output[1] = 63.0");

        read_reg(OUTPUT_BASE + 8,  read_val);
        if (read_val != 32'h005A0000) begin
            $display("FAIL: output[2] expected 0x005A0000 (90.0), got 0x%08h", read_val);
            error_count = error_count + 1;
        end else $display("PASS: output[2] = 90.0");

        read_reg(OUTPUT_BASE + 12, read_val);
        if (read_val != 32'h00630000) begin
            $display("FAIL: output[3] expected 0x00630000 (99.0), got 0x%08h", read_val);
            error_count = error_count + 1;
        end else $display("PASS: output[3] = 99.0");

        // acc_buffer phải = 0 vì ACCUM_EN = 0
        read_reg(ACC_BASE, read_val);
        if (read_val == 32'h0)
            $display("PASS: acc_buffer[0] = 0 (ACCUM_EN was off)");
        else begin
            $display("FAIL: acc_buffer[0] should be 0, got 0x%08h", read_val);
            error_count = error_count + 1;
        end

        //======================================================================
        // TEST 2: 3 channels với ACCUM_EN
        //
        // Mỗi channel dùng filter = all 1.0, input = all scale_ch
        //   ch0: input = all 1.0  → output = [9,9,9,9]  (all-ones filter, flat input)
        //   ch1: input = all 2.0  → output = [18,18,18,18]
        //   ch2: input = all 3.0  → output = [27,27,27,27]
        // acc = 9+18+27 = 54 cho mỗi pixel
        // Expected: acc_buffer = [0x00360000, 0x00360000, 0x00360000, 0x00360000]
        //======================================================================
        $display("\n--- TEST 2: 3 channels with ACCUM_EN ---");

        // Clear accumulator
        write_reg(CTRL_ADDR, CTRL_CLEAR_ACC);
        #(CLK_PERIOD * 2);
        read_reg(ACC_BASE, read_val);
        if (read_val == 32'h0)
            $display("PASS: acc_buffer cleared");
        else begin
            $display("FAIL: acc_buffer not cleared (0x%08h)", read_val);
            error_count = error_count + 1;
        end

        for (ch = 0; ch < 3; ch = ch + 1) begin
            $display("  [Channel %0d] input = %0d.0", ch, ch+1);
            for (i = 0; i < 9;  i = i + 1) filter_vals[i] = 32'h00010000;      // 1.0
            for (i = 0; i < 16; i = i + 1) input_vals[i]  = (ch + 1) << 16;    // 1.0/2.0/3.0
            run_one_channel(1); // ACCUM_EN = 1
        end

        $display("  --- acc_buffer results ---");
        for (i = 0; i < 4; i = i + 1) begin
            read_reg(ACC_BASE + (i*4), read_val);
            $display("  acc_buffer[%0d] = %f (0x%08h)", i,
                     $itor($signed(read_val)) / 65536.0, read_val);
            if (read_val != 32'h00360000) begin
                $display("  FAIL: expected 0x00360000 (54.0)");
                error_count = error_count + 1;
            end else
                $display("  PASS: acc_buffer[%0d] = 54.0", i);
        end

        // output_buffer phải là kết quả channel cuối (ch2: input=3.0 → 27.0)
        $display("  --- output_buffer (last channel only) ---");
        read_reg(OUTPUT_BASE, read_val);
        if (read_val != 32'h001B0000) begin
            $display("  FAIL: output[0] expected 0x001B0000 (27.0), got 0x%08h", read_val);
            error_count = error_count + 1;
        end else
            $display("  PASS: output_buffer[0] = 27.0 (last channel)");

        //======================================================================
        // TEST 3: CLEAR_ACC rồi chạy lại 1 channel → acc == output
        //======================================================================
        $display("\n--- TEST 3: CLEAR_ACC then re-run 1 channel ---");

        write_reg(CTRL_ADDR, CTRL_CLEAR_ACC);
        #(CLK_PERIOD * 2);

        for (i = 0; i < 9;  i = i + 1) filter_vals[i] = 32'h00010000;
        for (i = 0; i < 16; i = i + 1) input_vals[i]  = 32'h00020000; // all 2.0
        run_one_channel(1); // ACCUM_EN = 1

        read_reg(ACC_BASE,    read_val);
        $display("  acc_buffer[0] = %f", $itor($signed(read_val)) / 65536.0);
        read_reg(OUTPUT_BASE, status_val);
        $display("  output_buf[0] = %f", $itor($signed(status_val)) / 65536.0);

        if (read_val == status_val)
            $display("PASS: After clear, acc_buffer == output_buffer (1 channel)");
        else begin
            $display("FAIL: acc != output (acc=0x%08h, out=0x%08h)", read_val, status_val);
            error_count = error_count + 1;
        end

        //======================================================================
        // TEST 4: 2 channels, filter all 0.5, inputs [1..16] và [1..16]
        // Mỗi channel: f=0.5, d=[1..16]
        //   output_ch0 = output_ch1 = [27,31.5,45,49.5]
        // acc = [54, 63, 90, 99] (nhân đôi vì 2 channels giống nhau)
        // Expected giống TEST 1 output
        //======================================================================
        $display("\n--- TEST 4: 2 identical channels, verify accumulation math ---");

        write_reg(CTRL_ADDR, CTRL_CLEAR_ACC);
        #(CLK_PERIOD * 2);

        for (ch = 0; ch < 2; ch = ch + 1) begin
            for (i = 0; i < 9;  i = i + 1) filter_vals[i] = 32'h00008000; // 0.5
            for (i = 0; i < 16; i = i + 1) input_vals[i]  = (i+1) << 16;  // 1..16
            run_one_channel(1);
        end

        // Expected: 2 * output_single_channel(f=0.5, d=1..16)
        // Direct conv: sum of d[i+r][j+c]*0.5 = 0.5 * [54,63,90,99] = [27,31.5,45,49.5]
        // acc over 2 channels = [54, 63, 90, 99]
        read_reg(ACC_BASE + 0,  read_val);
        if (read_val == 32'h00360000)
            $display("PASS: acc[0] = 54.0 (2 x 27.0)");
        else begin
            $display("FAIL: acc[0] expected 0x00360000, got 0x%08h (%f)",
                     read_val, $itor($signed(read_val))/65536.0);
            error_count = error_count + 1;
        end

        read_reg(ACC_BASE + 4,  read_val);
        if (read_val == 32'h003F0000)
            $display("PASS: acc[1] = 63.0 (2 x 31.5)");
        else begin
            $display("FAIL: acc[1] expected 0x003F0000, got 0x%08h (%f)",
                     read_val, $itor($signed(read_val))/65536.0);
            error_count = error_count + 1;
        end

        read_reg(ACC_BASE + 8,  read_val);
        if (read_val == 32'h005A0000)
            $display("PASS: acc[2] = 90.0 (2 x 45.0)");
        else begin
            $display("FAIL: acc[2] expected 0x005A0000, got 0x%08h (%f)",
                     read_val, $itor($signed(read_val))/65536.0);
            error_count = error_count + 1;
        end

        read_reg(ACC_BASE + 12, read_val);
        if (read_val == 32'h00630000)
            $display("PASS: acc[3] = 99.0 (2 x 49.5)");
        else begin
            $display("FAIL: acc[3] expected 0x00630000, got 0x%08h (%f)",
                     read_val, $itor($signed(read_val))/65536.0);
            error_count = error_count + 1;
        end

        //======================================================================
        // Summary
        //======================================================================
        #(CLK_PERIOD * 10);
        $display("\n============================================================");
        $display("  Tests: 4  Errors: %0d", error_count);
        if (error_count == 0)
            $display("  Result: ALL TESTS PASSED");
        else
            $display("  Result: SOME TESTS FAILED");
        $display("============================================================");

        $finish;
    end

    // Watchdog
    initial begin
        #500_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule