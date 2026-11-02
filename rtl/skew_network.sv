
module skew_network #(
    parameter int DW     = 16,
    parameter int N_SIZE = 5
)(
    input  logic clk,
    input  logic rst_n,
    input  logic global_enable,

    // Input vectors from Input Sequencer
    input  logic signed [DW-1:0] a_in [N_SIZE-1:0],
    input  logic signed [DW-1:0] b_in [N_SIZE-1:0],

    input  logic valid_in,
    input  logic first_in,
    input  logic last_in,

    // Skewed outputs toward PE Array
    output logic signed [DW-1:0] a_out [N_SIZE-1:0],
    output logic signed [DW-1:0] b_out [N_SIZE-1:0],

    output logic valid_out [N_SIZE-1:0],
    output logic first_out [N_SIZE-1:0],
    output logic last_out [N_SIZE-1:0]
);
    
    // 1. A DATA SKEW
    genvar i;

    generate
        for (i = 0; i < N_SIZE; i = i + 1) begin : A_DATA_SKEW
            if (i == 0) begin : NO_DELAY
                assign a_out[i] = a_in[i];
            end
            else begin : DELAY_LINE
                
                logic signed [DW-1:0] a_pipe [i-1:0];
                integer k;

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (k = 0; k < i; k = k + 1)
                            a_pipe[k] <= '0;
                    end
                    else if (global_enable) begin
                        a_pipe[0] <= a_in[i];
                        for (k = 1; k < i; k = k + 1)
                            a_pipe[k] <= a_pipe[k-1];
                    end
                end
                assign a_out[i] = a_pipe[i-1];
            end
        end
    endgenerate
    
    // 2. B DATA SKEW
    genvar j;

    generate
        for (j = 0; j < N_SIZE; j = j + 1) begin : B_DATA_SKEW
            if (j == 0) begin : NO_DELAY
                assign b_out[j] = b_in[j];
            end
            else begin : DELAY_LINE
                
                logic signed [DW-1:0] b_pipe [j-1:0];
                integer k;

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (k = 0; k < j; k = k + 1)
                            b_pipe[k] <= '0;
                    end
                    else if (global_enable) begin
                        b_pipe[0] <= b_in[j];
                        for (k = 1; k < j; k = k + 1)
                            b_pipe[k] <= b_pipe[k-1];
                    end
                end
                assign b_out[j] = b_pipe[j-1];
            end
        end
    endgenerate

    // 3. CONTROL SKEW
    genvar r;
    
    generate
        for (r = 0; r < N_SIZE; r = r + 1) begin : CONTROL_SKEW
            if (r == 0) begin : NO_DELAY
                assign valid_out[r] = valid_in;
                assign first_out[r] = first_in;
                assign last_out[r]  = last_in;
            end
            else begin : DELAY_LINE
                logic valid_pipe [r-1:0];
                logic first_pipe [r-1:0];
                logic last_pipe  [r-1:0];
                
                integer k;
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (k = 0; k < r; k = k + 1) begin
                            valid_pipe[k] <= 1'b0;
                            first_pipe[k] <= 1'b0;
                            last_pipe[k]  <= 1'b0;
                        end
                    end
                    else if (global_enable) begin

                        valid_pipe[0] <= valid_in;
                        first_pipe[0] <= first_in;
                        last_pipe[0]  <= last_in;

                        for (k = 1; k < r; k = k + 1) begin
                            valid_pipe[k] <= valid_pipe[k-1];
                            first_pipe[k] <= first_pipe[k-1];
                            last_pipe[k]  <= last_pipe[k-1];
                        end
                    end
                end
                assign valid_out[r] = valid_pipe[r-1];
                assign first_out[r] = first_pipe[r-1];
                assign last_out[r]  = last_pipe[r-1];
            end
        end
    endgenerate
endmodule
