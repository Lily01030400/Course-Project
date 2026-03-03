# PPA Report — tqvp_winograd (Winograd Convolution Accelerator)

**Technology:** Sky130 HD | **Tool:** OpenLane2 v2.3.10 | **Clock:** 15ns (66.7 MHz target) | **Corner:** nom_tt_025C_1v80

---

## Area

| Metric | Value | Unit | Notes |
|---|---|---|---|
| Die Area | 0.604 | mm² | ~514 × 525 µm² estimate |
| Instance Count | 90,130 | cells | All instantiated std cells |
| Sequential Cells (FF) | 7,498 | cells | DFF flip-flops |
| Combinational Cells | 82,632 | cells | Logic + MUX |
| Core Utilization | 48.64 | % | Std cell / core area |

---

## Timing — TT Corner (25°C, 1.8V)

| Metric | Value | Unit | Notes |
|---|---|---|---|
| Clock Period | 15 | ns | ~66.7 MHz target |
| Setup WNS | +3.271 | ns | ✅ No violation |
| Setup TNS | 0.000 | ns | ✅ TT corner clean |
| Hold WNS | +0.315 | ns | ✅ Hold clean |
| Setup Violations | 0 | — | ✅ TT corner PASS |
| Hold Violations | 0 | — | ✅ TT corner PASS |

---

## Timing — SS Worst Case (100°C, 1.6V)

| Metric | Value | Unit | Notes |
|---|---|---|---|
| Setup WNS | -7.038 | ns | ❌ Critical — timing fail |
| Setup TNS | -3260.7 | ns | ❌ Total negative slack large |
| Setup Violations | 292 | paths | ❌ 292 paths fail at SS corner |
| Hold Violations | 2 | paths | ⚠️ Minor hold issues |

---

## Signal Integrity

| Metric | Value | Unit | Notes |
|---|---|---|---|
| Max Fanout Violations | 3,328 | nets | ⚠️ Present across ALL corners |
| Max Slew Violations | 1,535 | nets | ⚠️ SS corner — root cause of setup fail |
| Max Cap Violations | 6 | nets | ⚠️ Minor |

---

## Power (TT Corner, 25°C, 1.8V)

| Metric | Value | Unit | Notes |
|---|---|---|---|
| Total Power | 54.91 | mW | At nom_tt_025C_1v80 |
| Internal Power | 37.89 | mW | Largest contributor |
| Switching Power | 17.02 | mW | Dynamic net switching |
| Leakage Power | 0.66 | µW | Negligible |

---

## Physical

| Metric | Value | Unit | Notes |
|---|---|---|---|
| DRC Errors | 0 | — | ✅ DRC clean |
| LVS Errors | 0 | — | ✅ LVS PASS |
| Lint Errors | 0 | — | ✅ Lint clean |
| Inferred Latches | 0 | — | ✅ No latches |

---

## Summary

> Design passes **completely at TT corner** (25°C, 1.8V) — zero setup/hold violations, DRC clean, LVS PASS.
>
> At **SS worst-case corner** (100°C, 1.6V), timing fails due to large fanout (3,328 nets) causing excessive slew. This is the primary optimization target for **DP2**.
>
> Root cause: 90,130 cells with many 32-bit datapath operations → large fanout → timing violation at slow corner.
