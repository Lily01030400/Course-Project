# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from tqv import TinyQV

PERIPHERAL_NUM = 0

# -----------------------------------------------------------------------
# Address map (6-bit word address truyền thẳng vào tqv.write/read)
#
# peripheral.v dùng address[5:4] làm bank select:
#   addr[5:4]=00 (0x00..0x0F) → laddr 0x000..0x03C  (CTRL/STATUS/CONFIG)
#   addr[5:4]=01 (0x10..0x1F) → laddr 0x100..0x13C  (INPUT_BUF)
#   addr[5:4]=10 (0x20..0x2F) → laddr 0x200..0x23C  (FILTER_BUF)
#   addr[5:4]=11,bit3=0 (0x30..0x37) → laddr 0x300  (OUTPUT_BUF)
#   addr[5:4]=11,bit3=1 (0x38..0x3F) → laddr 0x400  (ACC_BUF)
#
# Quan trọng: template truyền address trực tiếp (không nhân 4).
# winograd_peripheral dùng laddr = data_addr[11:0] để decode.
# Trong peripheral.v: laddr_mapped = {bank, index, 2'b00}
# nên index[3:0] = address[3:0], offset tự thêm 2'b00 (nhân 4).
# -----------------------------------------------------------------------
ADDR_CTRL        = 0x00   # → laddr 0x000 (CTRL)
ADDR_STATUS      = 0x01   # → laddr 0x004 (STATUS)
ADDR_INPUT_BASE  = 0x10   # → laddr 0x100..0x13C (16 words)
ADDR_FILTER_BASE = 0x20   # → laddr 0x200..0x220 (9 words)
ADDR_OUTPUT_BASE = 0x30   # → laddr 0x300..0x30C (4 words)
ADDR_ACC_BASE    = 0x38   # → laddr 0x400..0x40C (4 words)

CTRL_START     = (1 << 0)
CTRL_IRQ_EN    = (1 << 2)
CTRL_ACCUM_EN  = (1 << 3)
CTRL_CLEAR_ACC = (1 << 4)

STATUS_BUSY = (1 << 0)
STATUS_DONE = (1 << 1)

def to_fixed(x, frac_bits=16):
    val = int(round(x * (1 << frac_bits)))
    if val < 0:
        val = val & 0xFFFFFFFF
    return val

def from_fixed(val, frac_bits=16):
    if val >= (1 << 31):
        val -= (1 << 32)
    return val / (1 << frac_bits)


@cocotb.test()
async def test_0_address_debug(dut):
    """Debug test: kiểm tra address mapping có đúng không"""
    dut._log.info("=== Test 0: Address Mapping Debug ===")
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()

    # Ghi vào INPUT_BUF[0] = 0x12345678
    await tqv.write_word_reg(ADDR_INPUT_BASE + 0, 0x12345678)
    val = await tqv.read_word_reg(ADDR_INPUT_BASE + 0)
    dut._log.info(f"  INPUT_BUF[0] write 0x12345678, read back = {val:#010x}")
    assert val == 0x12345678, f"Address mapping FAIL: got {val:#010x}, expected 0x12345678. Check bank select logic in peripheral.v"

    # Ghi vào INPUT_BUF[1] = 0xAABBCCDD
    await tqv.write_word_reg(ADDR_INPUT_BASE + 1, 0xAABBCCDD)
    val = await tqv.read_word_reg(ADDR_INPUT_BASE + 1)
    dut._log.info(f"  INPUT_BUF[1] write 0xAABBCCDD, read back = {val:#010x}")
    assert val == 0xAABBCCDD, f"Address mapping FAIL at INPUT[1]: {val:#010x}"

    # Ghi vào FILTER_BUF[0] = 0x11223344
    await tqv.write_word_reg(ADDR_FILTER_BASE + 0, 0x11223344)
    val = await tqv.read_word_reg(ADDR_FILTER_BASE + 0)
    dut._log.info(f"  FILTER_BUF[0] write 0x11223344, read back = {val:#010x}")
    assert val == 0x11223344, f"Address mapping FAIL at FILTER[0]: {val:#010x}"

    dut._log.info("  PASS: Address mapping OK")


@cocotb.test()
async def test_winograd_peripheral(dut):
    """Main test: Winograd convolution"""
    dut._log.info("=== Winograd Peripheral Test ===")
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()

    # --- Check STATUS ban đầu = 0 ---
    status = await tqv.read_word_reg(ADDR_STATUS)
    assert status == 0, f"Expected STATUS=0, got {status:#010x}"
    dut._log.info("  STATUS initial = 0 OK")

    # --- Ghi INPUT/FILTER all 1.0 ---
    for i in range(16):
        await tqv.write_word_reg(ADDR_INPUT_BASE + i, to_fixed(1.0))
    for i in range(9):
        await tqv.write_word_reg(ADDR_FILTER_BASE + i, to_fixed(1.0))

    # --- Clear ACC rồi START ---
    await tqv.write_word_reg(ADDR_CTRL, CTRL_CLEAR_ACC)
    await ClockCycles(dut.clk, 2)
    await tqv.write_word_reg(ADDR_CTRL, CTRL_START)
    dut._log.info("  Started convolution...")

    # --- Poll STATUS đến khi không BUSY ---
    for attempt in range(3000):
        status = await tqv.read_word_reg(ADDR_STATUS)
        if not (status & STATUS_BUSY):
            dut._log.info(f"  Done after {attempt} polls, STATUS={status:#010x}")
            break
        await ClockCycles(dut.clk, 5)
    else:
        assert False, "TIMEOUT: Winograd không hoàn thành sau 3000 polls"

    # --- Đọc OUTPUT ---
    outputs = []
    for i in range(4):
        val = await tqv.read_word_reg(ADDR_OUTPUT_BASE + i)
        outputs.append(from_fixed(val))
    dut._log.info(f"  Output[0..3] = {[f'{v:.4f}' for v in outputs]}")

    # Với input 4x4 all-1, filter 3x3 all-1 → output 2x2 all ~9.0
    for i, out in enumerate(outputs):
        assert abs(out - 9.0) < 0.5, f"OUTPUT[{i}]: expected ~9.0, got {out:.4f}"

    dut._log.info("=== PASS: All tests passed ===")