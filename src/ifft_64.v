`timescale 1ns / 1ps

// IFFT_64: 64-point IFFT using the radix-2^2 FFT core
//  - Conjugates input (negate im)
//  - Runs FFT
//  - Conjugates output (negate im)
//  - Reorders from bit-reversed to natural order
//  Latency: ~71 (FFT) + 64 (buffer) + 2 = ~137 cycles

`include "FFT64.v"
`include "SdfUnit.v"
`include "Butterfly.v"
`include "Twiddle64.v"
`include "DelayBuffer.v"
`include "Multiply.v"
`include "TwiddleConvert4.v"
`include "bit_reversal_buffer.v"

module ifft_64 #(
    parameter WIDTH = 16
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   di_en,
    input  wire [WIDTH-1:0]       di_re,
    input  wire [WIDTH-1:0]       di_im,
    output wire                   do_en,
    output wire [WIDTH-1:0]       do_re,
    output wire [WIDTH-1:0]       do_im
);

    // Conjugate input for IFFT: x* -> FFT(x*) -> (FFT(x*))* = N * IFFT(x)
    wire [WIDTH-1:0] fft_di_re = di_re;
    wire [WIDTH-1:0] fft_di_im = -di_im;

    wire fft_do_en;
    wire [WIDTH-1:0] fft_do_re;
    wire [WIDTH-1:0] fft_do_im;

    // FFT core (does forward FFT with 1/N scaling)
    FFT #(.WIDTH(WIDTH)) u_fft (
        .clock  (clk),
        .reset  (rst),
        .di_en  (di_en),
        .di_re  (fft_di_re),
        .di_im  (fft_di_im),
        .do_en  (fft_do_en),
        .do_re  (fft_do_re),
        .do_im  (fft_do_im)
    );

    // Conjugate FFT output for IFFT: (FFT(x*))* = N * IFFT(x)
    wire [WIDTH-1:0] conj_re = fft_do_re;
    wire [WIDTH-1:0] conj_im = -fft_do_im;

    // Bit-reversal buffer: FFT outputs bit-reversed, we need natural order
    bit_reversal_buffer #(.N(64), .WIDTH(WIDTH)) u_br (
        .clk   (clk),
        .rst   (rst),
        .di_en (fft_do_en),
        .di_re (conj_re),
        .di_im (conj_im),
        .do_en (do_en),
        .do_re (do_re),
        .do_im (do_im)
    );

endmodule