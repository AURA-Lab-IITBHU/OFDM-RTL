`timescale 1ns / 1ps

// Self-checking end-to-end testbench for ofdm_generate_frame (full.v).
//
// Golden frame is a Python re-implementation of ofdm_hls.cc.cpp:
//   generate_zc_sequence -> generate_qpsk_symbols -> map_to_subcarriers
//   -> ifft (HLS scaled: setSch(0x2A) = 4*4*4 = 1/64) -> add_cp -> add_to_frame
//
// stimulus: qpsk_bits = all ones. TOLERANCE absorbs radix-2^2 rounding drift.

module tb_ofdm_frame;
    localparam TOLERANCE = 48;   // LSB

    reg          clk = 0, rst = 1;
    reg  [127:0] qpsk_bits = {128{1'b1}};
    wire [4*80*32-1:0] ofdm_frame;
    wire         frame_done;

    integer error_count = 0;
    integer i, n, waited, frames_seen;
    integer start_pulses, ifft_samples, ifft_at_framedone;
    reg signed [15:0] exp_re [0:319];
    reg signed [15:0] exp_im [0:319];
    reg signed [31:0] dr, di;
    integer max_err;

    always #5 clk = ~clk;

    ofdm_generate_frame dut (
        .clk(clk), .rst(rst), .qpsk_bits(qpsk_bits),
        .ofdm_frame(ofdm_frame), .frame_done(frame_done)
    );

    always @(posedge clk) begin
        if (!rst) begin
            if (dut.symbol_start) start_pulses = start_pulses + 1;
            if (dut.u_ifft.do_en) ifft_samples = ifft_samples + 1;
            if (frame_done) begin
                frames_seen = frames_seen + 1;
                // snapshot once, on the first frame completion
                if (frames_seen == 1) ifft_at_framedone = ifft_samples;
            end
        end
    end

    initial begin
        start_pulses = 0; ifft_samples = 0; frames_seen = 0; ifft_at_framedone = 0;

        exp_re[  0] = 16'h00f5; exp_im[  0] = 16'h07a2;
        exp_re[  1] = 16'hf8a1; exp_im[  1] = 16'hef1e;
        exp_re[  2] = 16'h056d; exp_im[  2] = 16'hfed2;
        exp_re[  3] = 16'h00e0; exp_im[  3] = 16'h0cee;
        exp_re[  4] = 16'h073c; exp_im[  4] = 16'hff9e;
        exp_re[  5] = 16'hf845; exp_im[  5] = 16'hf3f0;
        exp_re[  6] = 16'h0644; exp_im[  6] = 16'h0d40;
        exp_re[  7] = 16'hefc4; exp_im[  7] = 16'hfa7b;
        exp_re[  8] = 16'h0596; exp_im[  8] = 16'hffe9;
        exp_re[  9] = 16'h0d20; exp_im[  9] = 16'hfdbb;
        exp_re[ 10] = 16'hfe01; exp_im[ 10] = 16'hf832;
        exp_re[ 11] = 16'hf8dd; exp_im[ 11] = 16'h146d;
        exp_re[ 12] = 16'hf8b6; exp_im[ 12] = 16'hfaba;
        exp_re[ 13] = 16'h0c28; exp_im[ 13] = 16'hf8af;
        exp_re[ 14] = 16'hff16; exp_im[ 14] = 16'hf979;
        exp_re[ 15] = 16'hf723; exp_im[ 15] = 16'h0a7c;
        exp_re[ 16] = 16'h0c69; exp_im[ 16] = 16'hfbc4;
        exp_re[ 17] = 16'hf864; exp_im[ 17] = 16'h0b3b;
        exp_re[ 18] = 16'hfd79; exp_im[ 18] = 16'hf9f0;
        exp_re[ 19] = 16'h0a07; exp_im[ 19] = 16'hf534;
        exp_re[ 20] = 16'hf693; exp_im[ 20] = 16'hfe4f;
        exp_re[ 21] = 16'h0426; exp_im[ 21] = 16'h14da;
        exp_re[ 22] = 16'hf90f; exp_im[ 22] = 16'hfb4c;
        exp_re[ 23] = 16'h09c2; exp_im[ 23] = 16'hf515;
        exp_re[ 24] = 16'h02bd; exp_im[ 24] = 16'hfcff;
        exp_re[ 25] = 16'hf2a9; exp_im[ 25] = 16'h07dc;
        exp_re[ 26] = 16'h0d36; exp_im[ 26] = 16'h0388;
        exp_re[ 27] = 16'hf30c; exp_im[ 27] = 16'hff8f;
        exp_re[ 28] = 16'h0111; exp_im[ 28] = 16'hfaf0;
        exp_re[ 29] = 16'h0dfb; exp_im[ 29] = 16'h00f4;
        exp_re[ 30] = 16'hfe90; exp_im[ 30] = 16'hfc9b;
        exp_re[ 31] = 16'hefc7; exp_im[ 31] = 16'h0355;
        exp_re[ 32] = 16'h0663; exp_im[ 32] = 16'h0195;
        exp_re[ 33] = 16'h0893; exp_im[ 33] = 16'h0221;
        exp_re[ 34] = 16'hf91a; exp_im[ 34] = 16'h06b8;
        exp_re[ 35] = 16'h0319; exp_im[ 35] = 16'he837;
        exp_re[ 36] = 16'hf4d8; exp_im[ 36] = 16'h0e9c;
        exp_re[ 37] = 16'h106f; exp_im[ 37] = 16'hfba7;
        exp_re[ 38] = 16'h0003; exp_im[ 38] = 16'h0b47;
        exp_re[ 39] = 16'hf2cb; exp_im[ 39] = 16'hfa28;
        exp_re[ 40] = 16'hfcd0; exp_im[ 40] = 16'h009a;
        exp_re[ 41] = 16'h10df; exp_im[ 41] = 16'hf9f1;
        exp_re[ 42] = 16'hf8da; exp_im[ 42] = 16'h0024;
        exp_re[ 43] = 16'hfdeb; exp_im[ 43] = 16'hfd8a;
        exp_re[ 44] = 16'h092f; exp_im[ 44] = 16'h0a88;
        exp_re[ 45] = 16'heee4; exp_im[ 45] = 16'h047b;
        exp_re[ 46] = 16'h09d3; exp_im[ 46] = 16'hff3f;
        exp_re[ 47] = 16'h00e2; exp_im[ 47] = 16'he9cf;
        exp_re[ 48] = 16'h00a5; exp_im[ 48] = 16'h01e5;
        exp_re[ 49] = 16'hffd2; exp_im[ 49] = 16'h1275;
        exp_re[ 50] = 16'hf829; exp_im[ 50] = 16'h0647;
        exp_re[ 51] = 16'h0d42; exp_im[ 51] = 16'hf33b;
        exp_re[ 52] = 16'hf574; exp_im[ 52] = 16'hfd2e;
        exp_re[ 53] = 16'h00e3; exp_im[ 53] = 16'hfdef;
        exp_re[ 54] = 16'h081a; exp_im[ 54] = 16'hff05;
        exp_re[ 55] = 16'hf475; exp_im[ 55] = 16'h0c70;
        exp_re[ 56] = 16'h0445; exp_im[ 56] = 16'h0018;
        exp_re[ 57] = 16'h0a61; exp_im[ 57] = 16'hf6e8;
        exp_re[ 58] = 16'hf932; exp_im[ 58] = 16'hfc27;
        exp_re[ 59] = 16'hf978; exp_im[ 59] = 16'h0e54;
        exp_re[ 60] = 16'hf96a; exp_im[ 60] = 16'hf21f;
        exp_re[ 61] = 16'h1337; exp_im[ 61] = 16'h080b;
        exp_re[ 62] = 16'hfd62; exp_im[ 62] = 16'hf98e;
        exp_re[ 63] = 16'hfa72; exp_im[ 63] = 16'h06e3;
        exp_re[ 64] = 16'h00f5; exp_im[ 64] = 16'h07a2;
        exp_re[ 65] = 16'hf8a1; exp_im[ 65] = 16'hef1e;
        exp_re[ 66] = 16'h056d; exp_im[ 66] = 16'hfed2;
        exp_re[ 67] = 16'h00e0; exp_im[ 67] = 16'h0cee;
        exp_re[ 68] = 16'h073c; exp_im[ 68] = 16'hff9e;
        exp_re[ 69] = 16'hf845; exp_im[ 69] = 16'hf3f0;
        exp_re[ 70] = 16'h0644; exp_im[ 70] = 16'h0d40;
        exp_re[ 71] = 16'hefc4; exp_im[ 71] = 16'hfa7b;
        exp_re[ 72] = 16'h0596; exp_im[ 72] = 16'hffe9;
        exp_re[ 73] = 16'h0d20; exp_im[ 73] = 16'hfdbb;
        exp_re[ 74] = 16'hfe01; exp_im[ 74] = 16'hf832;
        exp_re[ 75] = 16'hf8dd; exp_im[ 75] = 16'h146d;
        exp_re[ 76] = 16'hf8b6; exp_im[ 76] = 16'hfaba;
        exp_re[ 77] = 16'h0c28; exp_im[ 77] = 16'hf8af;
        exp_re[ 78] = 16'hff16; exp_im[ 78] = 16'hf979;
        exp_re[ 79] = 16'hf723; exp_im[ 79] = 16'h0a7c;
        exp_re[ 80] = 16'hfe00; exp_im[ 80] = 16'h0000;
        exp_re[ 81] = 16'h002a; exp_im[ 81] = 16'hfe56;
        exp_re[ 82] = 16'hfbc0; exp_im[ 82] = 16'hfe27;
        exp_re[ 83] = 16'h0179; exp_im[ 83] = 16'hff9c;
        exp_re[ 84] = 16'h001e; exp_im[ 84] = 16'h016a;
        exp_re[ 85] = 16'h0546; exp_im[ 85] = 16'h01f6;
        exp_re[ 86] = 16'hff6f; exp_im[ 86] = 16'h00c4;
        exp_re[ 87] = 16'hffa7; exp_im[ 87] = 16'hfee4;
        exp_re[ 88] = 16'hf92c; exp_im[ 88] = 16'hfe00;
        exp_re[ 89] = 16'hfee5; exp_im[ 89] = 16'hfee4;
        exp_re[ 90] = 16'h0086; exp_im[ 90] = 16'h00c4;
        exp_re[ 91] = 16'h09d5; exp_im[ 91] = 16'h01f6;
        exp_re[ 92] = 16'h051c; exp_im[ 92] = 16'h016a;
        exp_re[ 93] = 16'hff5f; exp_im[ 93] = 16'hff9c;
        exp_re[ 94] = 16'heb3d; exp_im[ 94] = 16'hfe27;
        exp_re[ 95] = 16'he026; exp_im[ 95] = 16'hfe56;
        exp_re[ 96] = 16'h5600; exp_im[ 96] = 16'h0000;
        exp_re[ 97] = 16'he026; exp_im[ 97] = 16'h01aa;
        exp_re[ 98] = 16'heb3d; exp_im[ 98] = 16'h01d9;
        exp_re[ 99] = 16'hff5f; exp_im[ 99] = 16'h0064;
        exp_re[100] = 16'h051c; exp_im[100] = 16'hfe96;
        exp_re[101] = 16'h09d5; exp_im[101] = 16'hfe0a;
        exp_re[102] = 16'h0086; exp_im[102] = 16'hff3c;
        exp_re[103] = 16'hfee5; exp_im[103] = 16'h011c;
        exp_re[104] = 16'hf92c; exp_im[104] = 16'h0200;
        exp_re[105] = 16'hffa7; exp_im[105] = 16'h011c;
        exp_re[106] = 16'hff6f; exp_im[106] = 16'hff3c;
        exp_re[107] = 16'h0546; exp_im[107] = 16'hfe0a;
        exp_re[108] = 16'h001e; exp_im[108] = 16'hfe96;
        exp_re[109] = 16'h0179; exp_im[109] = 16'h0064;
        exp_re[110] = 16'hfbc0; exp_im[110] = 16'h01d9;
        exp_re[111] = 16'h002a; exp_im[111] = 16'h01aa;
        exp_re[112] = 16'hfe00; exp_im[112] = 16'h0000;
        exp_re[113] = 16'h0382; exp_im[113] = 16'hfe56;
        exp_re[114] = 16'hff84; exp_im[114] = 16'hfe27;
        exp_re[115] = 16'h024a; exp_im[115] = 16'hff9c;
        exp_re[116] = 16'hfd0e; exp_im[116] = 16'h016a;
        exp_re[117] = 16'h00d3; exp_im[117] = 16'h01f6;
        exp_re[118] = 16'hfd97; exp_im[118] = 16'h00c4;
        exp_re[119] = 16'h0287; exp_im[119] = 16'hfee4;
        exp_re[120] = 16'hfed4; exp_im[120] = 16'hfe00;
        exp_re[121] = 16'h0266; exp_im[121] = 16'hfee4;
        exp_re[122] = 16'hfdc5; exp_im[122] = 16'h00c4;
        exp_re[123] = 16'h0182; exp_im[123] = 16'h01f6;
        exp_re[124] = 16'hfdb8; exp_im[124] = 16'h016a;
        exp_re[125] = 16'h020f; exp_im[125] = 16'hff9c;
        exp_re[126] = 16'hfe2f; exp_im[126] = 16'hfe27;
        exp_re[127] = 16'h0215; exp_im[127] = 16'hfe56;
        exp_re[128] = 16'hfe00; exp_im[128] = 16'h0000;
        exp_re[129] = 16'h0215; exp_im[129] = 16'h01aa;
        exp_re[130] = 16'hfe2f; exp_im[130] = 16'h01d9;
        exp_re[131] = 16'h020f; exp_im[131] = 16'h0064;
        exp_re[132] = 16'hfdb8; exp_im[132] = 16'hfe96;
        exp_re[133] = 16'h0182; exp_im[133] = 16'hfe0a;
        exp_re[134] = 16'hfdc5; exp_im[134] = 16'hff3c;
        exp_re[135] = 16'h0266; exp_im[135] = 16'h011c;
        exp_re[136] = 16'hfed4; exp_im[136] = 16'h0200;
        exp_re[137] = 16'h0287; exp_im[137] = 16'h011c;
        exp_re[138] = 16'hfd97; exp_im[138] = 16'hff3c;
        exp_re[139] = 16'h00d3; exp_im[139] = 16'hfe0a;
        exp_re[140] = 16'hfd0e; exp_im[140] = 16'hfe96;
        exp_re[141] = 16'h024a; exp_im[141] = 16'h0064;
        exp_re[142] = 16'hff84; exp_im[142] = 16'h01d9;
        exp_re[143] = 16'h0382; exp_im[143] = 16'h01aa;
        exp_re[144] = 16'hfe00; exp_im[144] = 16'h0000;
        exp_re[145] = 16'h002a; exp_im[145] = 16'hfe56;
        exp_re[146] = 16'hfbc0; exp_im[146] = 16'hfe27;
        exp_re[147] = 16'h0179; exp_im[147] = 16'hff9c;
        exp_re[148] = 16'h001e; exp_im[148] = 16'h016a;
        exp_re[149] = 16'h0546; exp_im[149] = 16'h01f6;
        exp_re[150] = 16'hff6f; exp_im[150] = 16'h00c4;
        exp_re[151] = 16'hffa7; exp_im[151] = 16'hfee4;
        exp_re[152] = 16'hf92c; exp_im[152] = 16'hfe00;
        exp_re[153] = 16'hfee5; exp_im[153] = 16'hfee4;
        exp_re[154] = 16'h0086; exp_im[154] = 16'h00c4;
        exp_re[155] = 16'h09d5; exp_im[155] = 16'h01f6;
        exp_re[156] = 16'h051c; exp_im[156] = 16'h016a;
        exp_re[157] = 16'hff5f; exp_im[157] = 16'hff9c;
        exp_re[158] = 16'heb3d; exp_im[158] = 16'hfe27;
        exp_re[159] = 16'he026; exp_im[159] = 16'hfe56;
        exp_re[160] = 16'hfe00; exp_im[160] = 16'h0000;
        exp_re[161] = 16'h002a; exp_im[161] = 16'hfe56;
        exp_re[162] = 16'hfbc0; exp_im[162] = 16'hfe27;
        exp_re[163] = 16'h0179; exp_im[163] = 16'hff9c;
        exp_re[164] = 16'h001e; exp_im[164] = 16'h016a;
        exp_re[165] = 16'h0546; exp_im[165] = 16'h01f6;
        exp_re[166] = 16'hff6f; exp_im[166] = 16'h00c4;
        exp_re[167] = 16'hffa7; exp_im[167] = 16'hfee4;
        exp_re[168] = 16'hf92c; exp_im[168] = 16'hfe00;
        exp_re[169] = 16'hfee5; exp_im[169] = 16'hfee4;
        exp_re[170] = 16'h0086; exp_im[170] = 16'h00c4;
        exp_re[171] = 16'h09d5; exp_im[171] = 16'h01f6;
        exp_re[172] = 16'h051c; exp_im[172] = 16'h016a;
        exp_re[173] = 16'hff5f; exp_im[173] = 16'hff9c;
        exp_re[174] = 16'heb3d; exp_im[174] = 16'hfe27;
        exp_re[175] = 16'he026; exp_im[175] = 16'hfe56;
        exp_re[176] = 16'h5600; exp_im[176] = 16'h0000;
        exp_re[177] = 16'he026; exp_im[177] = 16'h01aa;
        exp_re[178] = 16'heb3d; exp_im[178] = 16'h01d9;
        exp_re[179] = 16'hff5f; exp_im[179] = 16'h0064;
        exp_re[180] = 16'h051c; exp_im[180] = 16'hfe96;
        exp_re[181] = 16'h09d5; exp_im[181] = 16'hfe0a;
        exp_re[182] = 16'h0086; exp_im[182] = 16'hff3c;
        exp_re[183] = 16'hfee5; exp_im[183] = 16'h011c;
        exp_re[184] = 16'hf92c; exp_im[184] = 16'h0200;
        exp_re[185] = 16'hffa7; exp_im[185] = 16'h011c;
        exp_re[186] = 16'hff6f; exp_im[186] = 16'hff3c;
        exp_re[187] = 16'h0546; exp_im[187] = 16'hfe0a;
        exp_re[188] = 16'h001e; exp_im[188] = 16'hfe96;
        exp_re[189] = 16'h0179; exp_im[189] = 16'h0064;
        exp_re[190] = 16'hfbc0; exp_im[190] = 16'h01d9;
        exp_re[191] = 16'h002a; exp_im[191] = 16'h01aa;
        exp_re[192] = 16'hfe00; exp_im[192] = 16'h0000;
        exp_re[193] = 16'h0382; exp_im[193] = 16'hfe56;
        exp_re[194] = 16'hff84; exp_im[194] = 16'hfe27;
        exp_re[195] = 16'h024a; exp_im[195] = 16'hff9c;
        exp_re[196] = 16'hfd0e; exp_im[196] = 16'h016a;
        exp_re[197] = 16'h00d3; exp_im[197] = 16'h01f6;
        exp_re[198] = 16'hfd97; exp_im[198] = 16'h00c4;
        exp_re[199] = 16'h0287; exp_im[199] = 16'hfee4;
        exp_re[200] = 16'hfed4; exp_im[200] = 16'hfe00;
        exp_re[201] = 16'h0266; exp_im[201] = 16'hfee4;
        exp_re[202] = 16'hfdc5; exp_im[202] = 16'h00c4;
        exp_re[203] = 16'h0182; exp_im[203] = 16'h01f6;
        exp_re[204] = 16'hfdb8; exp_im[204] = 16'h016a;
        exp_re[205] = 16'h020f; exp_im[205] = 16'hff9c;
        exp_re[206] = 16'hfe2f; exp_im[206] = 16'hfe27;
        exp_re[207] = 16'h0215; exp_im[207] = 16'hfe56;
        exp_re[208] = 16'hfe00; exp_im[208] = 16'h0000;
        exp_re[209] = 16'h0215; exp_im[209] = 16'h01aa;
        exp_re[210] = 16'hfe2f; exp_im[210] = 16'h01d9;
        exp_re[211] = 16'h020f; exp_im[211] = 16'h0064;
        exp_re[212] = 16'hfdb8; exp_im[212] = 16'hfe96;
        exp_re[213] = 16'h0182; exp_im[213] = 16'hfe0a;
        exp_re[214] = 16'hfdc5; exp_im[214] = 16'hff3c;
        exp_re[215] = 16'h0266; exp_im[215] = 16'h011c;
        exp_re[216] = 16'hfed4; exp_im[216] = 16'h0200;
        exp_re[217] = 16'h0287; exp_im[217] = 16'h011c;
        exp_re[218] = 16'hfd97; exp_im[218] = 16'hff3c;
        exp_re[219] = 16'h00d3; exp_im[219] = 16'hfe0a;
        exp_re[220] = 16'hfd0e; exp_im[220] = 16'hfe96;
        exp_re[221] = 16'h024a; exp_im[221] = 16'h0064;
        exp_re[222] = 16'hff84; exp_im[222] = 16'h01d9;
        exp_re[223] = 16'h0382; exp_im[223] = 16'h01aa;
        exp_re[224] = 16'hfe00; exp_im[224] = 16'h0000;
        exp_re[225] = 16'h002a; exp_im[225] = 16'hfe56;
        exp_re[226] = 16'hfbc0; exp_im[226] = 16'hfe27;
        exp_re[227] = 16'h0179; exp_im[227] = 16'hff9c;
        exp_re[228] = 16'h001e; exp_im[228] = 16'h016a;
        exp_re[229] = 16'h0546; exp_im[229] = 16'h01f6;
        exp_re[230] = 16'hff6f; exp_im[230] = 16'h00c4;
        exp_re[231] = 16'hffa7; exp_im[231] = 16'hfee4;
        exp_re[232] = 16'hf92c; exp_im[232] = 16'hfe00;
        exp_re[233] = 16'hfee5; exp_im[233] = 16'hfee4;
        exp_re[234] = 16'h0086; exp_im[234] = 16'h00c4;
        exp_re[235] = 16'h09d5; exp_im[235] = 16'h01f6;
        exp_re[236] = 16'h051c; exp_im[236] = 16'h016a;
        exp_re[237] = 16'hff5f; exp_im[237] = 16'hff9c;
        exp_re[238] = 16'heb3d; exp_im[238] = 16'hfe27;
        exp_re[239] = 16'he026; exp_im[239] = 16'hfe56;
        exp_re[240] = 16'h0000; exp_im[240] = 16'h04d4;
        exp_re[241] = 16'hfdd9; exp_im[241] = 16'h02aa;
        exp_re[242] = 16'h0312; exp_im[242] = 16'h0242;
        exp_re[243] = 16'h025c; exp_im[243] = 16'hfac1;
        exp_re[244] = 16'h0388; exp_im[244] = 16'hfc4e;
        exp_re[245] = 16'heb2b; exp_im[245] = 16'h0a0f;
        exp_re[246] = 16'h1064; exp_im[246] = 16'hf58a;
        exp_re[247] = 16'h0178; exp_im[247] = 16'hfff6;
        exp_re[248] = 16'h0000; exp_im[248] = 16'h07a8;
        exp_re[249] = 16'hfc29; exp_im[249] = 16'h02bb;
        exp_re[250] = 16'hff73; exp_im[250] = 16'hff3b;
        exp_re[251] = 16'hfd4b; exp_im[251] = 16'hf761;
        exp_re[252] = 16'h0115; exp_im[252] = 16'hfb63;
        exp_re[253] = 16'h00a3; exp_im[253] = 16'h00c4;
        exp_re[254] = 16'h07f3; exp_im[254] = 16'h0ee8;
        exp_re[255] = 16'h0a9a; exp_im[255] = 16'h1470;
        exp_re[256] = 16'hdb17; exp_im[256] = 16'hcd17;
        exp_re[257] = 16'h0dcc; exp_im[257] = 16'h100e;
        exp_re[258] = 16'h0b63; exp_im[258] = 16'h0a4d;
        exp_re[259] = 16'h0115; exp_im[259] = 16'h0078;
        exp_re[260] = 16'hfe00; exp_im[260] = 16'h0000;
        exp_re[261] = 16'hf97b; exp_im[261] = 16'hfca8;
        exp_re[262] = 16'hfeae; exp_im[262] = 16'hff8f;
        exp_re[263] = 16'hffad; exp_im[263] = 16'hfc76;
        exp_re[264] = 16'h04d4; exp_im[264] = 16'h0000;
        exp_re[265] = 16'h01b1; exp_im[265] = 16'h01a4;
        exp_re[266] = 16'h037c; exp_im[266] = 16'h132a;
        exp_re[267] = 16'hf88a; exp_im[267] = 16'he5db;
        exp_re[268] = 16'hfeeb; exp_im[268] = 16'h049d;
        exp_re[269] = 16'hfeaa; exp_im[269] = 16'h0474;
        exp_re[270] = 16'h03d5; exp_im[270] = 16'h041f;
        exp_re[271] = 16'h0196; exp_im[271] = 16'hfcf7;
        exp_re[272] = 16'h02d4; exp_im[272] = 16'hfe00;
        exp_re[273] = 16'hfd34; exp_im[273] = 16'hfd17;
        exp_re[274] = 16'hfdaa; exp_im[274] = 16'h03b4;
        exp_re[275] = 16'hfa6d; exp_im[275] = 16'h0323;
        exp_re[276] = 16'h0078; exp_im[276] = 16'h03b2;
        exp_re[277] = 16'h134b; exp_im[277] = 16'heedb;
        exp_re[278] = 16'hf2cc; exp_im[278] = 16'h0b7c;
        exp_re[279] = 16'hfb6c; exp_im[279] = 16'h0013;
        exp_re[280] = 16'h02d4; exp_im[280] = 16'h00d4;
        exp_re[281] = 16'h015b; exp_im[281] = 16'hfded;
        exp_re[282] = 16'h02d7; exp_im[282] = 16'h00e5;
        exp_re[283] = 16'hfd77; exp_im[283] = 16'hfdd4;
        exp_re[284] = 16'hfeeb; exp_im[284] = 16'h009d;
        exp_re[285] = 16'hfdcd; exp_im[285] = 16'hfec6;
        exp_re[286] = 16'h0567; exp_im[286] = 16'h03ac;
        exp_re[287] = 16'h0819; exp_im[287] = 16'h02f7;
        exp_re[288] = 16'he984; exp_im[288] = 16'hf784;
        exp_re[289] = 16'h099b; exp_im[289] = 16'h02a5;
        exp_re[290] = 16'h0731; exp_im[290] = 16'h030d;
        exp_re[291] = 16'hfe75; exp_im[291] = 16'hfdf9;
        exp_re[292] = 16'hfe00; exp_im[292] = 16'h0000;
        exp_re[293] = 16'hfbba; exp_im[293] = 16'hfe1a;
        exp_re[294] = 16'h0172; exp_im[294] = 16'h02bb;
        exp_re[295] = 16'h00fb; exp_im[295] = 16'h010e;
        exp_re[296] = 16'h03a8; exp_im[296] = 16'h02d4;
        exp_re[297] = 16'hfe57; exp_im[297] = 16'hfb40;
        exp_re[298] = 16'hfd8a; exp_im[298] = 16'hf006;
        exp_re[299] = 16'h0060; exp_im[299] = 16'h189b;
        exp_re[300] = 16'h0115; exp_im[300] = 16'hff63;
        exp_re[301] = 16'hff3a; exp_im[301] = 16'hf856;
        exp_re[302] = 16'h0221; exp_im[302] = 16'hfc9d;
        exp_re[303] = 16'hfe2b; exp_im[303] = 16'hfe16;
        exp_re[304] = 16'h0000; exp_im[304] = 16'h04d4;
        exp_re[305] = 16'hfdd9; exp_im[305] = 16'h02aa;
        exp_re[306] = 16'h0312; exp_im[306] = 16'h0242;
        exp_re[307] = 16'h025c; exp_im[307] = 16'hfac1;
        exp_re[308] = 16'h0388; exp_im[308] = 16'hfc4e;
        exp_re[309] = 16'heb2b; exp_im[309] = 16'h0a0f;
        exp_re[310] = 16'h1064; exp_im[310] = 16'hf58a;
        exp_re[311] = 16'h0178; exp_im[311] = 16'hfff6;
        exp_re[312] = 16'h0000; exp_im[312] = 16'h07a8;
        exp_re[313] = 16'hfc29; exp_im[313] = 16'h02bb;
        exp_re[314] = 16'hff73; exp_im[314] = 16'hff3b;
        exp_re[315] = 16'hfd4b; exp_im[315] = 16'hf761;
        exp_re[316] = 16'h0115; exp_im[316] = 16'hfb63;
        exp_re[317] = 16'h00a3; exp_im[317] = 16'h00c4;
        exp_re[318] = 16'h07f3; exp_im[318] = 16'h0ee8;
        exp_re[319] = 16'h0a9a; exp_im[319] = 16'h1470;

        repeat (5) @(negedge clk);
        rst <= 1'b1;
        repeat (5) @(negedge clk);
        rst <= 1'b0;

        waited = 0;
        while (frames_seen < 1 && waited < 2000) begin
            @(negedge clk); waited = waited + 1;
        end

        if (frames_seen != 1) begin
            $display("  [FAIL] frame_done never asserted (waited %0d cycles)", waited);
            error_count = error_count + 1;
        end else begin
            $display("  frame_done asserted after %0d cycles", waited);
        end

        if (start_pulses != 4) begin
            $display("  [FAIL] symbol_start pulsed %0d times, expected 4", start_pulses);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] symbol_start pulsed 4 times (one per symbol)");
        end

        // By frame_done every symbol's 64 IFFT samples must have landed.
        if (ifft_at_framedone != 256) begin
            $display("  [FAIL] %0d IFFT samples by frame_done, expected exactly 256", ifft_at_framedone);
            error_count = error_count + 1;
        end else begin
            $display("  [PASS] exactly 256 IFFT samples (4 symbols x 64) by frame_done");
        end

        max_err = 0;
        for (n = 0; n < 320; n = n + 1) begin
            dr = $signed(ofdm_frame[n*32+16 +: 16]) - $signed(exp_re[n]);
            if (dr < 0) dr = -dr;
            if (dr > max_err) max_err = dr;
            if (dr > TOLERANCE) begin
                $display("  [FAIL] sample %0d re exp=%0d act=%0d diff=%0d", n, $signed(exp_re[n]), $signed(ofdm_frame[n*32+16 +: 16]), dr);
                error_count = error_count + 1;
            end
            di = $signed(ofdm_frame[n*32 +: 16]) - $signed(exp_im[n]);
            if (di < 0) di = -di;
            if (di > max_err) max_err = di;
            if (di > TOLERANCE) begin
                $display("  [FAIL] sample %0d im exp=%0d act=%0d diff=%0d", n, $signed(exp_im[n]), $signed(ofdm_frame[n*32 +: 16]), di);
                error_count = error_count + 1;
            end
        end
        if (max_err <= TOLERANCE)
            $display("  [PASS] all 320 frame samples match C++ golden (max err %0d LSB)", max_err);
        else
            $display("  [FAIL] frame mismatch, max err %0d LSB", max_err);

        $display("");
        if (error_count == 0) $display("ALL OFDM FRAME TESTS PASSED");
        else             $display("%0d ERROR(S)", error_count);
        $finish;
    end
endmodule
