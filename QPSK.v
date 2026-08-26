`timescale 1ns / 1ps
module QPSK_signal(
input [1:0] in,
input clk,
output reg [15:0] I,
output reg[15:0] Q

    );
    
    localparam signed POS = 16'sh5A82;
    localparam signed NEG =  -16'sh5A82;
    
    always@(posedge clk)
    begin 
    I <= in[1]?NEG:POS;
    Q <= in[0]?NEG:POS;
    end 
    
endmodule


module QPSK_signal_128(input [127:0] in,
input clk,
output  [1023:0] I,
output  [1023:0] Q

);
genvar k;

generate

begin
for(k=0; k<64; k=k+1)begin 
QPSK_signal inst(
.in(in[2*k+1:2*k]),
.clk(clk),
.I(I[16*k +15 :16*k]),
.Q(Q[16*k+15 :16*k])
);

end

end 

endgenerate 

endmodule