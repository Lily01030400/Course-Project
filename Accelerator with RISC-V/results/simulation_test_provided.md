# Simulation Report — tqvp_winograd (Winograd Convolution Accelerator)

**Tool:** Icarus Verilog v11/v12 + cocotb v1.9.2 | **Date:** March 2026

---

## Overall Summary

| Phase | Testbench | Tests | Pass | Fail | Status |
|---|---|---|---|---|---|
| Test 1 | test.py (SPI harness) | 2 | 2 | 0 | ✅ ALL PASS |
| Test 2 | peri_num_14 (GitHub Actions CI) | 2 | 2 | 0 | ✅ ALL PASS |

---

## Test 1 — Peripheral-Only Test (SPI Harness)

**Framework:** tinyqv-full-peripheral-template  
**Tool:** cocotb v1.9.2 + Icarus Verilog v11.0  
**Command:** `make` in `tinyqv-full-peripheral-template/test/`

```
** TESTS=2  PASS=2  FAIL=0  SKIP=0  **
Total sim time: 1,055,600 ns
```

| Test | Description | Sim Time | Status |
|---|---|---|---|
| test_0_address_debug | Address mapping verification | 159,600 ns | ✅ PASS |
| test_winograd_peripheral | Full convolution end-to-end | 896,000 ns | ✅ PASS |

**Detailed log:**
```
  53800 ns  INPUT_BUF[0]  write 0x12345678 → read back 0x12345678  ✅
 106700 ns  INPUT_BUF[1]  write 0xAABBCCDD → read back 0xaabbccdd  ✅
 159600 ns  FILTER_BUF[0] write 0x11223344 → read back 0x11223344  ✅
 159600 ns  PASS: Address mapping OK

 187300 ns  STATUS initial = 0 OK
 894900 ns  Started convolution...
 948800 ns  Done after 1 polls, STATUS=0x00000000
1055600 ns  Output[0..3] = ['9.0000', '9.0000', '9.0000', '9.0000']  ✅
1055600 ns  === PASS: All tests passed ===
```

---

## Test2 — Full Integration Test (GitHub Actions CI)

**Repo:** https://github.com/Lily01030400/ttsky25a-tinyQV  
**Job:** test (peri_num_14) — **Successful in 1m**  
**Tool:** cocotb v1.9.2 + Icarus Verilog v12.0  
**CPU:** TinyQV RISC-V (real CPU executing load/store instructions)

```
** TESTS=2  PASS=2  FAIL=0  SKIP=0  **
Total sim time: 640,300 ns
```

| Test | Description | Sim Time | Status |
|---|---|---|---|
| test_0_address_debug | Address mapping via CPU load/store | 107,350 ns | ✅ PASS |
| test_winograd_peripheral | Full convolution via CPU | 532,950 ns | ✅ PASS |

**Detailed log:**
```
  49750 ns  INPUT_BUF[0]  write 0x12345678 → read back 0x12345678  ✅
  78550 ns  INPUT_BUF[1]  write 0xAABBCCDD → read back 0xaabbccdd  ✅
 107350 ns  FILTER_BUF[0] write 0x11223344 → read back 0x11223344  ✅
 107350 ns  PASS: Address mapping OK

 141900 ns  STATUS initial = 0 OK
 563100 ns  Started convolution...
 589100 ns  Done after 1 polls, STATUS=0x00000000
 640300 ns  Output[0..3] = ['9.0000', '9.0000', '9.0000', '9.0000']  ✅
 640300 ns  === PASS: All tests passed ===
```

