module output_collector #(
    parameter int DW            = 16,
    parameter int N_SIZE        = 5,
    parameter int K_MAX         = N_SIZE,
    parameter int ACC_WIDTH     = 2*DW + $clog2(K_MAX),
    parameter int ROW_IDX_WIDTH = (N_SIZE <= 1) ? 1 : $clog2(N_SIZE)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic global_enable,

    // PE Array Results
    input  logic signed [ACC_WIDTH-1:0] pe_result [N_SIZE-1:0][N_SIZE-1:0],

    input  logic pe_result_valid [N_SIZE-1:0][N_SIZE-1:0],

    // Row Output
    output logic signed [ACC_WIDTH-1:0] matrix_c_out [N_SIZE-1:0],

    output logic [ROW_IDX_WIDTH-1:0] row_index,
    output logic valid_out,
    output logic matrix_done
);
    // Internal Storage
    logic signed [ACC_WIDTH-1:0] result_buffer [N_SIZE-1:0][N_SIZE-1:0];
    logic [N_SIZE-1:0] row_valid [N_SIZE-1:0];
    logic [N_SIZE-1:0] row_complete;
    logic [ROW_IDX_WIDTH-1:0] read_ptr;
    integer comb_j;
    integer seq_i, seq_j;
    
    // Row Completion Detection
    genvar r;

    generate
        for (r = 0; r < N_SIZE; r = r + 1) begin : ROW_CHECK
            assign row_complete[r] = &row_valid[r];
        end
    endgenerate
    
    // Output Logic
    always_comb begin
        valid_out = 1'b0;
        row_index = read_ptr;
        for (comb_j = 0; comb_j < N_SIZE; comb_j = comb_j + 1)
            matrix_c_out[comb_j] = '0;
        if (row_complete[read_ptr]) begin
            valid_out = 1'b1;
            for (comb_j = 0; comb_j < N_SIZE; comb_j = comb_j + 1)
                matrix_c_out[comb_j] = result_buffer[read_ptr][comb_j];
        end
    end

    // Capture + Output Control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr    <= '0;
            matrix_done <= 1'b0;
            for (seq_i = 0; seq_i < N_SIZE; seq_i = seq_i + 1) begin
                row_valid[seq_i] <= '0;
                for (seq_j = 0; seq_j < N_SIZE; seq_j = seq_j + 1)
                    result_buffer[seq_i][seq_j] <= '0;
            end
        end

        else if (global_enable) begin
            matrix_done <= 1'b0;
            // Release consumed row
            if (valid_out) begin
                row_valid[read_ptr] <= '0;
                if (read_ptr == N_SIZE-1) begin
                    read_ptr    <= '0;
                    matrix_done <= 1'b1;
                end
                else begin
                    read_ptr <= read_ptr + 1'b1;
                end
            end
            // Capture incoming PE results
            for (seq_i = 0; seq_i < N_SIZE; seq_i = seq_i + 1) begin
                for (seq_j = 0; seq_j < N_SIZE; seq_j = seq_j + 1) begin
                    if (pe_result_valid[seq_i][seq_j]) begin
                        result_buffer[seq_i][seq_j] <= pe_result[seq_i][seq_j];
                        row_valid[seq_i][seq_j]      <= 1'b1;
                    end
                end
            end
        end
    end
endmodule
