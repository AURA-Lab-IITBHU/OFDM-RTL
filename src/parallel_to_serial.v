`timescale 1ns / 1ps

`ifndef PARALLEL_TO_SERIAL_V
`define PARALLEL_TO_SERIAL_V

// Parallel-to-serial: takes N complex samples in parallel, streams out one per cycle
// Each complex sample is 32 bits: {re[15:0], im[15:0]}
module parallel_to_serial #(
    parameter N = 64,
    parameter WIDTH = 16
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,           // Pulse to start new frame
    input  wire [N*WIDTH*2-1:0]   parallel_data,  // {re[N-1], im[N-1], ..., re[0], im[0]}
    output reg                    do_en,          // Output sample valid
    output reg  [WIDTH-1:0]       do_re,          // Output real
    output reg  [WIDTH-1:0]       do_im,          // Output imag
    output reg                    frame_done      // High for one cycle after last sample
);

    localparam LOGN = $clog2(N);
    reg [LOGN-1:0] idx;
    reg            active;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idx       <= 0;
            active    <= 1'b0;
            do_en     <= 1'b0;
            do_re     <= 0;
            do_im     <= 0;
            frame_done <= 1'b0;
        end else begin
            frame_done <= 1'b0;
            if (start) begin
                active <= 1'b1;
                idx    <= 1;
                do_en  <= 1'b1;
                do_re  <= parallel_data[16 +: 16];   // sample 0
                do_im  <= parallel_data[0  +: 16];
            end else if (active) begin
                do_re <= parallel_data[(idx*32 + 16) +: 16];
                do_im <= parallel_data[(idx*32) +: 16];
                idx   <= idx + 1;
                if (idx == N-1) begin
                    active     <= 1'b0;
                    frame_done <= 1'b1;   // do_en drops next cycle via the else branch
                end
            end else begin
                do_en <= 1'b0;
            end
        end
    end

endmodule
`endif