# Architecture and Dataflow

## 1. Matrix operation

The accelerator computes the square matrix product C = A × B.

For every output element:

C[i,j] = sum over k=0…K-1 of A[i,k] × B[k,j]

The hardware uses an N_SIZE × N_SIZE array. Each PE at location (i,j) owns one C[i,j] value and accumulates its dot product locally.

## 2. Top-level organization

~~~mermaid
flowchart TD
    AV["A input vector<br/>a_in[N_SIZE]"]
    BV["B input vector<br/>b_in[N_SIZE]"]
    CTRL["valid_in / first_in / last_in"]
    SK["skew_network"]
    PA["PE_array<br/>N_SIZE × N_SIZE"]
    OC["output_collector<br/>N_SIZE × N_SIZE buffer"]
    ROW["matrix_c_out[N_SIZE]<br/>row_index / valid_out"]
    MD["matrix_done"]
    EN["global_enable"]

    AV --> SK
    BV --> SK
    CTRL --> SK
    SK -->|"A_i skewed by row i"| PA
    SK -->|"B_j skewed by column j"| PA
    PA -->|"PE result + result_valid"| OC
    OC --> ROW
    OC --> MD
    EN -.-> SK
    EN -.-> PA
    EN -.-> OC
~~~

The top module systolic_array is structural integration. It instantiates the skew network, PE array, and output collector. It does not implement a command controller, matrix scheduler, input-ready protocol, or internal transaction sequencer. The external source controls the input stream and enable signal.

## 3. Output-stationary processing element

~~~mermaid
flowchart LR
    AI["a_in"] --> MUL["Signed multiplier"]
    BI["b_in"] --> MUL
    MUL --> PR["Registered product"]
    PR --> ADD["Accumulator update"]
    ACC["Accumulator register"] --> ADD
    ADD --> ACC
    AI --> AR["A operand register"]
    BI --> BR["B operand register"]
    AR --> AF["a_out forwarding"]
    BR --> BF["b_out forwarding"]
    V["valid / first / last"] --> PIPE["Control pipeline"]
    PIPE --> ADD
    PIPE --> RV["result_valid"]
~~~

Each PE is responsible for one C[i,j] value. The RTL pipeline contains registered operand forwarding, a combinational signed multiplier feeding a registered product, and a registered accumulator. The product/control pipeline is aligned so that the accumulator consumes only a valid registered product.

Control semantics:

- **valid_in=1:** the input product participates in the PE pipeline.
- **first_in=1:** the corresponding product initializes the accumulator instead of adding to the previous dot-product value.
- **last_in=1:** marks the final product in the dot product; the PE asserts result_valid when that accumulation is committed.
- **valid_in=0:** data and first/last values are not treated as a valid arithmetic transaction.
- **global_enable=0:** sequential state is held, including operand/product/control pipeline registers, accumulator state, and result_valid.

Each PE forwards A to its right neighbor and B to its lower neighbor using registered operands. Partial sums are not forwarded: they remain stationary in the PE.

## 4. Operand and control skew

The systolic wavefront requires operands for the same reduction index k to arrive at PE (i,j) together.

- A row i input is delayed by i enabled cycles.
- B column j input is delayed by j enabled cycles.
- valid, first, and last control signals are delayed to maintain alignment with the associated operand stream.
- Skew registers advance only when global_enable=1 and are asynchronously reset by active-low rst_n.

~~~mermaid
flowchart LR
    A0["A row 0"] -->|"0-cycle skew"| R0["PE row 0"]
    A1["A row 1"] -->|"1 enabled cycle"| R1["PE row 1"]
    A2["A row 2"] -->|"2 enabled cycles"| R2["PE row 2"]
    B0["B col 0"] -->|"0-cycle skew"| C0["PE col 0"]
    B1["B col 1"] -->|"1 enabled cycle"| C1["PE col 1"]
    B2["B col 2"] -->|"2 enabled cycles"| C2["PE col 2"]
~~~

The skew is measured in enabled clock advances, not wall-clock cycles. When the global enable is low, the whole wavefront pauses without losing operand/control alignment.

## 5. PE array interconnect

PE_array instantiates N_SIZE² PEs using nested generate loops.

- The leftmost PE in each row receives the corresponding skewed A value.
- The top PE in each column receives the corresponding skewed B value.
- A moves horizontally through the row.
- B moves vertically through the column.
- Control markers propagate horizontally with A through each row.
- Each PE exposes its local accumulated result and result-valid indication to the collector.

## 6. Output collector

The collector contains:

- An N_SIZE × N_SIZE result buffer.
- One N_SIZE-bit validity bitmap per output row.
- A row-completion vector formed by AND-reducing each row's validity bits.
- A read pointer that emits completed rows in increasing row-index order.

A row becomes available when all PEs in that row have asserted result-valid and the collector has captured their results. While the current row is valid, matrix_c_out presents all N_SIZE elements and row_index identifies the row. On an enabled cycle with valid_out=1, the row-valid bitmap is cleared and the read pointer advances. After the final row is consumed, the pointer wraps and matrix_done pulses.

There is no separate ready input. The consumer uses global_enable to pause the complete design when it needs to hold the output row.

## 7. Top-level interface

| Signal | Direction | Description |
|---|---|---|
| clk | Input | Common clock |
| rst_n | Input | Asynchronous active-low reset |
| global_enable | Input | Advances or freezes the complete datapath |
| a_in[N_SIZE] | Input | Signed row operand vector |
| b_in[N_SIZE] | Input | Signed column operand vector |
| valid_in | Input | Marks an accepted reduction-step beat |
| first_in | Input | Marks the first product of each dot product |
| last_in | Input | Marks the final product of each dot product |
| matrix_c_out[N_SIZE] | Output | One completed output row |
| row_index | Output | Index of the currently presented output row |
| valid_out | Output | Indicates that the row at row_index is complete |
| matrix_done | Output | One-cycle pulse after the final row is consumed |

The input source must present the K reduction-step vectors for each matrix in the intended order and align first_in/last_in with the first and final valid beats. The design intentionally leaves scheduling to the external source.
