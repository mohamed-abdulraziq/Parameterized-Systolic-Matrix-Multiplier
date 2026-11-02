# Synthesis Report Summary

The supplied Design Compiler report set corresponds to systolic_array with DW=16, N_SIZE=5, K_MAX=5, and ACC_WIDTH=35.

## Report snapshots

- [Area and mapped cell statistics](area.md)
- [Setup and hold timing](timing.md)
- [Power estimate](power.md)
- [Design checks and reported findings](design_checks.md)

## Interpretation

Area is reported in technology-library units, not mm². The report has no wire-load model. Setup slack reaches 0.00 ns on the worst listed path under the 10 ns example constraint. The hold report is limited to the 20 paths listed. Power is a low-effort estimate with incomplete activity annotation. The check-design findings are disclosed in the separate report.

The public repository contains reviewed report snapshots rather than raw reports. The source reports include machine-specific absolute paths and licensed technology-library identifiers; these have been excluded from the public copy. The numerical results and relevant limitations are retained.
