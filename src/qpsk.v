`timescale 1ns / 1ps

module qpsk(
    input clk,
    input [127:0] d_in,
    output reg [1023:0] I,
    output reg  [1023:0] Q
    );
    
   integer i;

   always @(posedge clk ) begin
   for (  i = 0; i < 64 ; i = i+1) begin
    I[i*16 +: 16] <= d_in[2*i]     ? 16'shA57E : 16'sh5A82 ;
    Q[i*16 +: 16] <= d_in[(2*i)+1] ? 16'shA57E : 16'sh5A82 ;
   end
   end
endmodule
