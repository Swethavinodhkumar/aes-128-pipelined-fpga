
// =============================================================================
// Module: aes_subbytes
// =============================================================================
module aes_subbytes (
    input  logic [127:0] state_in,
    output logic [127:0] state_out
);
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : sb_loop
            aes_sbox u_sbox (
                .in  (state_in [127 - i*8 -: 8]),
                .out (state_out[127 - i*8 -: 8])
            );
        end
    endgenerate
endmodule

// =============================================================================
// Module: aes_shiftrows
// =============================================================================
module aes_shiftrows (
    input  logic [127:0] state_in,
    output logic [127:0] state_out
);
    assign state_out[127:120] = state_in[127:120];
    assign state_out[119:112] = state_in[87:80];
    assign state_out[111:104] = state_in[47:40];
    assign state_out[103:96]  = state_in[7:0];

    assign state_out[95:88]   = state_in[95:88];
    assign state_out[87:80]   = state_in[55:48];
    assign state_out[79:72]   = state_in[15:8];
    assign state_out[71:64]   = state_in[103:96];

    assign state_out[63:56]   = state_in[63:56];
    assign state_out[55:48]   = state_in[23:16];
    assign state_out[47:40]   = state_in[111:104];
    assign state_out[39:32]   = state_in[71:64];

    assign state_out[31:24]   = state_in[31:24];
    assign state_out[23:16]   = state_in[119:112];
    assign state_out[15:8]    = state_in[79:72];
    assign state_out[7:0]     = state_in[39:32];
endmodule

// =============================================================================
// Module: aes_mixcolumns
// =============================================================================
module aes_mixcolumns (
    input  logic [127:0] state_in,
    output logic [127:0] state_out
);
    function automatic logic [7:0] xtime(input logic [7:0] b);
        xtime = (b[7]) ? ((b << 1) ^ 8'h1b) : (b << 1);
    endfunction

    function automatic logic [7:0] mul3(input logic [7:0] b);
        mul3 = xtime(b) ^ b;
    endfunction

    function automatic logic [31:0] mix_col(input logic [31:0] col);
        logic [7:0] b0, b1, b2, b3, a0, a1, a2, a3;
        b0 = col[31:24]; b1 = col[23:16]; b2 = col[15:8]; b3 = col[7:0];
        a0 = xtime(b0) ^ mul3(b1) ^ b2        ^ b3;
        a1 = b0        ^ xtime(b1) ^ mul3(b2)  ^ b3;
        a2 = b0        ^ b1        ^ xtime(b2)  ^ mul3(b3);
        a3 = mul3(b0)  ^ b1        ^ b2         ^ xtime(b3);
        mix_col = {a0, a1, a2, a3};
    endfunction

    assign state_out[127:96] = mix_col(state_in[127:96]);
    assign state_out[95:64]  = mix_col(state_in[95:64]);
    assign state_out[63:32]  = mix_col(state_in[63:32]);
    assign state_out[31:0]   = mix_col(state_in[31:0]);
endmodule

// =============================================================================
// Module: aes_addroundkey
// =============================================================================
module aes_addroundkey (
    input  logic [127:0] state_in,
    input  logic [127:0] round_key,
    output logic [127:0] state_out
);
    assign state_out = state_in ^ round_key;
endmodule