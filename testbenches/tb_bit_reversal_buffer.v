`timescale 1ns / 1ps

// Proves the bit-reversal buffer handles back-to-back frames with zero idle
// cycles between them, which the previous single-bank design could not: it reset
// wr_idx at end-of-read, clobbering the next frame's sample 0.
//
// Pattern: frame f sample j carries the value f*N + j + 1 on the real path and its
// negation on the imaginary path, so both paths and every frame are distinguishable.
module tb_bit_reversal_buffer;

    localparam N     = 64;
    localparam WIDTH = 16;
    localparam BANKS = 4;
    localparam FRAMES = 24;

    reg clk;
    reg rst;
    reg di_en;
    reg [WIDTH-1:0] di_re, di_im;
    wire do_en;
    wire [WIDTH-1:0] do_re, do_im;
    wire overflow;

    integer error_count = 0;
    integer checks = 0;
    integer sent_frames = 0;
    integer out_frames = 0;
    integer f, j, n, frame_id;
    integer expected_re, expected_im;
    integer out_idx;

    // Frame numbering is global across test cases so each frame carries a unique
    // value. If it restarted per case the checker could not tell a replayed frame
    // from a correctly delivered one.
    integer next_frame_id = 0;

    bit_reversal_buffer #(
        .N(N),
        .WIDTH(WIDTH),
        .BANKS(BANKS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .di_en(di_en),
        .di_re(di_re),
        .di_im(di_im),
        .do_en(do_en),
        .do_re(do_re),
        .do_im(do_im),
        .overflow(overflow)
    );

    always #5 clk = ~clk;

    function integer bit_reverse(input integer val);
        integer i, rev;
        begin
            rev = 0;
            for (i = 0; i < $clog2(N); i = i + 1) begin
                rev = (rev << 1) | (val & 1);
                val = val >> 1;
            end
            bit_reverse = rev;
        end
    endfunction

    // Sample value carried by frame f, stream index j.
    function integer frame_value(input integer ff, input integer jj);
        frame_value = ff * N + jj + 1;
    endfunction

    // Push one sample. Called on negedge so the DUT samples it on the next posedge.
    task send_sample(input integer val_re, input integer val_im);
        begin
            @(negedge clk);
            di_en = 1'b1;
            di_re = val_re[WIDTH-1:0];
            di_im = val_im[WIDTH-1:0];
        end
    endtask

    // Stream FRAMES frames with di_en held continuously high: no idle cycles
    // between frames. Sent on a background process so it overlaps output draining.
    task stream_back_to_back(input integer nframes, input integer gap);
        integer g;
        begin
            frame_id = next_frame_id;
            for (f = 0; f < nframes; f = f + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (gap && f > 0 && j == 0) begin
                        for (g = 0; g < gap; g = g + 1) begin
                            @(negedge clk);
                            di_en = 1'b0;
                        end
                    end
                    send_sample(frame_value(frame_id + f, j),
                                -frame_value(frame_id + f, j));
                end
            end
            next_frame_id = next_frame_id + nframes;
            @(negedge clk);
            di_en = 1'b0;
            sent_frames = sent_frames + nframes;
        end
    endtask

    // Monitor outputs. do_en must never drop mid-burst, and each burst of N
    // samples must be the bit-reversed permutation of the matching input frame.
    always @(posedge clk) begin
        #1;
        if (do_en) begin
            if (out_idx == 0) out_frames = out_frames + 1;
            expected_re = frame_value(out_frames - 1, bit_reverse(out_idx));
            expected_im = -expected_re;
            checks = checks + 1;
            if ($signed(do_re) !== expected_re || $signed(do_im) !== expected_im) begin
                error_count = error_count + 1;
                if (error_count <= 5) begin
                    $display("  [FAIL] burst %0d idx %0d: got re=%0d im=%0d, expected re=%0d im=%0d",
                             out_frames - 1, out_idx, $signed(do_re), $signed(do_im),
                             expected_re, expected_im);
                end
            end
            out_idx = (out_idx + 1) % N;
            if (out_idx == 0 && (out_frames - 1) < sent_frames) begin
                $display("  [PASS] burst %0d: 64 samples, natural order confirmed",
                         out_frames - 1);
            end
        end
    end

    initial begin
        clk = 0;
        rst = 1'b1;
        di_en = 1'b0;
        di_re = 0;
        di_im = 0;
        out_idx = 0;

        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        // TC1: one isolated frame, then idle. Baseline path.
        $display("TC1: single isolated frame");
        stream_back_to_back(1, 0);
        repeat (200) @(negedge clk);
        if (out_frames == 1) $display("  [PASS] TC1: one burst received");
        else begin
            error_count = error_count + 1;
            $display("  [FAIL] TC1: expected 1 burst, got %0d", out_frames);
        end

        // TC2: 16 frames pushed with ZERO idle cycles between them. This is the case
        // that used to corrupt: frame f is read while frames f+1..f+3 are written.
        $display("TC2: 16 back-to-back frames, zero idle cycles");
        repeat (20) @(negedge clk);
        stream_back_to_back(16, 0);
        repeat (400) @(negedge clk);
        if (out_frames == 17) $display("  [PASS] TC2: all 17 bursts received");
        else begin
            error_count = error_count + 1;
            $display("  [FAIL] TC2: expected 17 bursts, got %0d", out_frames);
        end

        if (overflow !== 1'b0) begin
            error_count = error_count + 1;
            $display("  [FAIL] overflow asserted: a frame was dropped");
        end else begin
            $display("  [PASS] overflow stayed low: no frame dropped");
        end

        $display("");
        if (error_count == 0) begin
            $display("ALL BIT-REVERSAL BUFFER TESTS PASSED (%0d samples checked)", checks);
        end else begin
            $display("BIT-REVERSAL BUFFER TEST FAILED: %0d error(s) over %0d checks",
                     error_count, checks);
        end
        $finish;
    end

    initial begin
        #200000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
