`timescale 1ns / 1ps

`ifndef MAP_TO_SUBCARRIERS_V
`define MAP_TO_SUBCARRIERS_V


// Complex map_to_subcarriers: 32-bit per subcarrier (16 re + 16 im)
// Matches ofdm_hls.cc.cpp map_to_subcarriers() with complex_fixed
//
// GUARD_COUNT/LAST_GUARD_INDEX default to 10/9, which is what ofdm_hls.cc.cpp
// infers from its 43-entry zc_lut (64 - 2*10 - 1 = 43). Override both together:
// LAST_GUARD_INDEX drives the pilot phase ((i - LAST_GUARD_INDEX) % 6) as well as
// the upper guard boundary, so leaving one at its old value silently shifts every
// pilot subcarrier.
/* verilator lint_off DECLFILENAME */
/* Module name intentionally differs from the filename: the filename is the
   stage name used by the documented build commands, the module name is the
   historical one. See AGENTS.md. */
module parameterized_map_to_subcarriers #(
    parameter SUBCARRIER_COUNT = 64,
    parameter GUARD_COUNT      = 10,
    parameter DC               = 32,
    parameter LAST_GUARD_INDEX = 9
)(
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              sync,
    input  wire                              ref_sym,
    input  wire                              header,
    input  wire [SUBCARRIER_COUNT*32-1:0]    zc_seq,
    input  wire [SUBCARRIER_COUNT*32-1:0]    qpsk_symbol,
    output reg  [SUBCARRIER_COUNT*32-1:0]    subcarriers
);

    integer i;
    localparam COMPLEX_ZERO = 32'h0000_0000;
    localparam COMPLEX_ONE  = 32'h7FFF_0000; // 1.0 + j0.0 in Q1.15

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < SUBCARRIER_COUNT; i = i + 1)
                subcarriers[i*32 +: 32] <= COMPLEX_ZERO;
        end else begin
            for (i = 0; i < SUBCARRIER_COUNT; i = i + 1) begin
            if ((i == DC) || (i < GUARD_COUNT) || (i >= SUBCARRIER_COUNT - GUARD_COUNT)) begin
                subcarriers[i*32 +: 32] <= COMPLEX_ZERO;
            end
            else if (sync) begin
                subcarriers[i*32 +: 32] <= zc_seq[i*32 +: 32];
            end
            else if (ref_sym) begin
                subcarriers[i*32 +: 32] <= COMPLEX_ONE;
            end
            else if ((i - LAST_GUARD_INDEX) % 6 == 0) begin
                subcarriers[i*32 +: 32] <= COMPLEX_ONE;
            end
            else if (header) begin
                subcarriers[i*32 +: 32] <= COMPLEX_ONE;
            end
            else begin
                subcarriers[i*32 +: 32] <= qpsk_symbol[i*32 +: 32];
            end
            end
        end
    end
endmodule
`endif
