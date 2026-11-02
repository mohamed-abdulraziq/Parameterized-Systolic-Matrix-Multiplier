# Functional Verification

## Regression structure

The supplied final regression top is tb_systolic_array_final. It runs four back-to-back test configurations and a reset-stress test.

| Seed | DW | N_SIZE | K_MAX | ACC_WIDTH | Matrices |
|---:|---:|---:|---:|---:|---:|
| 101 | 8 | 1 | 1 | 16 | 95 |
| 202 | 8 | 2 | 3 | 18 | 95 |
| 303 | 16 | 5 | 5 | 35 | 95 |
| 404 | 16 | 7 | 28 | 37 | 95 |

The regression covers the minimum 1×1 configuration, a 2×2 array where K exceeds N, the 5×5 default configuration, and a 7×7 array with a 28-term reduction length.

## Largest-configuration counters

For DW=16, N_SIZE=7, K_MAX=28, seed 404:

| Counter | Expected | Reported |
|---|---:|---:|
| Accepted input beats | 2,660 | 2,660 |
| Completed matrices | 95 | 95 |
| Completed rows | 665 | 665 |
| matrix_done pulses | 95 | 95 |
| Input bubbles | 0 | 0 |
| Input errors | 0 | 0 |
| Output errors | 0 | 0 |

The transcript also records 841 input stall cycles, 14 output stall cycles, and 856 global stall cycles. It concludes with **PASS: back-to-back streaming with random global stalls** and **ALL TESTS PASSED**.

## Test dimensions

The supplied testbench exercises:

- Directed and randomized signed matrix data.
- Zero and identity-like patterns.
- Alternating signed extremes and ±1 values.
- Minimum/maximum operand corner cases.
- Back-to-back matrix streams with no intentional input bubbles.
- Random global stalls and controlled output-side stalls.
- Output row ordering and output stability while stalled.
- Reset during partial input, active PE pipeline processing, pending output, and partial output consumption.
- Invalid cycles where valid_in=0 while first_in/last_in may contain arbitrary values.
- Recovery after reset without stale outputs.

The project notes for the reset stress test report four reset events, five recovery matrices, and 35 of 35 rows verified for the 7×7 configuration, with no stale output errors.

## Regression summary

The supplied final transcript reports:

- Four back-to-back parameter configurations passed.
- 380 matrices across the four configured tests.
- 3,515 accepted input beats and 1,425 output rows, calculated from the four configuration dimensions and the 95 matrices per configuration.
- Reset stress passed.
- Final status: **ALL TESTS PASSED**.

The testbench implementation is retained as supplied. A small wrapper exposes the module name expected by the final regression top without changing the original back-to-back test implementation.

## Reproduction

From the repository root:

~~~tcl
vlib work
vlog -sv rtl/PE.sv rtl/PE_Array.sv rtl/skew_network.sv rtl/output_collector.sv rtl/systolic_array.sv
vlog -sv verification/systolic_array_tb.sv verification/systolic_b2b_test_wrapper.sv
vsim -c work.tb_systolic_array_final -do "run -all; quit -f"
~~~

The pass/fail transcript was supplied with the project. It was not independently rerun during repository preparation; the command above is the documented reproduction sequence.
