module systolic_array #(
    parameter int DW            = 16,
    parameter int N_SIZE        = 5,
    parameter int K_MAX         = N_SIZE,
    parameter int ACC_WIDTH     = 2*DW + $clog2(K_MAX),
    parameter int ROW_IDX_WIDTH = (N_SIZE <= 1) ? 1 : $clog2(N_SIZE)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic global_enable,

    input  logic signed [DW-1:0] a_in [N_SIZE-1:0],
    input  logic signed [DW-1:0] b_in [N_SIZE-1:0],
    input  logic valid_in,
    input  logic first_in,
    input  logic last_in,
    
    output logic signed [ACC_WIDTH-1:0] matrix_c_out [N_SIZE-1:0],
    output logic [ROW_IDX_WIDTH-1:0] row_index,
    output logic valid_out,
    output logic matrix_done
);

    logic signed [DW-1:0] a_skew [N_SIZE-1:0];
    logic signed [DW-1:0] b_skew [N_SIZE-1:0];
    logic valid_skew [N_SIZE-1:0];
    logic first_skew [N_SIZE-1:0];
    logic last_skew [N_SIZE-1:0];
    logic signed [ACC_WIDTH-1:0] pe_result [N_SIZE-1:0][N_SIZE-1:0];
    logic pe_result_valid [N_SIZE-1:0][N_SIZE-1:0];

    skew_network #(
        .DW(DW),
        .N_SIZE(N_SIZE)
    ) skew_inst (
        .clk(clk),
        .rst_n(rst_n),
        .global_enable(global_enable),
        .a_in(a_in),
        .b_in(b_in),
        .valid_in(valid_in),
        .first_in(first_in),
        .last_in(last_in),
        .a_out(a_skew),
        .b_out(b_skew),
        .valid_out(valid_skew),
        .first_out(first_skew),
        .last_out(last_skew)
    );

    PE_array #(
        .DW(DW),
        .N_SIZE(N_SIZE),
        .K_MAX(K_MAX),
        .ACC_WIDTH(ACC_WIDTH)
    ) array_inst (
        .clk(clk),
        .rst_n(rst_n),
        .global_enable(global_enable),
        .a_skew(a_skew),
        .b_skew(b_skew),
        .valid_skew(valid_skew),
        .first_skew(first_skew),
        .last_skew(last_skew),
        .result(pe_result),
        .result_valid(pe_result_valid)
    );

    output_collector #(
        .DW(DW),
        .N_SIZE(N_SIZE),
        .K_MAX(K_MAX),
        .ACC_WIDTH(ACC_WIDTH),
        .ROW_IDX_WIDTH(ROW_IDX_WIDTH)
    ) collector_inst (
        .clk(clk),
        .rst_n(rst_n),
        .global_enable(global_enable),
        .pe_result(pe_result),
        .pe_result_valid(pe_result_valid),
        .matrix_c_out(matrix_c_out),
        .row_index(row_index),
        .valid_out(valid_out),
        .matrix_done(matrix_done)
    );

endmodule