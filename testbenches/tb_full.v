`timescale 1ns / 1ps

// Self-checking testbench for ofdm_generate_frame (full.v).
//
// This is deliberately independent of testbenches/tb_ofdm_frame.v: that one
// checks against a *generated table* of absolute values, while this one
// computes the golden IFFT live in real arithmetic from first principles, and
// drives a pseudo-random payload rather than all-ones. Agreement between the
// two is what makes the end-to-end result trustworthy.
//
// Checks, per symbol:
//   - no X/Z bits in the frame slot
//   - each body sample against a live 64-point IFFT with 1/64 scaling (Q1.15)
//   - the 16 cyclic-prefix samples equal the 16 samples they were copied from
//
// Symbol 0 is the Zernkor Chu sequence, so the golden model reads the expected
// values out of the DUT via the hierarchical handle dut.zc_seq_cplx. That is a
// deliberate coupling: if the ZC ROM or its index logic changes, this
// testbench must be revisited, otherwise it keeps validating against the old
// sequence.

module tb_full;

    localparam SC          = 64;
    localparam N_SYMBOLS   = 4;
    localparam SYMBOL_LEN  = 80;
    localparam CP          = 16;
    localparam GUARD       = 10;     // must match full.v GUARD_COUNT
    localparam DC          = 32;     // must match full.v DC_INDEX
    localparam TOL         = 32;     // absorbs radix-2^2 per-stage truncation
    localparam TIMEOUT     = 6000;   // clock cycles
    localparam real PI     = 3.14159265358979;
    localparam real ONE_V  = 32767.0 / 32768.0;
    localparam real QP     = 23170.0 / 32768.0;   // = 16'sh5A82, as used by the RTL

    reg                                  clk = 0;
    reg                                  rst = 1;
    reg  [2*SC-1:0]                      qpsk_bits;
    wire [N_SYMBOLS*SYMBOL_LEN*32-1:0]   ofdm_frame;
    wire                                 frame_done;

    ofdm_generate_frame dut (
        .clk        (clk),
        .rst        (rst),
        .qpsk_bits  (qpsk_bits),
        .ofdm_frame (ofdm_frame),
        .frame_done (frame_done)
    );

    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Golden model storage
    // ------------------------------------------------------------------
    real sub_re [0:SC-1];
    real sub_im [0:SC-1];
    real exp_re [0:SC-1];       // expected time-domain body, in LSBs
    real exp_im [0:SC-1];

    integer error_count = 0;
    integer cycles;
    integer s, j, k, n;
    real    th, acc_re, acc_im, err_re, err_im, max_err;
    reg [31:0] w, w2;
    reg [31:0] zw;
    reg        ib, qb;

    // Expected subcarrier values for symbol index sy, mirroring full.v's
    // guard/DC -> sync -> reference -> pilot -> header -> payload ordering.
    task build_subcarriers;
        input integer sy;
        integer kk;
        begin
            for (kk = 0; kk < SC; kk = kk + 1) begin
                if (kk == DC || kk < GUARD || kk >= SC - GUARD) begin
                    sub_re[kk] = 0.0;
                    sub_im[kk] = 0.0;
                end else if (sy == 0) begin
                    zw = dut.zc_seq_cplx[kk*32 +: 32];
                    sub_re[kk] = $itor($signed(zw[31:16])) / 32768.0;
                    sub_im[kk] = $itor($signed(zw[15:0]))  / 32768.0;
                end else if (sy == 1) begin
                    sub_re[kk] = ONE_V;              // all-ones reference
                    sub_im[kk] = 0.0;
                end else if (((kk - (GUARD - 1)) % 6) == 0) begin
                    sub_re[kk] = ONE_V;              // pilot
                    sub_im[kk] = 0.0;
                end else if (sy == 2) begin
                    sub_re[kk] = ONE_V;              // header
                    sub_im[kk] = 0.0;
                end else begin
                    ib = qpsk_bits[2*kk];
                    qb = qpsk_bits[2*kk+1];
                    sub_re[kk] = ib ? -QP : QP;
                    sub_im[kk] = qb ? -QP : QP;
                end
            end
        end
    endtask

    // Ideal IFFT with 1/N scaling, result in LSBs
    task golden_ifft;
        integer nn, kk;
        begin
            for (nn = 0; nn < SC; nn = nn + 1) begin
                acc_re = 0.0;
                acc_im = 0.0;
                for (kk = 0; kk < SC; kk = kk + 1) begin
                    th     = 2.0 * PI * kk * nn / 64.0;
                    acc_re = acc_re + sub_re[kk]*$cos(th) - sub_im[kk]*$sin(th);
                    acc_im = acc_im + sub_re[kk]*$sin(th) + sub_im[kk]*$cos(th);
                end
                exp_re[nn] = acc_re / 64.0 * 32768.0;
                exp_im[nn] = acc_im / 64.0 * 32768.0;
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Stimulus and checking
    // ------------------------------------------------------------------
    initial begin
        // Pseudo-random but fixed payload bits
        qpsk_bits = 128'hA5C3_0F1E_9B47_D268_3C5A_E1F0_7788_B2D4;

        repeat (4) @(posedge clk);
        rst = 1'b0;

        cycles = 0;
        while (!frame_done && cycles < TIMEOUT) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (!frame_done) begin
            $display("[FAIL] frame_done never asserted within %0d cycles", TIMEOUT);
            $display("       probe: u_p2s.start, p2s_do_en, u_ifft.fft_do_en, s2p_frame_done");
            $display("   ALL OFDM GENERATE_FRAME TESTS FAILED");
            $finish;
        end
        $display("[INFO] frame_done after %0d cycles", cycles);

        for (s = 0; s < N_SYMBOLS; s = s + 1) begin
            if (^ofdm_frame[s*SYMBOL_LEN*32 +: SYMBOL_LEN*32] === 1'bx) begin
                $display("[FAIL] symbol %0d contains X/Z bits", s);
                error_count = error_count + 1;
            end else begin
                build_subcarriers(s);
                golden_ifft;
                max_err = 0.0;

                // Body vs golden IFFT
                for (j = CP; j < SYMBOL_LEN; j = j + 1) begin
                    n  = j - CP;
                    w  = ofdm_frame[(s*SYMBOL_LEN + j)*32 +: 32];
                    err_re = $itor($signed(w[31:16])) - exp_re[n];
                    err_im = $itor($signed(w[15:0]))  - exp_im[n];
                    if (err_re < 0.0) err_re = -err_re;
                    if (err_im < 0.0) err_im = -err_im;
                    if (err_re > max_err) max_err = err_re;
                    if (err_im > max_err) max_err = err_im;
                    if (err_re > TOL || err_im > TOL) begin
                        if (error_count < 40)
                            $display("[FAIL] sym %0d n=%2d got %0d%+0dj exp %0.1f%+0.1dj",
                                     s, n, $signed(w[31:16]), $signed(w[15:0]),
                                     exp_re[n], exp_im[n]);
                        error_count = error_count + 1;
                    end
                end
                $display("[PASS] symbol %0d body max error = %0.1f LSB (tol %0d)",
                         s, max_err, TOL);

                // Cyclic prefix: CP[j] must equal the body sample it was copied
                // from. Body sample j sits at word SYMBOL_LEN + j, so the match
                // is at word j + SC.
                for (j = 0; j < CP; j = j + 1) begin
                    w  = ofdm_frame[(s*SYMBOL_LEN + j)*32 +: 32];
                    w2 = ofdm_frame[(s*SYMBOL_LEN + j + SC)*32 +: 32];
                    if (w !== w2) begin
                        $display("[FAIL] sym %0d CP[%0d]=%h != body[%0d]=%h", s, j, w, j, w2);
                        error_count = error_count + 1;
                    end
                end
                $display("[PASS] symbol %0d cyclic prefix exact", s);
            end
        end

        $display("========================================");
        if (error_count == 0) $display("   ALL OFDM GENERATE_FRAME TESTS PASSED");
        else                  $display("   ALL OFDM GENERATE_FRAME TESTS FAILED: %0d error(s)",
                                         error_count);
        $display("========================================");
        $finish;
    end

    // Overall watchdog
    initial begin
        #(10 * (TIMEOUT + 100));
        $display("[FAIL] global timeout");
        $display("   ALL OFDM GENERATE_FRAME TESTS FAILED");
        $finish;
    end

endmodule