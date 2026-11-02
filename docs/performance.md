# Throughput and Latency

This note separates the data-rate capability implied by the RTL architecture from measured simulation counters and synthesis timing evidence.

## 1. Work performed per input beat

The input interface carries one A vector and one B vector per reduction step. Each vector contains N signed operands. When valid_in=1 and the pipeline advances, the systolic wavefront can activate all N² PEs for the current reduction step.

Each PE performs one signed multiplication and updates one local partial sum. Therefore:

- MACs per accepted input beat = N_SIZE × N_SIZE.
- MACs per matrix = N_SIZE × N_SIZE × K.

The architecture can accept one reduction-step beat per enabled clock cycle. This is the ideal no-stall input issue rate; deasserting global_enable pauses the entire pipeline.

## 2. Ideal steady-state rates

Let f_clk be the clock frequency and K the reduction length.

| Quantity | Ideal rate |
|---|---|
| Accepted input beats | f_clk beats/s |
| PE MAC issue rate | N² × f_clk MAC/s |
| Matrix completion rate | f_clk / K matrices/s |
| Average output-row rate | N × f_clk / K rows/s |
| Average output-element rate | N² × f_clk / K elements/s |

These are architectural upper bounds assuming continuous valid input, no global stalls, no output-side pause, and a clock that the implementation can actually meet.

## 3. Example: 7×7, K=28

For DW=16, N_SIZE=7, K_MAX=28, ACC_WIDTH=37:

- Number of PEs: 7 × 7 = 49.
- MAC operations per matrix: 7 × 7 × 28 = 1,372.
- Input beats per matrix: 28.
- At an assumed 100 MHz clock: 49 × 100 MHz = **4.9 GMAC/s** peak PE issue rate.
- At that same assumed clock: 100 MHz / 28 = **3.57 million matrices/s** ideal matrix rate.
- Average output rate: 7 × 100 MHz / 28 = **25 million rows/s**, or 175 million result elements/s.

The 7×7 configuration is functionally covered by the supplied regression. The supplied Design Compiler area/timing/power reports are for the 5×5 default configuration, not this 7×7 configuration.

## 4. Example: synthesized 5×5 configuration

The Design Compiler report uses DW=16, N_SIZE=5, K_MAX=5, ACC_WIDTH=35 and a 10 ns example clock constraint.

At a hypothetical 100 MHz with no stalls:

- 25 PEs can issue up to 25 MACs per enabled cycle.
- The ideal peak issue rate would be 2.5 GMAC/s.
- The ideal matrix rate would be 20 million matrices/s.

However, the supplied worst setup slack is 0.00 ns under this constraint. The synthesis result does not demonstrate robust timing margin or post-route operation at 100 MHz. The figures above are derived from the architecture and constraint frequency; they are not measured throughput.

## 5. What the simulation demonstrates

For the largest functional configuration (DW=16, N_SIZE=7, K_MAX=28), the supplied back-to-back regression reports:

| Counter | Result |
|---|---:|
| Accepted beats | 2,660 |
| Completed matrices | 95 |
| Completed rows | 665 |
| Input bubbles | 0 |
| Input stall cycles | 841 |
| Output stall cycles | 14 |
| Global stall cycles | 856 |
| Output errors | 0 |

The input count is exactly 95 × 28 beats, and the output count is exactly 95 × 7 rows. This establishes correct back-to-back transaction accounting under the generated random global stalls. The transcript does not report the complete elapsed cycle count for the test, so an observed sustained throughput in beats/s, matrices/s, or MAC/s cannot be calculated from this excerpt.

## 6. Aggregate arithmetic work in the four back-to-back regressions

The four configured back-to-back tests cover the following MAC work:

| Configuration | Matrices | MACs per matrix | MACs checked |
|---|---:|---:|---:|
| 1×1, K=1 | 95 | 1 | 95 |
| 2×2, K=3 | 95 | 12 | 1,140 |
| 5×5, K=5 | 95 | 125 | 11,875 |
| 7×7, K=28 | 95 | 1,372 | 130,340 |
| **Total** | **380** | — | **143,450** |

This is the amount of arithmetic work represented by the verified matrix transactions, calculated from each configuration's dimensions and reduction length. It is not a measured operations-per-second result.

## 7. Latency

End-to-end latency depends on the configured array dimension, the row/column skew, PE pipeline stages, and when the collector has captured a complete output row. The supplied regression validates functional ordering and stability but does not provide a dedicated measured input-to-first-row or input-to-matrix-done latency report. Accordingly, this repository documents the pipeline structure and steady-state rate rather than publishing an unsupported fixed cycle-latency number.

## 8. Timing evidence

The 5×5 synthesis setup report lists the critical paths from global_enable to PE product registers and reports a worst listed slack of 0.00 ns under the 10 ns example constraint. The hold report lists 20 paths, with the smallest displayed slack of +0.24 ns. This is pre-layout synthesis evidence; it is not routed timing or sign-off.
