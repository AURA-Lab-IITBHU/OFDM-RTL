`timescale 1ns / 1ps

// Serial-to-parallel: collects N complex samples from stream, outputs in parallel
// Each complex sample is 32 bits: {re[15:0], im[15:0]}
module serial_to_parallel #(
    parameter N = 64,
    parameter WIDTH = 16
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   di_en,
    input  wire [WIDTH-1:0]       di_re,
    input  wire [WIDTH-1:0]       di_im,
    output reg                    frame_done,
    output reg  [N*WIDTH*2-1:0]   parallel_data
);

    localparam LOGN = $clog2(N);
    reg [LOGN-1:0] idx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idx        <= 0;
            frame_done <= 1'b0;
        end else begin
            frame_done <= 1'b0;
            if (di_en) begin
                // Pack as {re[15:0], im[15:0]} per 32-bit word
                parallel_data[(idx*32 + 16) +: 16] <= di_re;
                parallel_data[(idx*32) +: 16] <= di_im;
                idx <= idx + 1;
                if (idx == N-1) begin
                    idx        <= 0;
                    frame_done <= 1'b1;
                end
            end
        end
    end

endmodule