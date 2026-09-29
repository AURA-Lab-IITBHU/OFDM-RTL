`include "qpsk_signal.v"
`timescale 1ns / 1ps

// Parallel QPSK mapper : 64 symbols per clock : 2 bits per symbol 
//  Symbol k uses in[2k:+2] and drives I/Q[16k:+16]

module qpsk_signal_128(

input clk,
input [127:0] in,
output signed [1023:0] I, // 64 x 16-bit signed samples
output signed [1023:0] Q  // 64 x 16-bit signed samples

 );
    
 genvar k;
    generate  
        begin
            for(k = 0; k<64 ; k = k+1)
                begin
                    qpsk_signal inst(
                    .clk(clk),
                    .in( in[ 2*k + 1 : 2*k] ),
                    .I (I[ 16*k +:16]), 
                    .Q (Q[ 16*k +:16])
                    );
                end
        end  
    endgenerate 
       
endmodule
