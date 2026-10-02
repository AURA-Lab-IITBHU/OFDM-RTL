`timescale 1ns / 1ps

`ifndef ADD_CP_V
`define ADD_CP_V


// Complex add_cp: cyclic prefix on 32-bit complex symbols
// Matches ofdm_hls.cc.cpp add_cp() with complex_fixed
module parameterized_add_cp #(
    parameter SYMBOL_LEN       = 80,
    parameter SUBCARRIER_COUNT = 64,
    parameter CP_LENGTH        = 16
)(
    input  wire                              clk,
    input  wire                              rst,
    input  wire [SUBCARRIER_COUNT*32-1:0]    ofdm_symbol,
    output reg  [SYMBOL_LEN*32-1:0]          ofdm_symbol_cp
);

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ofdm_symbol_cp <= {SYMBOL_LEN*32{1'b0}};
        end else begin
        for (i = 0; i < CP_LENGTH; i = i + 1) begin
            ofdm_symbol_cp[i*32 +: 32] <= ofdm_symbol[(SUBCARRIER_COUNT - CP_LENGTH + i)*32 +: 32];
        end
        for (i = CP_LENGTH; i < SYMBOL_LEN; i = i + 1) begin
            ofdm_symbol_cp[i*32 +: 32] <= ofdm_symbol[(i - CP_LENGTH)*32 +: 32];
        end
        end
    end
endmodule
`endif
