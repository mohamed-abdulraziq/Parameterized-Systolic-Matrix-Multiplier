module PE #(
    parameter int DW        = 16,
    parameter int N_SIZE    = 5,
    parameter int K_MAX     = N_SIZE,
    parameter int ACC_WIDTH = 2*DW + $clog2(K_MAX)
)(
    input logic clk,
    input logic rst_n, 
  
 // Operand inputs
    input  logic signed [DW-1:0] a_in,
    input  logic signed [DW-1:0] b_in,

    // Control inputs
    input  logic global_enable,
    input  logic valid_in,
    input  logic first_in,
    input  logic last_in,

    // Forwarding outputs
    output logic signed [DW-1:0] a_out,
    output logic signed [DW-1:0] b_out,

    // Result outputs
    output logic signed [ACC_WIDTH-1:0] result,
    output logic result_valid,
    output logic valid_out,
    output logic first_out,
    output logic last_out

);

// Operand registring
logic signed [DW-1:0] a_reg;
logic signed [DW-1:0] b_reg;

// Product registring
logic signed [(2*DW)-1:0] prod_reg;
logic signed [(2*DW)-1:0] prod_comb;

// Control registring
logic valid_reg;
logic first_reg;
logic last_reg;
logic operand_enable;

logic signed [DW-1:0] a_mult;
logic signed [DW-1:0] b_mult;

// Power Saving for Stall && Bubble cases
assign operand_enable = global_enable && valid_in;

assign a_mult = operand_enable ? a_in : '0;
assign b_mult = operand_enable ? b_in : '0;

// Product calc
assign prod_comb = a_mult * b_mult;

// Output Forwarding
assign a_out = a_reg;
assign b_out = b_reg;
assign valid_out = valid_reg;
assign first_out = first_reg;
assign last_out = last_reg;

// PE logic 
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result       <= 'b0;
        a_reg        <= 'b0;
        b_reg        <= 'b0;
        prod_reg     <= 'b0;
        result_valid <= 1'b0;
        valid_reg    <= 1'b0;
        first_reg    <= 1'b0;
        last_reg     <= 1'b0;
    end 
    else begin
        if (global_enable) begin
            // Advance all pipeline stages.
            // When global_enable = 0, all registers hold their state.
            a_reg        <= a_in;
            b_reg        <= b_in;
            prod_reg     <= prod_comb;
            valid_reg    <= valid_in;
            first_reg    <= first_in;
            last_reg     <= last_in;
            result_valid <= 1'b0;
            if (valid_reg) begin
                if (first_reg) begin
                    result <= prod_reg;
                end
                else begin
                    result <= result + prod_reg;
                end
                if (last_reg) begin
                    result_valid <= 1'b1;
                end
            end 
        end
    end
end

endmodule