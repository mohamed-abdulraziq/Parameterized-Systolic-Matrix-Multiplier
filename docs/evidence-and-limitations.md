# Evidence, Scope, and Limitations

## Evidence included in this repository

- SystemVerilog RTL for the PE, PE array, skew network, output collector, and top-level integration.
- Self-checking SystemVerilog testbench and the small module-name compatibility wrapper.
- Final regression counters and pass status supplied with the project.
- Synopsys Design Compiler synthesis script and reviewable example constraints.
- Reviewed synthesis area, top-20 setup/hold path, power, and design-check results.

## Configuration boundaries

- Functional regression: four configurations, including 7×7 with K=28.
- Synthesis reports: default 5×5 configuration only.
- The 7×7 configuration is not represented by the supplied synthesis metrics.
- The 10 ns clock in the synthesis constraints is an example constraint set, not a validated post-route operating frequency.

## Results not claimed

This repository does not claim formal equivalence, scan DFT/ATPG, floorplan/place/CTS/route, parasitic extraction, post-route STA, physical sign-off, sign-off power, or silicon measurement.

## Tool/report interpretation

- Setup: the worst listed setup slack is 0.00 ns in the supplied top-20 report.
- Hold: +0.24 ns is the smallest slack among the 20 paths listed in the supplied report.
- Power: 8.774 mW is a low-effort estimate with incomplete activity annotation.
- Design checks: 35 feedthrough ports, 2 cells that do not drive nets, and 175 unloaded nets were reported. The unloaded nets include unused edge forwarding/control outputs in the generated PE array.
- Synthesis area is library area, not mm², and the report has no wire-load model.

## Reproducibility and proprietary dependencies

The synthesis script is sanitized to remove absolute machine paths and licensed library names. It expects the user to provide an authorized technology library directory and library filenames through environment variables. Generated mapped netlists, DDC, SDF, and licensed PDK/library files are not included.
