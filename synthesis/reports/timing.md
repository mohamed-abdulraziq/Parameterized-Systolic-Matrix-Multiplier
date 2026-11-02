# Synthesis Timing Report

**Top:** systolic_array  
**Configuration:** DW=16, N_SIZE=5, K_MAX=5, ACC_WIDTH=35  
**Example clock period:** 10.000 ns  
**Clock uncertainty:** 0.200 ns  
**Input/output delays:** 1.000 ns

## Setup

The supplied report lists the 20 worst max-delay paths. The worst listed path reports **0.00 ns slack**.

The first critical path starts at the top-level **global_enable** input and ends at a PE product register. The path passes through the enable/control logic and signed multiplier implementation before reaching the product-register D pin. Several other top paths have the same global-enable-to-product-register pattern.

This indicates that the design is at the timing boundary for the example 10 ns constraint. It does not establish comfortable margin or a post-route 100 MHz operating frequency.

## Hold

The supplied report lists 20 min-delay paths. The smallest displayed slack in that list is **+0.24 ns**. This is the minimum among the reported paths, not a full-chip multi-corner hold sign-off result.

These are synthesis timing reports with the constraints and library setup used for that run. There is no placement, CTS, routing, or extracted-parasitic timing report in this project.
