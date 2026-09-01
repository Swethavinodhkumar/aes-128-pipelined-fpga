// =============================================================================
// Module: aes_text_feeder  (FIXED)
// Fix: DRAIN state compared blocks_received == block_count but
//      blocks_received is incremented in the SAME clock cycle via the
//      if(valid_out) block — on the LAST valid_out pulse, both the increment
//      AND the DRAIN comparison happen simultaneously. Because the increment
//      is non-blocking (<=), blocks_received still holds the OLD value during
//      the comparison, so the condition is never true on the last cycle.
//      The FSM gets stuck in DRAIN forever → done_all never fires → LED off.
//
//      Fix: compare (blocks_received + 1) when valid_out is high in DRAIN,
//      OR simply compare >= instead of ==, OR use a next-value signal.
//      Cleanest: use (blocks_received == block_count - 1) && valid_out as
//      the exit condition so we exit on the cycle the LAST block arrives.
// =============================================================================

module aes_text_feeder #(
    parameter int MAX_BLOCKS = 256,
    parameter     HEX_FILE   = "plaintext.hex"
)(
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [127:0] key,
    input  logic [15:0]  block_count,

    output logic [127:0] plaintext,
    output logic         valid_in,
    output logic [31:0]  block_idx,

    input  logic [127:0] ciphertext,
    input  logic         valid_out,
    input  logic [31:0]  block_out,

    output logic         busy,
    output logic         done_all
);

    logic [127:0] pt_rom [0:MAX_BLOCKS-1];
    initial $readmemh(HEX_FILE, pt_rom);

    logic [127:0] ct_mem [0:MAX_BLOCKS-1];
    logic [15:0]  blocks_sent;
    logic [15:0]  blocks_received;

    typedef enum logic [1:0] {IDLE, STREAM, DRAIN} fsm_t;
    fsm_t state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            busy            <= 1'b0;
            done_all        <= 1'b0;
            valid_in        <= 1'b0;
            blocks_sent     <= 16'd0;
            blocks_received <= 16'd0;
            block_idx       <= 32'd0;
            plaintext       <= 128'd0;
        end else begin
            valid_in <= 1'b0;

            case (state)
                IDLE: begin
                    done_all <= 1'b0;
                    if (start && block_count > 0) begin
                        blocks_sent     <= 16'd0;
                        blocks_received <= 16'd0;
                        busy            <= 1'b1;
                        state           <= STREAM;
                    end
                end

                STREAM: begin
                    if (blocks_sent < block_count) begin
                        plaintext   <= pt_rom[blocks_sent];
                        block_idx   <= {16'd0, blocks_sent};
                        valid_in    <= 1'b1;
                        blocks_sent <= blocks_sent + 1'b1;
                    end else begin
                        state <= DRAIN;
                    end
                end

                DRAIN: begin
                    // FIX: exit when the LAST block arrives this very cycle
                    // (blocks_received hasn't updated yet due to non-blocking)
                    if (valid_out && (blocks_received + 16'd1 == block_count)) begin
                        busy     <= 1'b0;
                        done_all <= 1'b1;
                        state    <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase

            // Store each encrypted block as it arrives
            if (valid_out) begin
                ct_mem[block_out[15:0]] <= ciphertext;
                blocks_received         <= blocks_received + 1'b1;
            end
        end
    end

endmodule
