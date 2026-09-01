
// =============================================================================
// Module: aes128_pipeline
// Description: AES-128 Encryption – 10-stage Fully Pipelined Architecture
//
//  Iterative vs Pipeline comparison:
//    Iterative  → 11 cycles per block, 1 block active at a time
//    Pipeline   → 10 cycles latency, NEW BLOCK ACCEPTED EVERY CYCLE
//
//  Pipeline structure (each stage = 1 clock):
//    Stage 0 : AddRoundKey with round_key[0]  (input register)
//    Stage 1 : Full round with round_key[1]
//    ...
//    Stage 9 : Full round with round_key[9]
//    Stage 10: Final round (no MixColumns) with round_key[10]
//
//  Total pipeline depth: 11 register stages (including input reg)
//  Latency: 11 clock cycles from valid_in to valid_out
//  Throughput: 1 block / clock cycle
//
//  Ports:
//    clk        – system clock
//    rst_n      – active-low synchronous reset
//    plaintext  – 128-bit plaintext input
//    key        – 128-bit cipher key (static; key change flushes pipeline)
//    valid_in   – high when plaintext is valid (treat like AXI-Stream tvalid)
//    block_idx  – block sequence number for output ordering (32-bit tag)
//    ciphertext – 128-bit encrypted output
//    valid_out  – high when ciphertext is valid
//    block_out  – block sequence number corresponding to ciphertext
// =============================================================================

module aes128_pipeline (
    input  logic         clk,
    input  logic         rst_n,

    // Input
    input  logic [127:0] plaintext,
    input  logic [127:0] key,
    input  logic         valid_in,
    input  logic [31:0]  block_idx,

    // Output
    output logic [127:0] ciphertext,
    output logic         valid_out,
    output logic [31:0]  block_out
);

    // -------------------------------------------------------------------------
    // Key schedule (combinational)
    // -------------------------------------------------------------------------
    logic [127:0] round_key [0:10];

    aes_key_expansion u_kexp (
        .key       (key),
        .round_key (round_key)
    );

    // -------------------------------------------------------------------------
    // Stage 0 – Initial AddRoundKey + input register
    // -------------------------------------------------------------------------
    logic [127:0] s0_state;
    logic         s0_valid;
    logic [31:0]  s0_tag;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_state <= 128'd0;
            s0_valid <= 1'b0;
            s0_tag   <= 32'd0;
        end else begin
            s0_state <= plaintext ^ round_key[0];   // AddRoundKey(0)
            s0_valid <= valid_in;
            s0_tag   <= block_idx;
        end
    end

    // -------------------------------------------------------------------------
    // Stages 1-10 – pipeline round instances
    // -------------------------------------------------------------------------
    // Wire arrays between stages
    logic [127:0] ps [0:10];   // state at output of each stage (ps[0]=s0)
    logic         pv [0:10];   // valid at output of each stage
    logic [31:0]  pt [0:10];   // tag at output of each stage

    assign ps[0] = s0_state;
    assign pv[0] = s0_valid;
    assign pt[0] = s0_tag;

    genvar g;
    generate
        // Rounds 1-9: full round (IS_LAST=0)
        for (g = 1; g <= 9; g++) begin : pipe_rounds
            aes_pipe_round #(.IS_LAST(0)) u_round (
                .clk       (clk),
                .rst_n     (rst_n),
                .state_in  (ps[g-1]),
                .round_key (round_key[g]),
                .state_out (ps[g]),
                .valid_in  (pv[g-1]),
                .valid_out (pv[g]),
                .tag_in    (pt[g-1]),
                .tag_out   (pt[g])
            );
        end

        // Round 10: final round (IS_LAST=1, no MixColumns)
        aes_pipe_round #(.IS_LAST(1)) u_round_final (
            .clk       (clk),
            .rst_n     (rst_n),
            .state_in  (ps[9]),
            .round_key (round_key[10]),
            .state_out (ps[10]),
            .valid_in  (pv[9]),
            .valid_out (pv[10]),
            .tag_in    (pt[9]),
            .tag_out   (pt[10])
        );
    endgenerate

    // -------------------------------------------------------------------------
    // Output
    // -------------------------------------------------------------------------
    assign ciphertext = ps[10];
    assign valid_out  = pv[10];
    assign block_out  = pt[10];

endmodule
