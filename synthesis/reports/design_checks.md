# Synthesis Design Checks

The supplied Design Compiler check_design summary for top module systolic_array reports:

| Finding | Count |
|---|---:|
| Feedthrough ports | 35 |
| Cells that do not drive nets | 2 |
| Unloaded nets | 175 |

The detailed messages identify many unloaded nets as forwarding/control outputs at the outer edge of the generated PE array, where there is no downstream PE neighbor. The two cell-does-not-drive findings are retained as reported and should be checked against the mapped hierarchy.

The synthesis log also records 236 potential design problems and signed-to-unsigned conversion warnings. The summary does not label these findings as functional failures, but they should not be hidden or described as a warning-free synthesis run.

See [Synthesis Results](../../docs/synthesis.md) for the configuration, interpretation, and flow limitations.
