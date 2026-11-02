module PE_array #(
    parameter int DW        = 16,
    parameter int N_SIZE    = 5,
    parameter int K_MAX     = N_SIZE,
    parameter int ACC_WIDTH = 2*DW + $clog2(K_MAX)
)(
    input logic clk,
    input logic rst_n,
    input logic global_enable,

    // Skewed inputs from Skew Network
    input logic signed [DW-1:0] a_skew [N_SIZE-1:0],
    input logic signed [DW-1:0] b_skew [N_SIZE-1:0],

    input logic valid_skew [N_SIZE-1:0],
    input logic first_skew [N_SIZE-1:0],
    input logic last_skew  [N_SIZE-1:0],

    // PE results
    output logic signed [ACC_WIDTH-1:0] result [N_SIZE-1:0][N_SIZE-1:0],

    output logic result_valid [N_SIZE-1:0][N_SIZE-1:0]
);
    // INTER-PE DATA CONNECTIONS
    logic signed [DW-1:0] a_link [N_SIZE-1:0][N_SIZE-1:0];
    logic signed [DW-1:0] b_link [N_SIZE-1:0][N_SIZE-1:0];

    // INTER-PE CONTROL CONNECTIONS
    logic valid_link [N_SIZE-1:0][N_SIZE-1:0];
    logic first_link [N_SIZE-1:0][N_SIZE-1:0];
    logic last_link  [N_SIZE-1:0][N_SIZE-1:0];

    // PE INPUT CONNECTIONS
    logic signed [DW-1:0] pe_a_in [N_SIZE-1:0][N_SIZE-1:0];
    logic signed [DW-1:0] pe_b_in [N_SIZE-1:0][N_SIZE-1:0];
    logic pe_valid_in [N_SIZE-1:0][N_SIZE-1:0];
    logic pe_first_in [N_SIZE-1:0][N_SIZE-1:0];
    logic pe_last_in  [N_SIZE-1:0][N_SIZE-1:0];

    // GENERATE N_SIZE x N_SIZE PE ARRAY
    genvar i, j;
    
    generate
        for (i = 0; i < N_SIZE; i = i + 1) begin : PE_ROW
            for (j = 0; j < N_SIZE; j = j + 1) begin : PE_COL
                // A: Horizontal Data Flow
                if (j == 0) begin : A_INPUT
                    assign pe_a_in[i][j] = a_skew[i];
                end
                else begin : A_FORWARD
                    assign pe_a_in[i][j] = a_link[i][j-1];
                end
                // B: Vertical Data Flow
                if (i == 0) begin : B_INPUT
                    assign pe_b_in[i][j] = b_skew[j];
                end
                else begin : B_FORWARD
                    assign pe_b_in[i][j] = b_link[i-1][j];
                end
                
                // CONTROL: Horizontal Propagation
                if (j == 0) begin : CONTROL_INPUT
                    assign pe_valid_in[i][j] = valid_skew[i];
                    assign pe_first_in[i][j] = first_skew[i];
                    assign pe_last_in[i][j]  = last_skew[i];
                end
                else begin : CONTROL_FORWARD
                    assign pe_valid_in[i][j] = valid_link[i][j-1];
                    assign pe_first_in[i][j] = first_link[i][j-1];
                    assign pe_last_in[i][j]  = last_link[i][j-1];
                end
                
                // PE INSTANTIATION
                PE #(
                    .DW(DW),
                    .N_SIZE(N_SIZE),
                    .K_MAX(K_MAX),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .global_enable(global_enable),

                    // Operands
                    .a_in(pe_a_in[i][j]),
                    .b_in(pe_b_in[i][j]),

                    // Control
                    .valid_in(pe_valid_in[i][j]),
                    .first_in(pe_first_in[i][j]),
                    .last_in(pe_last_in[i][j]),

                    // Forwarding
                    .a_out(a_link[i][j]),
                    .b_out(b_link[i][j]),

                    // Results
                    .result(result[i][j]),
                    .result_valid(result_valid[i][j]),

                    // Control forwarding
                    .valid_out(valid_link[i][j]),
                    .first_out(first_link[i][j]),
                    .last_out(last_link[i][j])
                );
            end
        end
    endgenerate
endmodule
