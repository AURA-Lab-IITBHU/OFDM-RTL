`timescale 1ns / 1ps

// Structural mirror of ofdm_hls.cc.cpp -- stage order matches the C++ top:
//   generate_zc_sequence -> generate_qpsk_symbols -> map_to_subcarriers
//   -> ifft -> add_cp -> add_to_frame -> generate_frame
//
// Complex datapath: 32-bit per subcarrier (16 re + 16 im Q1.15)

`include "src/zc_seq.v"
`include "src/qpsk_signal.v"
`include "src/qpsk_signal_128.v"
`include "src/qpsk.v"
`include "src/map_to_subcarriers.v"
`include "src/parallel_to_serial.v"
`include "src/ifft_64.v"
`include "src/serial_to_parallel.v"
`include "src/add_cp.v"
`include "src/uart_rx.v"

// ---------------------------------------------------------------------------
// Top level: equivalent to generate_frame() in the C++ reference.
// Processes one frame (N_SYMBOLS symbols) at a time, then loops.
// Pipeline latency ~267 cycles per symbol. Symbols are processed
// sequentially within a frame.
// ---------------------------------------------------------------------------
module ofdm_generate_frame #(
    parameter SUBCARRIER_COUNT = 64,
    parameter GUARD_COUNT      = 10,
    parameter DC_INDEX         = 32,
    parameter DATA_WIDTH       = 16,
    parameter N_SYMBOLS        = 4,
    parameter SYMBOL_LEN       = 80,
    parameter CP_LENGTH        = 16,
    parameter COMPLEX_WIDTH    = 32
)(
    input  wire                              clk,
    input  wire                              rst,
    input  wire [2*SUBCARRIER_COUNT-1:0]     qpsk_bits,
    output reg  [N_SYMBOLS*SYMBOL_LEN*32-1:0] ofdm_frame,
    output reg                               frame_done
);

    localparam IDLE = 2'b00, RUN = 2'b01, WAIT = 2'b10;
    reg [1:0] state;

    // --- generate_zc_sequence -------------------------------------------
    wire [DATA_WIDTH-1:0] zc_seq_re [0:SUBCARRIER_COUNT-1];
    wire [DATA_WIDTH-1:0] zc_seq_im [0:SUBCARRIER_COUNT-1];

    zc_sequence_generator #(
        .SUB_COUNT  (SUBCARRIER_COUNT),
        .GUARD_COUNT(GUARD_COUNT),
        .DC_INDEX   (DC_INDEX),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_zc_seq (
        .zc_seq_re(zc_seq_re),
        .zc_seq_im(zc_seq_im)
    );

    wire [SUBCARRIER_COUNT*32-1:0] zc_seq_cplx;
    genvar g;
    generate
        for (g = 0; g < SUBCARRIER_COUNT; g = g + 1) begin : pack_zc
            assign zc_seq_cplx[g*32 +: 32] = {zc_seq_re[g], zc_seq_im[g]};
        end
    endgenerate

    // --- generate_qpsk_symbols ------------------------------------------
    wire [1023:0] qpsk_i;
    wire [1023:0] qpsk_q;

    qpsk_signal_128 u_qpsk (
        .clk(clk),
        .in (qpsk_bits),
        .I  (qpsk_i),
        .Q  (qpsk_q)
    );

    wire [SUBCARRIER_COUNT*32-1:0] qpsk_symbol_cplx;
    genvar q;
    generate
        for (q = 0; q < SUBCARRIER_COUNT; q = q + 1) begin : pack_qpsk
            assign qpsk_symbol_cplx[q*32 +: 32] = {qpsk_i[q*16 +: 16], qpsk_q[q*16 +: 16]};
        end
    endgenerate

    // --- symbol control --------------------------------------------------
    reg [$clog2(N_SYMBOLS):0] sym_idx;  // extra bit for overflow detection
    reg                       symbol_start;
    reg                       start_sent;
    reg                       next_symbol_start;
    reg                       frame_active;
    wire                      symbol_done;  // s2p_frame_done delayed by add_cp

    // --- map_to_subcarriers ----------------------------------------------
    // Reset with rst only. symbol_start must NOT reset the mapper: it is the
    // same edge on which p2s reads sample 0, and clearing would zero it.
    wire                       map_rst = rst;
    wire                       map_sync, map_ref, map_hdr;
    wire [SUBCARRIER_COUNT*32-1:0] subcarriers;

    assign map_sync = (sym_idx == 0);
    assign map_ref  = (sym_idx == 1);
    assign map_hdr  = (sym_idx == 2);

    parameterized_map_to_subcarriers #(
        .SUBCARRIER_COUNT(SUBCARRIER_COUNT),
        .GUARD_COUNT     (GUARD_COUNT),
        .DC              (DC_INDEX),
        .LAST_GUARD_INDEX(GUARD_COUNT - 1),
        .DATA_WIDTH      (16)
    ) u_map (
        .clk         (clk),
        .rst         (map_rst),
        .sync        (map_sync),
        .ref_sym     (map_ref),
        .header      (map_hdr),
        .zc_seq      (zc_seq_cplx),
        .qpsk_symbol (qpsk_symbol_cplx),
        .subcarriers (subcarriers)
    );

    // --- parallel_to_serial ----------------------------------------------
    wire                          p2s_do_en;
    wire [15:0]                   p2s_do_re;
    wire [15:0]                   p2s_do_im;
    wire                          p2s_frame_done;

    parallel_to_serial #(.N(SUBCARRIER_COUNT), .WIDTH(16)) u_p2s (
        .clk           (clk),
        .rst           (rst),
        .start         (symbol_start),
        .parallel_data (subcarriers),
        .do_en         (p2s_do_en),
        .do_re         (p2s_do_re),
        .do_im         (p2s_do_im),
        .frame_done    (p2s_frame_done)
    );

    // --- ifft_64 ---------------------------------------------------------
    wire                          ifft_do_en;
    wire [15:0]                   ifft_do_re;
    wire [15:0]                   ifft_do_im;

    ifft_64 #(.WIDTH(16)) u_ifft (
        .clk   (clk),
        .rst   (rst),
        .di_en (p2s_do_en),
        .di_re (p2s_do_re),
        .di_im (p2s_do_im),
        .do_en (ifft_do_en),
        .do_re (ifft_do_re),
        .do_im (ifft_do_im)
    );

    // --- serial_to_parallel ----------------------------------------------
    wire                          s2p_frame_done;
    wire [SUBCARRIER_COUNT*32-1:0] ifft_parallel;

    serial_to_parallel #(.N(SUBCARRIER_COUNT), .WIDTH(16)) u_s2p (
        .clk           (clk),
        .rst           (rst),
        .di_en         (ifft_do_en),
        .di_re         (ifft_do_re),
        .di_im         (ifft_do_im),
        .frame_done    (s2p_frame_done),
        .parallel_data (ifft_parallel)
    );

    // --- add_cp ----------------------------------------------------------
    wire [SYMBOL_LEN*32-1:0] ofdm_symbol_cp;

    parameterized_add_cp #(
        .SYMBOL_LEN      (SYMBOL_LEN),
        .SUBCARRIER_COUNT(SUBCARRIER_COUNT),
        .CP_LENGTH       (CP_LENGTH)
    ) u_add_cp (
        .clk           (clk),
        .rst           (rst),
        .ofdm_symbol   (ifft_parallel),
        .ofdm_symbol_cp(ofdm_symbol_cp)
    );

    // symbol_done is s2p_frame_done delayed by 1 cycle for add_cp
    reg s2p_frame_done_d;
    always @(posedge clk or posedge rst) begin
        if (rst) s2p_frame_done_d <= 1'b0;
        else     s2p_frame_done_d <= s2p_frame_done;
    end
    assign symbol_done = s2p_frame_done_d;

    // --- add_to_frame / frame control ------------------------------------
    // Symbol latency: p2s(64) + ifft(71+64) + s2p(64) + add_cp(1) = 264
    //
    // Launch timing, relative to the edge (E) that increments sym_idx:
    //   E   : sym_idx changes; mapper still drives the OLD symbol
    //   E+1 : mapper registers the NEW symbol into subcarriers
    //   E+2 : symbol_start is seen by p2s, which reads valid subcarriers
    // start_sent guarantees symbol 0 is launched exactly once per frame.

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state              <= IDLE;
            sym_idx            <= 0;
            symbol_start       <= 1'b0;
            start_sent         <= 1'b0;
            next_symbol_start  <= 1'b0;
            frame_active       <= 1'b0;
            frame_done         <= 1'b0;
        end else begin
            symbol_start <= 1'b0;

            case (state)
                IDLE: begin
                    if (!frame_active) begin
                        frame_active <= 1'b1;
                        sym_idx      <= 0;
                        start_sent   <= 1'b0;
                        frame_done   <= 1'b0;
                        state        <= RUN;
                    end
                end

                RUN: begin
                    // First symbol: one pulse only
                    if (!start_sent) begin
                        symbol_start <= 1'b1;
                        start_sent   <= 1'b1;
                    end else if (next_symbol_start) begin
                        symbol_start      <= 1'b1;
                        next_symbol_start <= 1'b0;
                    end

                    if (symbol_done) begin
                        // add_cp registered ofdm_symbol_cp on this same edge,
                        // so the slot is safe to write now.
                        ofdm_frame[sym_idx*SYMBOL_LEN*32 +: SYMBOL_LEN*32] <= ofdm_symbol_cp;
                        sym_idx <= sym_idx + 1;

                        if (sym_idx == N_SYMBOLS - 1) begin
                            state        <= IDLE;
                            frame_active <= 1'b0;
                            frame_done   <= 1'b1;
                        end else begin
                            next_symbol_start <= 1'b1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule


// ===========================================================================
// GAPS -- stages present in ofdm_hls.cc.cpp but not implemented here
// ===========================================================================
//
// 1. IFFT -- IMPLEMENTED via r22sdf radix-2^2 FFT core
//    Uses FFT64 with input/output conjugation and bit-reversal buffer.
//    Latency ~137 cycles. Output is natural order, scaled by 1/N.
//
// 2. generate_qpsk_symbols() -- IMPLEMENTED
//    qpsk_signal_128 instantiated, drives map_to_subcarriers.
//    C++ masks payload before mapping; RTL does masking in map_to_subcarriers.
//
// 3. add_to_frame() as a separate module
//    Folded into this file as indexed part-select with pipeline delay register.
//
// Data width: 32-bit per subcarrier (16 re + 16 im Q1.15), matching C++
// complex_fixed type. All C++ stages now have RTL counterparts.
// ===========================================================================