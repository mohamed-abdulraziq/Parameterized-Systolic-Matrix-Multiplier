// Compatibility wrapper for the final regression top.
// The testbench defines the back-to-back test implementation as
// tb_systolic_array_reset_stress, while tb_systolic_array_final
// instantiates systolic_b2b_test. This wrapper bridges the module names
// without modifying the original testbench implementation.
module systolic_b2b_test #(
    parameter integer DW      = 24,
    parameter integer N_SIZE  = 1,
    parameter integer K_MAX   = 7*N_SIZE,
    parameter integer SEED_ID = 152
)(output wire test_done);

    tb_systolic_array_reset_stress #(
        .DW(DW),
        .N_SIZE(N_SIZE),
        .K_MAX(K_MAX),
        .SEED_ID(SEED_ID)
    ) b2b_test_inst (
        .test_done(test_done)
    );

endmodule
