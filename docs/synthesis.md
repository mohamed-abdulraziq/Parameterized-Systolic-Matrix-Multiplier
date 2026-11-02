# Synthesis Results

## Run configuration

The supplied Synopsys Design Compiler reports are for:

| Parameter | Value |
|---|---:|
| Top module | systolic_array |
| DW | 16 |
| N_SIZE | 5 |
| K_MAX | 5 |
| ACC_WIDTH | 35 |
| Clock period in example constraints | 10.000 ns |
| Clock uncertainty | 0.200 ns |
| Input delay | 1.000 ns |
| Output delay | 1.000 ns |

The supplied script identifies the I/O and clock values as example constraints that should be reviewed for the intended integration environment.

## Area

| Metric | Result |
|---|---:|
| Ports | 12,173 |
| Nets | 48,369 |
| Total mapped cells | 30,983 |
| Combinational cells | 26,946 |
| Sequential cells | 3,934 |
| Buffer/inverter instances | 4,027 |
| Macros / black boxes | 0 |
| Combinational area (includes buffer/inverter area) | 420,479.631256 |
| Buffer/inverter area (included above) | 17,303.373787 |
| Non-combinational area | 100,188.943846 |
| **Total cell area** | **520,668.575101** |

Area values are technology-library area units, not mm². The report lists net interconnect area as undefined because no wire-load model was specified. The total area shown is mapped cell area, not physical layout area.

## Setup timing

The supplied report is a top-20 max-delay path report. The worst listed paths have **0.00 ns slack** under the 10 ns constraint. The first critical path starts at global_enable and ends at a PE product register, passing through the PE control/multiplier logic.

The report indicates that the design is at the timing boundary for the supplied constraint. The 100 MHz constraint should not be presented as a demonstrated operating frequency or as a comfortable timing closure result.

## Hold timing

The supplied hold report lists 20 paths. The smallest displayed slack among those paths is **+0.24 ns**. This is the minimum within the listed path set, not a full-chip multi-corner hold sign-off statement.

## Power estimate

The Design Compiler power report gives:

| Component | Estimate |
|---|---:|
| Switching power | 0.593 mW |
| Internal power | 7.713 mW |
| Leakage power | approximately 0.469 mW |
| **Total power** | **8.774 mW** |

The power run uses low analysis effort and zero-delay activity propagation. It reports unannotated primary inputs and unannotated sequential cell outputs. Treat this result as an early estimate under the reported activity assumptions, not measured or sign-off power.

## Design checks

The supplied check_design summary for systolic_array lists:

| Finding | Count |
|---|---:|
| Feedthrough ports | 35 |
| Cells that do not drive nets | 2 |
| Unloaded nets | 175 |

The unloaded nets shown in the report include edge-of-array forwarding and control outputs that have no downstream PE neighbor. The two undriven-cell findings are disclosed as reported and should be reviewed against the mapped hierarchy. These checks are not a clean/no-warning claim.

## Flow scope

The supplied Design Compiler flow covers RTL analysis/elaboration, linking, synthesis and technology mapping, timing/design checks, and generation of mapped netlist, DDC, SDC, SDF, and reports.

This project does not include scan DFT/ATPG, Formality equivalence, physical floorplanning, placement, CTS, routing, parasitic extraction, or post-route sign-off timing. No such results are claimed.
