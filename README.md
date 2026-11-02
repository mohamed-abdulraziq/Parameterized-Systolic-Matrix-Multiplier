# Parameterized Output-Stationary Systolic Matrix Multiplier

A parameterized N × N SystemVerilog accelerator for signed matrix multiplication using an **output-stationary systolic dataflow**. The design is built from a regular grid of processing elements (PEs), a configurable operand-skew network, and an ordered output collector.

Each PE owns one output element C[i,j], keeps its partial sum locally, receives A[i,k] horizontally and B[k,j] vertically, and accumulates the dot product across the reduction dimension K.

## Design at a glance

- Parameterized operand width, array dimension, reduction length, accumulator width, and row-index width.
- N × N processing-element array with signed multiply-accumulate datapaths.
- Output-stationary dataflow: partial sums remain inside their destination PEs.
- Row-wise A propagation and column-wise B propagation.
- Matching skew of operands and valid, first, and last control markers.
- Global-enable stall support across the PE pipeline, skew network, and output collector.
- Ordered row collection with per-row completion tracking and a matrix_done pulse.
- Self-checking back-to-back regression across four parameter configurations, plus reset/recovery stress testing.

## Architecture

~~~mermaid
flowchart LR
    SRC["A vector / B vector<br/>valid, first, last"] --> SK["Operand & control<br/>skew network"]
    SK --> PE["N × N PE array<br/>output-stationary"]
    PE --> OC["N × N result buffer<br/>row-valid tracking"]
    OC --> OUT["matrix_c_out[N_SIZE]<br/>row_index, valid_out"]
    OC --> DONE["matrix_done"]
    EN["global_enable"] -.-> SK
    EN -.-> PE
    EN -.-> OC
~~~

**Data movement:** A operands move from left to right across each PE row. B operands move from top to bottom down each PE column. The skew network delays row i's A stream by i enabled cycles and column j's B stream by j enabled cycles so the matching A[i,k] and B[k,j] values meet at PE (i,j).

See [Architecture and Dataflow](docs/architecture.md) for the PE microarchitecture, wavefront alignment, collector behavior, and interface contract.

## Parameterization

| Parameter | Default | Description |
|---|---:|---|
| DW | 16 | Signed input operand width |
| N_SIZE | 5 | Number of PE rows and columns |
| K_MAX | N_SIZE | Maximum dot-product length |
| ACC_WIDTH | 2*DW + $clog2(K_MAX) | Signed accumulator/result width |
| ROW_IDX_WIDTH | max(1, $clog2(N_SIZE)) | Output row-index width |

The configured accumulator width must be sufficient for the maximum supported reduction length. The tested configurations include both K=N and K>N.

## AI-assisted development disclosure

The verification strategy, test scenarios, parameter configurations, corner cases, and expected behavior were defined by the project author. AI assistance was used as a development aid to translate parts of that plan into SystemVerilog testbench code. The resulting testbench was then used for the reported simulation regression. The AI assistance was limited to testbench implementation support; it does not change the authorship of the RTL architecture and design decisions.

## Functional verification

The supplied final regression runs four back-to-back configurations (95 matrices per configuration) and a reset-stress test.

| Seed | DW | N_SIZE | K_MAX | ACC_WIDTH | Matrices |
|---:|---:|---:|---:|---:|---:|
| 101 | 8 | 1 | 1 | 16 | 95 |
| 202 | 8 | 2 | 3 | 18 | 95 |
| 303 | 16 | 5 | 5 | 35 | 95 |
| 404 | 16 | 7 | 28 | 37 | 95 |

The supplied regression transcript reports **ALL TESTS PASSED** across these four configurations and the reset test. Across the four back-to-back configurations, this represents 380 matrices, 3,515 accepted input beats, and 1,425 output rows.

For the largest configuration (DW=16, N_SIZE=7, K_MAX=28), the transcript reports:

| Verification counter | Result |
|---|---:|
| Accepted input beats | 2,660 / 2,660 expected |
| Input bubbles | 0 |
| Input errors | 0 |
| Input stall cycles | 841 |
| Output stall cycles | 14 |
| Global stall cycles | 856 |
| Completed matrices | 95 / 95 expected |
| Completed output rows | 665 / 665 expected |
| matrix_done pulses | 95 / 95 expected |
| Output errors | 0 |

The testbench also checks signed arithmetic patterns, output ordering, result stability during stalls, reset while work is in flight, and recovery without stale outputs. Full details are in [Verification Results](docs/verification.md).

## Throughput model

The array accepts one vector beat per enabled clock cycle. A beat carries the next reduction-step operands for all rows and columns; when valid, all N² PEs can perform one multiply-accumulate operation in parallel.

- **Peak array issue rate:** N² MAC operations per enabled cycle.
- **Input rate:** one accepted reduction-step beat per enabled cycle.
- **Matrix interval:** K accepted beats per matrix, so the ideal steady-state matrix rate is f_clk/K, assuming continuous input and no stalls.
- **Output interface:** up to one completed row per enabled cycle; each row contains N result elements.

For the 7×7, K=28 configuration, the datapath has 49 PEs and a peak issue rate of 49 MAC/cycle. At a hypothetical 100 MHz operating clock, that corresponds to an architectural peak of 4.9 GMAC/s and an ideal matrix rate of about 3.57 million matrices/s. **These are calculated upper bounds, not measured silicon or post-route performance.** The 7×7 configuration was functionally simulated; the supplied synthesis report is for the 5×5 default configuration.

The synthesis timing report for the 5×5 configuration has a worst setup slack of 0.00 ns under the example 10 ns clock constraint. Therefore, 100 MHz is the constraint used for the synthesis run, not a demonstrated operating frequency. The simulation transcript gives stall counters but not total elapsed clock cycles, so no measured MAC/s or end-to-end latency is claimed.

See [Throughput and Latency](docs/performance.md) for assumptions and derivations.

## Synthesis results

The supplied Synopsys Design Compiler reports are for the default configuration (DW=16, N_SIZE=5, K_MAX=5, ACC_WIDTH=35) using a 10 ns example clock constraint.

| Metric | Reported result |
|---|---:|
| Mapped cell count | 30,983 |
| Combinational cells | 26,946 |
| Sequential cells | 3,934 |
| Buffer/inverter instances | 4,027 |
| Total cell area | 520,668.575101 library area units |
| Worst listed setup slack | 0.00 ns |
| Minimum slack among 20 listed hold paths | +0.24 ns |
| Estimated total power | 8.774 mW |

Area is in technology-library units, not mm². The report has no wire-load model, so it does not provide physical interconnect area or placed layout area. The power report uses low-effort, zero-delay activity propagation and flags unannotated primary inputs and sequential outputs; 8.774 mW is an estimate under those assumptions.

The critical setup paths start at global_enable and reach PE product registers through the multiplier/control cone. The design-check report lists 35 feedthrough ports, two cells that do not drive nets, and 175 unloaded nets; many unloaded nets are edge-of-array forwarding/control signals. These checks are documented rather than presented as a warning-free result.

See [Synthesis and Timing Results](docs/synthesis.md), with individual [area](synthesis/reports/area.md), [timing](synthesis/reports/timing.md), [power](synthesis/reports/power.md), and [design-check](synthesis/reports/design_checks.md) summaries.

## Repository structure

~~~text
.
├── rtl/
│   ├── PE.sv
│   ├── PE_Array.sv
│   ├── skew_network.sv
│   ├── output_collector.sv
│   └── systolic_array.sv
├── verification/
│   ├── systolic_array_tb.sv
│   └── systolic_b2b_test_wrapper.sv
├── synthesis/
│   ├── scripts/systolic_array_dc.tcl
│   ├── constraints/cons.tcl
│   └── reports/
└── docs/
    ├── architecture.md
    ├── performance.md
    ├── verification.md
    ├── synthesis.md
    └── evidence-and-limitations.md
~~~

## Simulation

The regression top is **tb_systolic_array_final**.

Example ModelSim/Questa command sequence from the repository root:

~~~tcl
vlib work
vlog -sv rtl/PE.sv rtl/PE_Array.sv rtl/skew_network.sv rtl/output_collector.sv rtl/systolic_array.sv
vlog -sv verification/systolic_array_tb.sv verification/systolic_b2b_test_wrapper.sv
vsim -c work.tb_systolic_array_final -do "run -all; quit -f"
~~~

The wrapper maps the test module name expected by the final regression top to the back-to-back test module name declared in the supplied testbench. The original testbench logic is preserved. The project regression run completed with all four parameter configurations passing and the reset-stress test passing. The checked-in testbench and wrapper provide the corresponding reproducible simulation setup.

## Synthesis

The reviewable Design Compiler script is in **synthesis/scripts/systolic_array_dc.tcl**. Configure the licensed technology libraries using the documented environment variables and review the example constraints before running:

~~~sh
dc_shell -f synthesis/scripts/systolic_array_dc.tcl
~~~

The script generates reports, a mapped netlist, DDC, SDC, and SDF in local output folders. Licensed standard-cell libraries, absolute machine paths, and generated technology-dependent netlists are not included.

## Scope

This repository covers RTL design, functional verification, and synthesis. It does not claim formal equivalence, scan DFT/ATPG, floorplanning, placement, CTS, routing, parasitic extraction, post-route timing, sign-off power, or silicon measurement.
