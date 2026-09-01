// =============================================================================
// Module: aes_pipe_round
// Description: One full AES round (SubBytes → ShiftRows → MixColumns →
//              AddRoundKey) clocked with pipeline registers.
//              Used for rounds 1-9.  Round 10 skips MixColumns.
//
// Parameters:
//   IS_LAST  – set 1 for round 10 (skips MixColumns)
//
// Pipeline latency of the whole 10-stage chain: 10 clock cycles
// Throughput: 1 block per clock cycle (after pipeline fills)
// =============================================================================

module aes_pipe_round #(
    parameter IS_LAST = 0
)(
    input  logic         clk,
    input  logic         rst_n,
    // Data path
    input  logic [127:0] state_in,
    input  logic [127:0] round_key,
    output logic [127:0] state_out,
    // Valid/tag propagation
    input  logic         valid_in,
    output logic         valid_out,
    input  logic [31:0]  tag_in,    // block index propagated for ordering
    output logic [31:0]  tag_out
);

    // -------------------------------------------------------------------------
    // Combinational round logic
    // -------------------------------------------------------------------------
    logic [127:0] after_sb, after_sr, after_mc, after_ark;

    aes_subbytes  u_sb (.state_in(state_in),  .state_out(after_sb));
    aes_shiftrows u_sr (.state_in(after_sb),  .state_out(after_sr));
    aes_mixcolumns u_mc(.state_in(after_sr),  .state_out(after_mc));

    // Round 10: no MixColumns
    wire [127:0] pre_ark = IS_LAST ? after_sr : after_mc;

    aes_addroundkey u_ark (
        .state_in  (pre_ark),
        .round_key (round_key),
        .state_out (after_ark)
    );

    // -------------------------------------------------------------------------
    // Pipeline register
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_out  <= 128'd0;
            valid_out  <= 1'b0;
            tag_out    <= 32'd0;
        end else begin
            state_out  <= after_ark;
            valid_out  <= valid_in;
            tag_out    <= tag_in;
        end
    end

endmodule

