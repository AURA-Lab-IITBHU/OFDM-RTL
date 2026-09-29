`include "qpsk_signal_128.v"
`timescale 1ns / 1ps

module tb_QPSK_signal;

reg clk;
reg [127:0]in;

wire [1023:0]I;
wire [1023:0]Q;

qpsk_signal_128 uut (
        .in(in),
        .clk(clk),
        .I(I),
        .Q(Q)
    );
    // 100Mhz
    always #5 clk = ~clk;
    
    //5a82 = 1/sqrt(2)
   //a57e = -1/sqrt(2)
    
initial begin 
#0
clk =1'b1;
in = 128'b00;
$monitor("Value of I: %0h and Q:%0h ", I[15:0], Q[15:0]);
#10 
in = 128'b11;
$monitor("Value of I: %0h and Q:%0h ", I[15:0], Q[15:0]);
#10 
in = 128'b10;
$monitor("Value of I: %0h and Q:%0h ", I[15:0], Q[15:0]);

#10 
in = 128'b01;
$monitor("Value of I: %0h and Q:%0h ", I[15:0], Q[15:0]);

#10 
$finish;
end 

endmodule
