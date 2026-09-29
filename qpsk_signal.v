`timescale 1ns / 1ps

// QPSK Mapper for 2 Bits 
//   in   I    Q
//   00  +A   +A
//   01  +A   -A
//   10  -A   +A
//   11  -A   -A
//   
//  A = 1/sqrt(2)

module qpsk_signal(

input clk,
input [1:0] in,
output reg signed [15:0] I,
output reg signed [15:0] Q


);
    // 1/sqrt(2) = 0.7071 * 2^15 = 23170 (0x5A82)
    localparam signed POS = 16'sh5A82;
    localparam signed NEG =  -16'sh5A82;

        always@(posedge clk) 
            begin 
                I <= in[1] ? NEG : POS;
                Q <= in[0] ? NEG : POS;
            end 

endmodule
