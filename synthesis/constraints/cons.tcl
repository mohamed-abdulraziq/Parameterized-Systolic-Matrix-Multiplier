###############################################################################
# Example timing constraints for systolic_array.
#
# These values match the example constraint set reflected in the supplied
# synthesis timing reports. They are not a substitute for interface timing
# requirements from a real integration environment. Review clock, I/O delays,
# loads, transitions, and asynchronous-reset treatment before reuse.
###############################################################################

create_clock -name clk -period 10.000 [get_ports clk]
set_clock_uncertainty 0.200 [get_clocks clk]

set_input_delay 1.000 -clock clk \
    [get_ports {a_in* b_in* valid_in first_in last_in global_enable rst_n}]

set_output_delay 1.000 -clock clk \
    [get_ports {matrix_c_out* row_index* valid_out matrix_done}]

set_input_transition 0.100 [all_inputs]
set_load 0.010 [all_outputs]

# rst_n is asynchronous in the RTL. Review whether it should be excluded from
# ordinary synchronous I/O timing under the target sign-off methodology.
