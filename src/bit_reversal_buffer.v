`timescale 1ns / 1ps

// Bit-reversal buffer: takes N samples in bit-reversed order, outputs in natural order
module bit_reversal_buffer #(
    parameter N = 64,
    parameter WIDTH = 16
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   di_en,     // Input sample valid
    input  wire [WIDTH-1:0]       di_re,     // Input real
    input  wire [WIDTH-1:0]       di_im,     // Input imag
    output wire                   do_en,     // Output sample valid
    output wire [WIDTH-1:0]       do_re,     // Output real
    output wire [WIDTH-1:0]       do_im      // Output imag
);

    localparam LOGN = $clog2(N);
    
    reg [WIDTH-1:0] buf_re [0:N-1];
    reg [WIDTH-1:0] buf_im [0:N-1];
    reg [LOGN-1:0]  wr_idx;
    reg [LOGN-1:0]  rd_idx;
    reg             filling;
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

    // Write path: store incoming bit-reversed samples at bit-reversed indices
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_idx   <= 0;
            filling  <= 1'b1;
            rd_idx   <= 0;
            do_en_reg <= 1'b0;
        end else begin
            if (di_en) begin
                buf_re[bit_reverse(wr_idx)] <= di_re;
                buf_im[bit_reverse(wr_idx)] <= di_im;
                wr_idx <= wr_idx + 1;
                if (wr_idx == N-1) begin
                    filling <= 1'b0;
                    rd_idx <= 0;
                    do_en_reg <= 1'b1;
                end
            end
            
            if (!filling && do_en_reg) begin
                rd_idx <= rd_idx + 1;
                if (rd_idx == N-1) begin
                    do_en_reg <= 1'b0;
                    filling <= 1'b1;
                    wr_idx <= 0;
                end
            end
        end
    end

    assign do_en = do_en_reg;
    assign do_re = buf_re[rd_idx];
    assign do_im = buf_im[rd_idx];

endmodule