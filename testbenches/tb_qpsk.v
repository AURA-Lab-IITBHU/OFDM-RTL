`timescale 1ns / 1ps

module tb_qpsk(  );

reg clk;
reg [127:0] d_in;
wire [1023:0] I;
wire [1023:0] Q;

qpsk uut (
.clk(clk),
.d_in(d_in),
.I(I),
.Q(Q)
);

always  begin
#5 clk = !clk;
end

initial begin
clk = 0;
d_in = 128'd0;
#20 
d_in = 128'd7;
#10 
d_in =  128'd8;
#10
$finish;

end
endmodule
