`timescale 1ns/1ps

module tb_systolic_array_reset_stress #(
    parameter integer DW = 24,
    parameter integer N_SIZE = 1,
    parameter integer K_MAX = 7*N_SIZE,
    parameter integer SEED_ID = 152
)(output reg test_done);

    parameter integer ACC_WIDTH     = 2*DW + $clog2(K_MAX);
    parameter integer ROW_IDX_WIDTH = (N_SIZE <= 1) ? 1 : $clog2(N_SIZE);

    localparam integer NUM_MATRICES = 95;
    localparam integer TOTAL_BEATS  = NUM_MATRICES * K_MAX;

    // ============================================================
    // DUT INTERFACE
    // ============================================================

    reg clk;
    reg rst_n;
    reg global_enable;

    reg signed [DW-1:0] a_in [N_SIZE-1:0];
    reg signed [DW-1:0] b_in [N_SIZE-1:0];

    reg valid_in;
    reg first_in;
    reg last_in;

    wire signed [ACC_WIDTH-1:0] matrix_c_out [N_SIZE-1:0];
    wire [ROW_IDX_WIDTH-1:0] row_index;
    wire valid_out;
    wire matrix_done;

    systolic_array #(
        .DW(DW),
        .N_SIZE(N_SIZE),
        .K_MAX(K_MAX),
        .ACC_WIDTH(ACC_WIDTH),
        .ROW_IDX_WIDTH(ROW_IDX_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .global_enable(global_enable),
        .a_in(a_in),
        .b_in(b_in),
        .valid_in(valid_in),
        .first_in(first_in),
        .last_in(last_in),
        .matrix_c_out(matrix_c_out),
        .row_index(row_index),
        .valid_out(valid_out),
        .matrix_done(matrix_done)
    );

    // ============================================================
    // CLOCK
    // ============================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // TEST STORAGE
    // ============================================================

    reg signed [DW-1:0]
        A [0:NUM_MATRICES-1][0:N_SIZE-1][0:K_MAX-1];

    reg signed [DW-1:0]
        B [0:NUM_MATRICES-1][0:K_MAX-1][0:N_SIZE-1];

    longint signed
        golden [0:NUM_MATRICES-1][0:N_SIZE-1][0:N_SIZE-1];

    integer accepted_beats;
    integer completed_matrices;
    integer completed_rows;
    integer done_pulses;

    integer expected_matrix;
    integer expected_row;

    integer cycle_count;
    integer input_bubbles;
    integer input_errors;
    integer output_errors;

    integer input_stall_cycles;
    integer output_stall_cycles;
    integer global_stall_cycles;

    reg stall_active;
    reg signed [DW-1:0] held_a [N_SIZE-1:0];
    reg signed [DW-1:0] held_b [N_SIZE-1:0];
    reg held_valid;
    reg held_first;
    reg held_last;

    reg output_stall_active;
    reg held_output_valid;
    reg [ROW_IDX_WIDTH-1:0] held_row_index;
    reg signed [ACC_WIDTH-1:0] held_matrix_c [N_SIZE-1:0];

    integer last_input_cycle;
    integer current_matrix;
    integer current_beat;

    reg send_active;
    reg expected_done;
    reg expected_done_next;

    integer i, j, k, m;
    integer drain_cycle;
    integer seed_state;
    integer seed_dummy;

    // ============================================================
    // ERROR REPORTING
    // ============================================================

    task automatic fail(input string message);
        begin
            output_errors = output_errors + 1;
            $display("[%0t] ERROR: %s", $time, message);

            if (output_errors >= 20)
                $fatal(1, "Too many errors");
        end
    endtask

    // ============================================================
    // MATRIX GENERATION
    //
    // Pattern 0: Zero matrices
    // Pattern 1: Identity matrices
    // Pattern 2: Signed MIN/MAX
    // Pattern 3: Alternating signs
    // Pattern 4: MIN * MIN
    // Pattern 5: MAX * MAX
    // Pattern 6: Full-range random values
    // ============================================================

    task automatic generate_all_matrices;

        integer r;
        integer c;
        integer t;

        integer signed temp_a;
        integer signed temp_b;

        integer signed min_value;
        integer signed max_value;

        begin

            min_value = -(1 << (DW-1));
            max_value =  (1 << (DW-1))-1;

            for (m = 0; m < NUM_MATRICES; m = m + 1) begin

                for (r = 0; r < N_SIZE; r = r + 1) begin

                    for (t = 0; t < K_MAX; t = t + 1) begin

                        case (m % 7)

                            0: begin
                                temp_a = 0;
                                temp_b = 0;
                            end

                            1: begin
                                temp_a = (r == t) ? 1 : 0;
                                temp_b = (t == r) ? 1 : 0;
                            end

                            2: begin
                                temp_a = ((r+t) % 2 == 0) ?
                                         min_value : max_value;

                                temp_b = ((r+t) % 2 == 0) ?
                                         max_value : min_value;
                            end

                            3: begin
                                temp_a = ((r+t) % 2 == 0) ? -1 : 1;
                                temp_b = ((r+t) % 2 == 0) ? 1 : -1;
                            end

                            4: begin
                                temp_a = min_value;
                                temp_b = min_value;
                            end

                            5: begin
                                temp_a = max_value;
                                temp_b = max_value;
                            end

                            default: begin
                                temp_a = $urandom;
                                temp_b = $urandom;
                            end

                        endcase

                        A[m][r][t] = temp_a;
                        B[m][t][r] = temp_b;

                    end
                end

            end

        end
    endtask

    // ============================================================
    // GOLDEN MODEL
    //
    // C[i][j] = SUM(A[i][k] * B[k][j])
    // ============================================================

    task automatic calculate_all_golden;

        integer matrix_id;
        integer r;
        integer c;
        integer t;

        longint signed accumulator;

        begin

            for (matrix_id = 0;
                 matrix_id < NUM_MATRICES;
                 matrix_id = matrix_id + 1) begin

                for (r = 0; r < N_SIZE; r = r + 1) begin

                    for (c = 0; c < N_SIZE; c = c + 1) begin

                        accumulator = 0;

                        for (t = 0; t < K_MAX; t = t + 1) begin

                            accumulator = accumulator +
                                longint'(A[matrix_id][r][t]) *
                                longint'(B[matrix_id][t][c]);

                        end

                        golden[matrix_id][r][c] = accumulator;

                        if (ACC_WIDTH < 64) begin
                            if (accumulator >= (64'sd1 <<< (ACC_WIDTH-1)) ||
                                accumulator < -(64'sd1 <<< (ACC_WIDTH-1)))
                                $fatal(1,
                                    "Golden overflow matrix=%0d row=%0d col=%0d",
                                    matrix_id, r, c);
                        end

                    end
                end
            end

        end
    endtask

    // ============================================================
    // INPUT CONTROL
    // ============================================================

    task automatic clear_inputs;

        integer index;

        begin

            valid_in = 0;
            first_in = 0;
            last_in  = 0;

            for (index = 0; index < N_SIZE; index = index + 1) begin
                a_in[index] = '0;
                b_in[index] = '0;
            end

        end
    endtask

    // ============================================================
    // BACK-TO-BACK DRIVER
    //
    // No idle cycles between beats.
    // No idle cycles between matrices.
    // No waiting for matrix_done between matrices.
    //
    // Every rising edge during the stream has valid_in=1.
    // ============================================================

    task automatic send_all_matrices;

        integer matrix_id;
        integer beat;
        integer index;
        integer beat_accepted;

        begin

            global_enable = 1;

            $display("");
            $display("==================================================");
            $display("START BACK-TO-BACK STREAM WITH RANDOM GLOBAL STALLS");
            $display("Matrices = %0d", NUM_MATRICES);
            $display("Beats per matrix = %0d", K_MAX);
            $display("Total input beats = %0d", TOTAL_BEATS);
            $display("Random input global stall probability = 25%%");
            $display("Output drain uses guaranteed 2-cycle stalls / 2-cycle runs");
            $display("==================================================");

            for (matrix_id = 0;
                 matrix_id < NUM_MATRICES;
                 matrix_id = matrix_id + 1) begin

                for (beat = 0; beat < K_MAX; beat = beat + 1) begin

                    // Present a new beat only after the previous beat
                    // has been accepted on an enabled rising edge.
                    @(negedge clk);

                    for (index = 0; index < N_SIZE; index = index + 1) begin
                        a_in[index] = A[matrix_id][index][beat];
                        b_in[index] = B[matrix_id][beat][index];
                    end

                    valid_in = 1;
                    first_in = (beat == 0);
                    last_in  = (beat == K_MAX-1);

                    if ((matrix_id == 0) && (beat == 0))
                        send_active = 1;

                    beat_accepted = 0;

                    // During a stall, keep this exact beat and its flags
                    // unchanged. Advance only after global_enable is high
                    // at a rising edge.
                    while (beat_accepted == 0) begin

                        global_enable = ($urandom_range(0,3) != 0);

                        @(posedge clk);

                        if (global_enable === 1'b1) begin
                            #1;
                            beat_accepted = 1;
                        end
                        else begin
                            // Change global_enable only on a falling edge.
                            @(negedge clk);
                        end

                    end

                end

                $display(
                    "[%0t] Matrix %0d input completed",
                    $time, matrix_id
                );

            end

            // Stop presenting input only after the final beat was accepted.
            @(negedge clk);

            clear_inputs;
            send_active = 0;
            global_enable = 1;

            $display("");
            $display("ALL INPUT MATRICES SUBMITTED");

        end

    endtask

    // ============================================================
    // INPUT STREAM MONITOR
    //
    // Checks:
    // 1. No invalid cycle during the stream.
    // 2. Correct first/last markers.
    // 3. Correct consecutive input acceptance.
    // ============================================================

    always @(posedge clk) begin : input_monitor

        integer expected_beat;
        integer index;

        if (!rst_n) begin
            stall_active = 0;
        end
        else begin

            if (global_enable === 1'b0) begin

                global_stall_cycles = global_stall_cycles + 1;

                // Check that the collector's externally visible output
                // remains frozen for the entire global stall.
                if (!output_stall_active) begin
                    held_output_valid = valid_out;
                    held_row_index = row_index;
                    for (index = 0; index < N_SIZE; index = index + 1)
                        held_matrix_c[index] = matrix_c_out[index];
                    output_stall_active = 1;
                end
                else begin
                    if (valid_out !== held_output_valid ||
                        row_index !== held_row_index) begin
                        output_errors = output_errors + 1;
                        $display("[%0t] ERROR: Output control changed during global stall",
                                 $time);
                    end

                    for (index = 0; index < N_SIZE; index = index + 1) begin
                        if (matrix_c_out[index] !== held_matrix_c[index]) begin
                            output_errors = output_errors + 1;
                            $display("[%0t] ERROR: Output data changed during global stall",
                                     $time);
                        end
                    end
                end

            end
            else begin
                output_stall_active = 0;
            end

            if (send_active) begin

                if (global_enable === 1'b0) begin

                    input_stall_cycles = input_stall_cycles + 1;

                    // A valid beat must remain presented while the
                    // complete datapath is frozen.
                    if (valid_in !== 1'b1) begin
                        input_errors = input_errors + 1;
                        $display("[%0t] ERROR: valid_in dropped during global stall",
                                 $time);
                    end

                    if (!stall_active) begin
                        for (index = 0; index < N_SIZE; index = index + 1) begin
                            held_a[index] = a_in[index];
                            held_b[index] = b_in[index];
                        end
                        held_valid = valid_in;
                        held_first = first_in;
                        held_last  = last_in;
                        stall_active = 1;
                    end
                    else begin
                        for (index = 0; index < N_SIZE; index = index + 1) begin
                            if (a_in[index] !== held_a[index] ||
                                b_in[index] !== held_b[index]) begin
                                input_errors = input_errors + 1;
                                $display("[%0t] ERROR: Input data changed during global stall",
                                         $time);
                            end
                        end

                        if (valid_in !== held_valid ||
                            first_in !== held_first ||
                            last_in  !== held_last) begin
                            input_errors = input_errors + 1;
                            $display("[%0t] ERROR: Input control changed during global stall",
                                     $time);
                        end
                    end

                end
                else if (global_enable === 1'b1) begin

                    cycle_count = cycle_count + 1;

                    if (stall_active) begin
                        // The held beat is accepted now; the driver may
                        // present the next beat only on the following negedge.
                        stall_active = 0;
                    end

                    if (valid_in !== 1'b1) begin

                        input_bubbles = input_bubbles + 1;

                        $display(
                            "[%0t] ERROR: Input bubble on enabled stream cycle",
                            $time
                        );

                    end
                    else begin

                        expected_beat = accepted_beats % K_MAX;

                        if (first_in !== (expected_beat == 0))
                            input_errors = input_errors + 1;

                        if (last_in !== (expected_beat == K_MAX-1))
                            input_errors = input_errors + 1;

                        if (accepted_beats > 0) begin
                            if ((cycle_count - last_input_cycle) != 1) begin
                                input_errors = input_errors + 1;
                                $display(
                                    "[%0t] ERROR: Non-consecutive enabled input beats",
                                    $time
                                );
                            end
                        end

                        accepted_beats = accepted_beats + 1;
                        last_input_cycle = cycle_count;

                    end

                end

            end
            else if ((send_active === 1'b0) &&
                     (completed_matrices < NUM_MATRICES) &&
                     (global_enable === 1'b0)) begin
                output_stall_cycles = output_stall_cycles + 1;
            end

        end

    end

    // ============================================================
    // OUTPUT SCOREBOARD
    //
    // Output rows are checked in matrix order.
    // Outputs may arrive while input matrices are still streaming.
    // ============================================================

    always @(posedge clk) begin : output_scoreboard

        integer column;

        if (!rst_n) begin

            expected_matrix = 0;
            expected_row = 0;
            expected_done = 0;

            #1;

            if (valid_out !== 0 ||
                matrix_done !== 0 ||
                row_index !== '0)
                fail("Reset output check failed");

        end
        else begin

            // If disabled, all output-side state must hold, including
            // matrix_done. If enabled, predict the next completion state.
            expected_done_next = expected_done;

            if (global_enable) begin

                expected_done_next = 0;

                if (valid_out) begin

                    if (expected_matrix >= NUM_MATRICES) begin
                        fail("Unexpected output after all matrices");
                    end
                    else begin

                        if (row_index !== expected_row[ROW_IDX_WIDTH-1:0]) begin
                            fail($sformatf(
                                "Matrix %0d: row index got=%0d expected=%0d",
                                expected_matrix, row_index, expected_row
                            ));
                        end

                        for (column = 0;
                             column < N_SIZE;
                             column = column + 1) begin

                            if (longint'(matrix_c_out[column]) !==
                                golden[expected_matrix][expected_row][column]) begin

                                fail($sformatf(
                                    "Matrix %0d Row %0d Col %0d: DUT=%0d GOLDEN=%0d",
                                    expected_matrix,
                                    expected_row,
                                    column,
                                    matrix_c_out[column],
                                    golden[expected_matrix][expected_row][column]
                                ));

                            end

                        end

                        completed_rows = completed_rows + 1;

                        if (expected_row == N_SIZE-1) begin

                            expected_row = 0;
                            expected_done_next = 1;

                            $display(
                                "[%0t] PASS: Matrix %0d output verified",
                                $time, expected_matrix
                            );

                            expected_matrix = expected_matrix + 1;
                            completed_matrices = completed_matrices + 1;

                        end
                        else begin
                            expected_row = expected_row + 1;
                        end

                    end

                end
                else begin

                    for (column = 0;
                         column < N_SIZE;
                         column = column + 1) begin

                        if (matrix_c_out[column] !== '0)
                            fail($sformatf(
                                "Invalid output data[%0d] is not zero",
                                column
                            ));

                    end

                end

            end

            #1;

            if (matrix_done !== expected_done_next)
                fail($sformatf(
                    "matrix_done DUT=%b expected=%b global_enable=%b",
                    matrix_done, expected_done_next, global_enable
                ));

            // Count the assertion event once. A stall may hold matrix_done
            // high for several clocks but must not create extra pulses.
            if (expected_done_next && !expected_done)
                done_pulses = done_pulses + 1;

            expected_done = expected_done_next;

        end

    end

    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        test_done = 0;
        seed_state = SEED_ID;
        seed_dummy = $urandom(seed_state);
        rst_n = 0;
        global_enable = 1;

        clear_inputs;

        send_active = 0;

        accepted_beats = 0;
        completed_matrices = 0;
        completed_rows = 0;
        done_pulses = 0;

        expected_matrix = 0;
        expected_row = 0;

        cycle_count = 0;
        input_bubbles = 0;
        input_errors = 0;
        output_errors = 0;

        input_stall_cycles = 0;
        output_stall_cycles = 0;
        global_stall_cycles = 0;

        stall_active = 0;
        output_stall_active = 0;
        held_output_valid = 0;
        held_row_index = '0;
        held_valid = 0;
        held_first = 0;
        held_last = 0;

        last_input_cycle = -1;

        expected_done = 0;
        expected_done_next = 0;

        if (N_SIZE < 1 || K_MAX < 1)
            $fatal(1, "Invalid parameters");

        if (ACC_WIDTH < 2*DW + $clog2(K_MAX))
            $fatal(1, "ACC_WIDTH too small");

        $display("");
        $display("==================================================");
        $display("SYSTOLIC ARRAY BACK-TO-BACK TEST");
        $display("DW=%0d N_SIZE=%0d K_MAX=%0d ACC_WIDTH=%0d",
                 DW, N_SIZE, K_MAX, ACC_WIDTH);
        $display("Matrices=%0d", NUM_MATRICES);
        $display("==================================================");

        // Generate all matrices and golden results before streaming.
        generate_all_matrices;
        calculate_all_golden;

        // Reset.
        repeat (4) @(negedge clk);
        rst_n = 1;

        repeat (2) @(negedge clk);

        // Send all matrices back-to-back in accepted-beat order.
        // Random global stalls hold the current beat until acceptance.
        send_all_matrices;

        // Drain the output with GUARANTEED global stalls.
        // Two disabled cycles followed by two enabled cycles.
        // This ensures output-side freeze behavior is actually exercised.
        drain_cycle = 0;

        while (completed_matrices < NUM_MATRICES) begin
            @(negedge clk);

            if ((drain_cycle % 4) < 2)
                global_enable = 1'b0;
            else
                global_enable = 1'b1;

            drain_cycle = drain_cycle + 1;
        end

        // Resume the datapath and allow any held completion pulse to retire.
        @(negedge clk);
        global_enable = 1'b1;

        @(posedge clk);
        #2;

        // ========================================================
        // FINAL CHECKS
        // ========================================================

        $display("");
        $display("==================================================");
        $display("BACK-TO-BACK TEST RESULTS");
        $display("==================================================");

        $display("Accepted beats      = %0d", accepted_beats);
        $display("Expected beats      = %0d", TOTAL_BEATS);

        $display("Input bubbles       = %0d", input_bubbles);
        $display("Input errors        = %0d", input_errors);
        $display("Input stall cycles  = %0d", input_stall_cycles);
        $display("Output stall cycles = %0d", output_stall_cycles);
        $display("Global stall cycles = %0d", global_stall_cycles);

        $display("Completed matrices  = %0d", completed_matrices);
        $display("Expected matrices   = %0d", NUM_MATRICES);

        $display("Completed rows      = %0d", completed_rows);
        $display("Expected rows       = %0d", NUM_MATRICES*N_SIZE);

        $display("matrix_done pulses  = %0d", done_pulses);
        $display("Expected done pulses= %0d", NUM_MATRICES);

        $display("Output errors       = %0d", output_errors);

        $display("==================================================");

        if (accepted_beats != TOTAL_BEATS)
            input_errors = input_errors + 1;

        if (input_bubbles != 0)
            input_errors = input_errors + 1;

        if (input_stall_cycles == 0)
            input_errors = input_errors + 1;

        if (output_stall_cycles == 0)
            input_errors = input_errors + 1;

        if (input_errors != 0)
            $fatal(1, "Input stream test FAILED");

        if (completed_matrices != NUM_MATRICES)
            $fatal(1, "Not all matrices completed");

        if (completed_rows != NUM_MATRICES*N_SIZE)
            $fatal(1, "Output row count mismatch");

        if (done_pulses != NUM_MATRICES)
            $fatal(1, "matrix_done pulse count mismatch");

        if (output_errors != 0)
            $fatal(1, "Output scoreboard FAILED");

        $display("");
        $display("PASS: BACK-TO-BACK STREAMING WITH RANDOM GLOBAL STALLS");
        $display("No accepted-beat bubbles or input/output changes during stalls.");
        $display("All matrix outputs matched the golden model.");

        test_done = 1;

    end

    // ============================================================
    // TIMEOUT
    // ============================================================

    initial begin
        #20000000;
        $fatal(1, "BACK-TO-BACK TEST TIMEOUT");
    end

endmodule


`timescale 1ns/1ps

module systolic_reset_test #(
    parameter integer DW = 16,
    parameter integer N_SIZE = 5,
    parameter integer K_MAX = 5
)(output reg test_done);

    parameter integer ACC_WIDTH     = 2*DW + $clog2(K_MAX);
    parameter integer ROW_IDX_WIDTH = (N_SIZE <= 1) ? 1 : $clog2(N_SIZE);

    localparam integer RESET_CASES = 4;

    reg clk;
    reg rst_n;
    reg global_enable;

    reg signed [DW-1:0] a_in [N_SIZE-1:0];
    reg signed [DW-1:0] b_in [N_SIZE-1:0];

    reg valid_in;
    reg first_in;
    reg last_in;

    wire signed [ACC_WIDTH-1:0] matrix_c_out [N_SIZE-1:0];
    wire [ROW_IDX_WIDTH-1:0] row_index;
    wire valid_out;
    wire matrix_done;

    systolic_array #(
        .DW(DW),
        .N_SIZE(N_SIZE),
        .K_MAX(K_MAX),
        .ACC_WIDTH(ACC_WIDTH),
        .ROW_IDX_WIDTH(ROW_IDX_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .global_enable(global_enable),
        .a_in(a_in),
        .b_in(b_in),
        .valid_in(valid_in),
        .first_in(first_in),
        .last_in(last_in),
        .matrix_c_out(matrix_c_out),
        .row_index(row_index),
        .valid_out(valid_out),
        .matrix_done(matrix_done)
    );

    integer errors;
    integer reset_count;
    integer recovery_matrices;
    integer rows_checked;
    integer invalid_flag_cycles;

    integer i, j, k;
    integer signed temp;
    longint signed golden [N_SIZE-1:0][N_SIZE-1:0];
    reg signed [DW-1:0] test_a [N_SIZE-1:0][K_MAX-1:0];
    reg signed [DW-1:0] test_b [K_MAX-1:0][N_SIZE-1:0];

    initial begin
        test_done = 0;
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic clear_inputs;
        integer x;
        begin
            valid_in = 1'b0;
            first_in = 1'b0;
            last_in  = 1'b0;
            for (x = 0; x < N_SIZE; x = x + 1) begin
                a_in[x] = '0;
                b_in[x] = '0;
            end
        end
    endtask

    task automatic fail(input string msg);
        begin
            errors = errors + 1;
            $display("[%0t] ERROR: %s", $time, msg);
        end
    endtask

    task automatic build_test_matrix(input integer seed_id);
        integer r, c, t;
        longint signed acc;
        integer signed va, vb;
        begin
            for (r = 0; r < N_SIZE; r = r + 1) begin
                for (t = 0; t < K_MAX; t = t + 1) begin
                    va = ((r*17 + t*11 + seed_id*7) % 31) - 15;
                    vb = ((t*13 + r*5 + seed_id*3) % 29) - 14;
                    test_a[r][t] = va;
                    test_b[t][r] = vb;
                end
            end

            for (r = 0; r < N_SIZE; r = r + 1) begin
                for (c = 0; c < N_SIZE; c = c + 1) begin
                    acc = 0;
                    for (t = 0; t < K_MAX; t = t + 1)
                        acc = acc +
                              longint'(test_a[r][t]) *
                              longint'(test_b[t][c]);
                    golden[r][c] = acc;
                end
            end
        end
    endtask

    task automatic apply_reset;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            global_enable = 1'b1;
            clear_inputs;
            #1;

            if (valid_out !== 1'b0)
                fail("valid_out did not clear on reset");
            if (matrix_done !== 1'b0)
                fail("matrix_done did not clear on reset");
            if (row_index !== '0)
                fail("row_index did not reset to zero");

            repeat (3) @(negedge clk);
            rst_n = 1'b1;
            reset_count = reset_count + 1;

            // Allow reset release and check that no stale output reappears.
            repeat (2) begin
                @(posedge clk);
                #1;
                if (valid_out !== 1'b0 || matrix_done !== 1'b0)
                    fail("Stale output appeared after reset release");
            end
        end
    endtask

    task automatic send_one_matrix;
        integer beat, x;
        begin
            for (beat = 0; beat < K_MAX; beat = beat + 1) begin
                @(negedge clk);
                global_enable = 1'b1;
                valid_in = 1'b1;
                first_in = (beat == 0);
                last_in  = (beat == K_MAX-1);

                for (x = 0; x < N_SIZE; x = x + 1) begin
                    a_in[x] = test_a[x][beat];
                    b_in[x] = test_b[beat][x];
                end

                @(posedge clk);
                #1;
            end

            @(negedge clk);
            clear_inputs;
        end
    endtask

    task automatic send_invalid_garbage;
        integer n, x;
        begin
            for (n = 0; n < 3; n = n + 1) begin
                @(negedge clk);
                global_enable = 1'b1;
                valid_in = 1'b0;
                first_in = (n != 1);
                last_in  = (n == 1);
                for (x = 0; x < N_SIZE; x = x + 1) begin
                    a_in[x] = {DW{1'b1}};
                    b_in[x] = {DW{1'b0}} ^ (n + x);
                end
                invalid_flag_cycles = invalid_flag_cycles + 1;
                @(posedge clk);
                #1;
            end
            @(negedge clk);
            clear_inputs;
        end
    endtask

    task automatic check_recovery_matrix(input integer seed_id);
        integer expected_row;
        integer c;
        integer timeout_count;
        reg row_seen;
        begin
            build_test_matrix(seed_id);
            send_invalid_garbage;
            send_one_matrix;

            expected_row = 0;
            timeout_count = 0;

            while (expected_row < N_SIZE && timeout_count < 5000) begin
                // Check the current phase first: the final input beat may
                // make row 0 valid before this task is entered.
                if (!(global_enable && valid_out)) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (global_enable && valid_out) begin
                    row_seen = 1'b1;

                    if (row_index !== expected_row[ROW_IDX_WIDTH-1:0])
                        fail($sformatf("Recovery matrix %0d: row index got %0d expected %0d",
                                       seed_id, row_index, expected_row));

                    for (c = 0; c < N_SIZE; c = c + 1) begin
                        if (longint'(matrix_c_out[c]) !== golden[expected_row][c])
                            fail($sformatf("Recovery matrix %0d row %0d col %0d mismatch: DUT=%0d GOLDEN=%0d",
                                           seed_id, expected_row, c,
                                           matrix_c_out[c], golden[expected_row][c]));
                    end

                    @(posedge clk);
                    #1;
                    rows_checked = rows_checked + 1;

                    if (expected_row == N_SIZE-1) begin
                        if (matrix_done !== 1'b1)
                            fail("matrix_done missing after final recovery row");
                    end
                    else begin
                        if (matrix_done !== 1'b0)
                            fail("matrix_done asserted before final recovery row");
                    end

                    expected_row = expected_row + 1;
                end
            end

            if (expected_row != N_SIZE)
                fail($sformatf("Timeout waiting for recovery matrix %0d outputs", seed_id));
            else begin
                recovery_matrices = recovery_matrices + 1;
                $display("[%0t] PASS: Recovery matrix %0d verified",
                         $time, seed_id);
            end

            @(negedge clk);
            global_enable = 1'b1;
            @(posedge clk);
            #1;
            if (matrix_done !== 1'b0)
                fail("matrix_done did not return low after completion");
        end
    endtask

    task automatic wait_for_valid_output(input integer max_cycles);
        integer count;
        begin
            count = 0;
            while (valid_out !== 1'b1 && count < max_cycles) begin
                @(negedge clk);
                count = count + 1;
            end
            if (valid_out !== 1'b1)
                fail("Timed out waiting for pending collector output");
        end
    endtask

    task automatic consume_rows_without_check(input integer target_rows);
        integer consumed;
        integer count;
        begin
            consumed = 0;
            count = 0;
            while (consumed < target_rows && count < 5000) begin
                if (global_enable && valid_out) begin
                    @(posedge clk);
                    #1;
                    consumed = consumed + 1;
                end
                else begin
                    @(negedge clk);
                    count = count + 1;
                end
            end
            if (consumed != target_rows)
                fail("Timed out while consuming partial output rows");
        end
    endtask

    initial begin
        rst_n = 1'b0;
        global_enable = 1'b1;
        clear_inputs;

        errors = 0;
        reset_count = 0;
        recovery_matrices = 0;
        rows_checked = 0;
        invalid_flag_cycles = 0;

        if (N_SIZE < 1 || K_MAX < 1)
            $fatal(1, "Invalid parameters");
        if (ACC_WIDTH < 2*DW + $clog2(K_MAX))
            $fatal(1, "ACC_WIDTH too small");

        $display("");
        $display("==================================================");
        $display("SYSTOLIC ARRAY RESET STRESS + CONTROL FLAG TEST");
        $display("DW=%0d N_SIZE=%0d K_MAX=%0d ACC_WIDTH=%0d",
                 DW, N_SIZE, K_MAX, ACC_WIDTH);
        $display("==================================================");

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        // TEST 1: Reset during a partially received input matrix.
        $display("TEST 1: Reset during partial input");
        build_test_matrix(1);
        for (i = 0; i < 2; i = i + 1) begin
            @(negedge clk);
            valid_in = 1'b1;
            first_in = (i == 0);
            last_in = 1'b0;
            for (j = 0; j < N_SIZE; j = j + 1) begin
                a_in[j] = test_a[j][i];
                b_in[j] = test_b[i][j];
            end
            @(posedge clk);
            #1;
        end
        apply_reset;
        check_recovery_matrix(11);

        // TEST 2: Reset while data is still moving through the PE pipeline.
        $display("TEST 2: Reset during active pipeline");
        build_test_matrix(2);
        send_one_matrix;
        repeat (2) @(posedge clk);
        apply_reset;
        check_recovery_matrix(22);

        // TEST 3: Reset while a completed row is pending in the collector.
        $display("TEST 3: Reset with pending output row");
        build_test_matrix(3);
        send_one_matrix;
        wait_for_valid_output(5000);
        // wait_for_valid_output returns at the negedge where valid_out is seen.
        // Freeze immediately so the pending row cannot be consumed.
        global_enable = 1'b0;
        @(posedge clk); // one frozen edge with valid_out pending
        #1;
        if (valid_out !== 1'b1)
            fail("Pending valid_out was not held during global stall");
        apply_reset;
        check_recovery_matrix(33);

        // TEST 4: Reset after some rows have already been emitted.
        $display("TEST 4: Reset during partial output consumption");
        build_test_matrix(4);
        send_one_matrix;
        consume_rows_without_check(2);
        @(negedge clk);
        global_enable = 1'b0;
        @(posedge clk);
        #1;
        apply_reset;
        check_recovery_matrix(44);

        // TEST 5: Invalid cycles with arbitrary first/last flags must be ignored.
        $display("TEST 5: Invalid input with garbage control flags");
        build_test_matrix(5);
        check_recovery_matrix(55);

        $display("");
        $display("==================================================");
        $display("RESET STRESS TEST RESULTS");
        $display("==================================================");
        $display("Reset events                 = %0d", reset_count);
        $display("Recovery matrices verified   = %0d", recovery_matrices);
        $display("Expected recovery matrices   = 5");
        $display("Verified output rows         = %0d", rows_checked);
        $display("Expected output rows         = %0d", 5*N_SIZE);
        $display("Invalid garbage cycles       = %0d", invalid_flag_cycles);
        $display("Errors                       = %0d", errors);
        $display("==================================================");

        if (reset_count != 4)
            $fatal(1, "Reset event count mismatch");
        if (recovery_matrices != 5)
            $fatal(1, "Recovery matrix count mismatch");
        if (rows_checked != 5*N_SIZE)
            $fatal(1, "Recovery row count mismatch");
        if (errors != 0)
            $fatal(1, "RESET STRESS TEST FAILED");

        $display("PASS: RESET STRESS + CONTROL FLAG TEST");
        $display("No stale outputs after reset; recovery matrices verified.");
        test_done = 1;
    end

    initial begin
        #20000000;
        $fatal(1, "RESET STRESS TEST TIMEOUT");
    end

endmodule



// ================================================================
// Final regression top
// Run all parameter configurations and reset stress in one simulation.
// ================================================================
module tb_systolic_array_final;

    wire done_1, done_2, done_3, done_4, done_reset;

    // Smallest supported array and data width.
    systolic_b2b_test #(
        .DW(8), .N_SIZE(1), .K_MAX(1), .SEED_ID(101)
    ) cfg_1 (done_1);

    // Small array with K_MAX larger than N_SIZE.
    systolic_b2b_test #(
        .DW(8), .N_SIZE(2), .K_MAX(3), .SEED_ID(202)
    ) cfg_2 (done_2);

    // Main project configuration.
    systolic_b2b_test #(
        .DW(16), .N_SIZE(5), .K_MAX(5), .SEED_ID(303)
    ) cfg_3 (done_3);

    // Larger array and extended accumulation length.
    systolic_b2b_test #(
        .DW(16), .N_SIZE(7), .K_MAX(28), .SEED_ID(404)
    ) cfg_4 (done_4);

    // Reset and invalid-control recovery test.
    systolic_reset_test #(
        .DW(16), .N_SIZE(7), .K_MAX(28)
    ) reset_cases (done_reset);

    initial begin
        wait (done_1 && done_2 && done_3 && done_4 && done_reset);
        $display("");
        $display("==================================================");
        $display("FINAL SYSTOLIC ARRAY REGRESSION: ALL TESTS PASSED");
        $display("Parameter configurations : 4");
        $display("Random seeds             : 101, 202, 303, 404");
        $display("Reset stress             : PASS");
        $display("==================================================");
        $stop;
    end

    initial begin
        #30000000;
        $fatal(1, "FINAL REGRESSION TIMEOUT");
    end

endmodule
