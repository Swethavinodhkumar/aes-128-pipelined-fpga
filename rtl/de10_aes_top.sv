// =============================================================================
// de10_aes_top.sv — AES-128 Pipeline with Seven Segment Output
// Fix: ciphertext_reg is (* preserve *) and directly drives displays
// =============================================================================

module de10_aes_top #(
    parameter [127:0] KEY_CONST   = 128'h2b7e151628aed2a6abf7158809cf4f3c,
    parameter int     BLOCK_COUNT = 2,
    parameter int     MAX_BLOCKS  = 256,
    parameter         HEX_FILE    = "plaintext.hex"
)(
    input  logic        MAX10_CLK1_50,
    input  logic [1:0]  KEY,
    input  logic [9:0]  SW,
    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1,
    output logic [6:0]  HEX2,
    output logic [6:0]  HEX3,
    output logic [6:0]  HEX4,
    output logic [6:0]  HEX5
);

    logic clk, rst_n;
    assign clk   = MAX10_CLK1_50;
    assign rst_n = KEY[0];

    // =========================================================================
    // Edge detect KEY[1] → 1-cycle start pulse
    // =========================================================================
    logic key1_prev, start;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) key1_prev <= 1'b1;
        else        key1_prev <= KEY[1];
    end
    assign start = key1_prev & ~KEY[1];

    // =========================================================================
    // Plaintext ROM — loaded from plaintext.hex
    // =========================================================================
    // Quartus ROM using altsyncram — reads from MIF file properly in hardware
logic [127:0] pt_rom_out;
logic [7:0]   rom_addr;

altsyncram #(
    .operation_mode              ("ROM"),
    .width_a                     (128),
    .widthad_a                   (8),
    .numwords_a                  (256),
    .outdata_reg_a               ("UNREGISTERED"),
    .init_file                   ("plaintext.mif"),
    .intended_device_family      ("MAX 10"),
    .lpm_hint                    ("ENABLE_RUNTIME_MOD=NO"),
    .lpm_type                    ("altsyncram"),
    .read_during_write_mode_port_a ("NEW_DATA_NO_NBE_READ")
) u_rom (
    .clock0    (clk),
    .address_a (rom_addr),
    .q_a       (pt_rom_out)
);

    // =========================================================================
    // Pipeline interface
    // =========================================================================
    logic [127:0] pt_feed;
    logic         pt_valid;
    logic [31:0]  pt_idx;

    logic [127:0] enc_ct;
    logic         enc_valid_out;
    logic [31:0]  enc_block_out;

    // =========================================================================
    // AES-128 Pipeline
    // =========================================================================
    aes128_pipeline u_pipeline (
        .clk        (clk),
        .rst_n      (rst_n),
        .plaintext  (pt_feed),
        .key        (KEY_CONST),
        .valid_in   (pt_valid),
        .block_idx  (pt_idx),
        .ciphertext (enc_ct),
        .valid_out  (enc_valid_out),
        .block_out  (enc_block_out)
    );

    // =========================================================================
    // Preserved ciphertext register — (* preserve *) stops Quartus optimising
    // this away. Stores Block 0 ciphertext for display.
    // =========================================================================
    (* preserve *) logic [127:0] ciphertext_reg;
    (* preserve *) logic         ct_valid;

    

    // =========================================================================
    // FSM — IDLE → STREAM → DRAIN → DONE
    // =========================================================================
    typedef enum logic [1:0] {
        ST_IDLE=2'd0, ST_STREAM=2'd1,
        ST_DRAIN=2'd2, ST_DONE=2'd3
    } state_t;

    state_t      state;
	 logic rom_read_pending;
    logic [15:0] blocks_sent;
    logic [15:0] blocks_received;
    logic        done_all;

   always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state              <= ST_IDLE;
        blocks_sent        <= '0;
        blocks_received    <= '0;
        done_all           <= 1'b0;
        pt_valid           <= 1'b0;
        pt_feed            <= '0;
        pt_idx             <= '0;
        rom_addr           <= '0;
        rom_read_pending   <= 1'b0;
		  ciphertext_reg     <= 128'd0;
		  ct_valid           <= 1'b0;
    end else begin
        pt_valid <= 1'b0;

        case (state)
            ST_IDLE: begin
                done_all <= 1'b0;
                if (start) begin
                    blocks_sent     <= '0;
                    blocks_received <= '0;
                    rom_addr        <= 8'd0;
                    rom_read_pending<= 1'b1;
                    state           <= ST_STREAM;
                end
            end

            ST_STREAM: begin
                if (rom_read_pending) begin
                    // ROM data is now valid — send it
                    pt_feed          <= pt_rom_out;
                    pt_idx           <= {16'd0, blocks_sent};
                    pt_valid         <= 1'b1;
                    blocks_sent      <= blocks_sent + 1'b1;
                    rom_read_pending <= 1'b0;

                    if (blocks_sent + 1 < BLOCK_COUNT) begin
                        // Pre-fetch next address
                        rom_addr         <= rom_addr + 8'd1;
                        rom_read_pending <= 1'b1;
                    end else begin
                        state <= ST_DRAIN;
                    end
                end
            end

            ST_DRAIN: begin
                if (enc_valid_out) begin
                    blocks_received <= blocks_received + 1'b1;
                    if (blocks_received + 16'd1 >= BLOCK_COUNT) begin
                        done_all <= 1'b1;
                        state    <= ST_DONE;
                    end
                end
            end

            ST_DONE: begin end

            default: state <= ST_IDLE;
        endcase

        // Capture block 0 ciphertext
        if (enc_valid_out && enc_block_out == 32'd0) begin
            ciphertext_reg <= enc_ct;
            ct_valid       <= 1'b1;
        end
    end
end

    // =========================================================================
    // Display mux
    // SW[9]=0 → ciphertext_reg (encrypted output)
    // SW[9]=1 → pt_rom[0]     (plaintext — for comparison)
    // SW[2:0] selects 24-bit window:
    //   000 → bits [127:104]  digits  1-6
    //   001 → bits [103:80]   digits  7-12
    //   010 → bits [79:56]    digits 13-18
    //   011 → bits [55:32]    digits 19-24
    //   100 → bits [31:8]     digits 25-30
    //   101 → bits [7:0]      digits 31-32 (HEX1,HEX0 only)
    // =========================================================================
    logic [127:0] display_word;
    assign display_word = ciphertext_reg;

    logic [23:0] display_slice;
    logic        last_view;

    always_comb begin
        last_view = (SW[2:0] == 3'b101);
        case (SW[2:0])
            3'b000: display_slice = display_word[127:104];
            3'b001: display_slice = display_word[103:80];
            3'b010: display_slice = display_word[79:56];
            3'b011: display_slice = display_word[55:32];
            3'b100: display_slice = display_word[31:8];
            3'b101: display_slice = {8'h00, display_word[7:0]};
            default: display_slice = 24'h0;
        endcase
    end

    // =========================================================================
    // Seven segment decoder instances
    // =========================================================================
    logic [6:0] seg5, seg4, seg3, seg2, seg1, seg0;

    seg7_decoder u5 (.hex_in(display_slice[23:20]), .seg_out(seg5));
    seg7_decoder u4 (.hex_in(display_slice[19:16]), .seg_out(seg4));
    seg7_decoder u3 (.hex_in(display_slice[15:12]), .seg_out(seg3));
    seg7_decoder u2 (.hex_in(display_slice[11:8]),  .seg_out(seg2));
    seg7_decoder u1 (.hex_in(display_slice[7:4]),   .seg_out(seg1));
    seg7_decoder u0 (.hex_in(display_slice[3:0]),   .seg_out(seg0));

    // Blank upper 4 displays in last view (only 2 hex digits = HEX1,HEX0)
    assign HEX5 = last_view ? 7'b1111111 : seg5;
    assign HEX4 = last_view ? 7'b1111111 : seg4;
    assign HEX3 = last_view ? 7'b1111111 : seg3;
    assign HEX2 = last_view ? 7'b1111111 : seg2;
    assign HEX1 = seg1;
    assign HEX0 = seg0;

    // =========================================================================
    // LEDs
    // LEDR[0] = done (stays ON after encryption complete)
    // LEDR[1] = ct_valid (ciphertext captured successfully)
    // LEDR[2] = pipeline output pulsing
    // LEDR[4:2] = current SW view
    // =========================================================================
    assign LEDR[0]   = done_all;
    assign LEDR[1]   = ct_valid;
    assign LEDR[2]   = enc_valid_out;
    assign LEDR[5:3] = SW[2:0];
    assign LEDR[9:6] = '0;

endmodule