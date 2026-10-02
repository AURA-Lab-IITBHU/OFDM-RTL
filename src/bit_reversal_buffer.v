`timescale 1ns / 1ps

`ifndef BIT_REVERSAL_BUFFER_V
`define BIT_REVERSAL_BUFFER_V


// Bit-reversal buffer: takes N samples in bit-reversed order, outputs in natural order.
//
// Stream sample j arrives bit-reversed, so it is stored at buf[bit_reverse(j)] and
// read back sequentially from 0 to N-1, which yields natural order. bit_reverse is
// an involution, so output[n] == input[bit_reverse(n)].
//
// The buffer is a frame FIFO of BANKS independent banks. A single-bank design cannot
// tolerate back-to-back frames: end-of-read reset the write pointer, clobbering the
// next frame's sample 0, and read/write of the same slot would corrupt data anyway.
// With BANKS banks the write side may run ahead of the read side by BANKS-1 whole
// frames, so consecutive symbols can be pushed with zero idle cycles between them.
//
// The read side drains at most one sample per cycle, i.e. exactly the rate the write
// side accepts, so in steady state it never falls more than one frame behind and
// BANKS=2 is enough to stream with zero idle cycles. BANKS=4 is the default to give
// margin for a consumer that stalls.
//
// BANKS need not be a power of two; the bank pointers wrap by explicit comparison
// rather than by pointer width, which would round up to the next power of two and
// alias onto banks the occupancy guard does not know about.
module bit_reversal_buffer #(
    parameter N     = 64,
    parameter WIDTH = 16,
    parameter BANKS = 4
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   di_en,     // Input sample valid
    input  wire [WIDTH-1:0]       di_re,     // Input real
    input  wire [WIDTH-1:0]       di_im,     // Input imag
    output wire                   do_en,     // Output sample valid
    output wire [WIDTH-1:0]       do_re,     // Output real
    output wire [WIDTH-1:0]       do_im,     // Output imag
    output reg                    overflow   // sticky: a frame was dropped, data lost
);

    localparam LOGN = $clog2(N);
    localparam LBK  = $clog2(BANKS);
    localparam LCNT = $clog2(BANKS + 1);

    reg [WIDTH-1:0] buf_re [0:BANKS*N-1];
    reg [WIDTH-1:0] buf_im [0:BANKS*N-1];
    reg [LBK-1:0]  wr_bank;      // bank being written
    reg [LBK-1:0]  rd_bank;      // bank holding the oldest complete frame
    reg [LOGN-1:0] wr_idx;
    reg [LOGN-1:0] rd_idx;
    reg [LCNT-1:0] full;         // complete frames available to read
    reg             do_en_reg;

    function integer bit_reverse(input integer val);
        integer i, rev;
        begin
            rev = 0;
            for (i = 0; i < LOGN; i = i + 1) begin
                rev = (rev << 1) | (val & 1);
                val = val >> 1;
            end
            bit_reverse = rev;
        end
    endfunction

    // Frame boundary events, shared by the pointer and occupancy logic so they can
    // never disagree about whether a frame was accepted.
    wire wr_complete = di_en     && (wr_idx == N-1);
    wire rd_complete = do_en_reg && (rd_idx == N-1);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_bank  <= 0;
            rd_bank  <= 0;
            wr_idx   <= 0;
            rd_idx   <= 0;
            full     <= 0;
            do_en_reg <= 1'b0;
            overflow <= 1'b0;
        end else begin
            // ---- write pointer: store sample wr_idx at slot bit_reverse(wr_idx) ----
            if (di_en) begin
                buf_re[wr_bank*N + bit_reverse(wr_idx)] <= di_re;
                buf_im[wr_bank*N + bit_reverse(wr_idx)] <= di_im;
                wr_idx <= wr_idx + 1;
                if (wr_idx == N-1) begin
                    wr_idx <= 0;
                    if (full == BANKS) begin
                        // No free bank. Drop the frame and flag it rather than
                        // silently overwriting a frame the reader still needs.
                        overflow <= 1'b1;
                    end else if (wr_bank == BANKS-1) begin
                        wr_bank <= 0;
                    end else begin
                        wr_bank <= wr_bank + 1;
                    end
                end
            end

            // ---- read pointer: on burst end step to the next bank ----
            if (do_en_reg) begin
                rd_idx <= rd_idx + 1;
                if (rd_idx == N-1) begin
                    rd_idx <= 0;
                    if (rd_bank == BANKS-1) begin
                        rd_bank <= 0;
                    end else begin
                        rd_bank <= rd_bank + 1;
                    end
                end
            end

            // ---- occupancy: simultaneous accept and release nets to no change ----
            case ({wr_complete, rd_complete})
                2'b10:   full <= full + 1;
                2'b01:   full <= full - 1;
                default: ;
            endcase

            // ---- burst control: never drop and re-gate do_en mid-stream ----
            if (wr_complete || (full != 0 && !do_en_reg)) begin
                do_en_reg <= 1'b1;
            end else if (rd_complete) begin
                do_en_reg <= 1'b0;
            end
        end
    end

    assign do_en = do_en_reg;
    assign do_re = buf_re[rd_bank*N + rd_idx];
    assign do_im = buf_im[rd_bank*N + rd_idx];

endmodule
`endif
