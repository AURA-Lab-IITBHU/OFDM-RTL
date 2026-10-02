`timescale 1ns / 1ps

`ifndef ZC_SEQ_V
`define ZC_SEQ_V

// ZC (Zadoff-Chu) sync sequence, one complex value per subcarrier.
//
// Outputs are PACKED vectors, not unpacked arrays: subcarrier i occupies
// zc_seq_re[((i+1)*DATA_WIDTH)-1 : i*DATA_WIDTH] (and likewise for im), i.e.
// subcarrier 0 sits in the LSBs. Unpacked-array ports are SystemVerilog-only
// and will not elaborate in Vivado, which parses .v as Verilog-2001.
//
// LUT_SIZE is the C++ LUT entry count: 64 - 2*10 - 1 = 43.
/* verilator lint_off DECLFILENAME */
/* Module name intentionally differs from the filename: the filename is the
   stage name used by the documented build commands, the module name is the
   historical one. See AGENTS.md. */
module zc_sequence_generator
#(
  parameter SUB_COUNT = 64 ,
  parameter GUARD_COUNT = 10,
  parameter DC_INDEX = 32 ,
  parameter DATA_WIDTH = 16
)
( output wire [(DATA_WIDTH*SUB_COUNT)-1:0] zc_seq_re ,
  output wire [(DATA_WIDTH*SUB_COUNT)-1:0] zc_seq_im );
  
// Creating zc_sequence_look_up_table

localparam LUT_SIZE = SUB_COUNT - (2*GUARD_COUNT) - 1;

wire [(DATA_WIDTH * LUT_SIZE)-1:0] zc_lut_re ; // for real part
wire [(DATA_WIDTH * LUT_SIZE)-1:0] zc_lut_im ; //for imaginary part

// look_up_table (Q1.15 Format )

assign zc_lut_re[DATA_WIDTH -1:0]  = 16'h7FFF;  
assign zc_lut_im[DATA_WIDTH -1:0]  = 16'h0000;

assign zc_lut_re[(2*DATA_WIDTH)-1:DATA_WIDTH ]  = 16'h9060; 
assign zc_lut_im[(2*DATA_WIDTH)-1:DATA_WIDTH ]  = 16'h3EA5;
 
assign zc_lut_re[(3*DATA_WIDTH)-1 :2*DATA_WIDTH]  = 16'hFB53;  
assign zc_lut_im[(3*DATA_WIDTH)-1 :2*DATA_WIDTH]  = 16'h7FEA;

assign zc_lut_re[(4*DATA_WIDTH)-1 :3*DATA_WIDTH]  = 16'h8057;  
assign zc_lut_im[(4*DATA_WIDTH)-1 :3*DATA_WIDTH]  = 16'hF6A8;

assign zc_lut_re[(5*DATA_WIDTH)-1 :4*DATA_WIDTH]  = 16'h320F;  
assign zc_lut_im[(5*DATA_WIDTH)-1 :4*DATA_WIDTH]  = 16'h75CD;

assign zc_lut_re[(6*DATA_WIDTH)-1 :5*DATA_WIDTH]  = 16'hE8C0;  
assign zc_lut_im[(6*DATA_WIDTH)-1 :5*DATA_WIDTH]  = 16'h7DDE;

assign zc_lut_re[(7*DATA_WIDTH)-1 :6*DATA_WIDTH]  = 16'h2060;  
assign zc_lut_im[(7*DATA_WIDTH)-1 :6*DATA_WIDTH]  = 16'h8429;

assign zc_lut_re[(8*DATA_WIDTH)-1 :7*DATA_WIDTH]  = 16'hE8C0;  
assign zc_lut_im[(8*DATA_WIDTH)-1 :7*DATA_WIDTH]  = 16'h8221;

assign zc_lut_re[(9*DATA_WIDTH)-1 :8*DATA_WIDTH]  = 16'h73E5;  
assign zc_lut_im[(9*DATA_WIDTH)-1 :8*DATA_WIDTH]  = 16'h3654;

assign zc_lut_re[(10*DATA_WIDTH)-1 :9*DATA_WIDTH]  = 16'h42AE;  
assign zc_lut_im[(10*DATA_WIDTH)-1 :9*DATA_WIDTH]  = 16'h92BD;

assign zc_lut_re[(11*DATA_WIDTH)-1 :10*DATA_WIDTH] = 16'h7EA2;  
assign zc_lut_im[(11*DATA_WIDTH)-1 :10*DATA_WIDTH] = 16'h12A3;

assign zc_lut_re[(12*DATA_WIDTH)-1 :11*DATA_WIDTH] = 16'hA728;  
assign zc_lut_im[(12*DATA_WIDTH)-1 :11*DATA_WIDTH] = 16'hA3DA;

assign zc_lut_re[(13*DATA_WIDTH)-1 :12*DATA_WIDTH] = 16'hB585;  
assign zc_lut_im[(13*DATA_WIDTH)-1 :12*DATA_WIDTH] = 16'h97E6;

assign zc_lut_re[(14*DATA_WIDTH)-1 :13*DATA_WIDTH] = 16'h6AC0;  
assign zc_lut_im[(14*DATA_WIDTH)-1 :13*DATA_WIDTH] = 16'h46A0;

assign zc_lut_re[(15*DATA_WIDTH)-1 :14*DATA_WIDTH] = 16'h7A92;  
assign zc_lut_im[(15*DATA_WIDTH)-1 :14*DATA_WIDTH] = 16'hDB1F;

assign zc_lut_re[(16*DATA_WIDTH)-1 :15*DATA_WIDTH] = 16'h0DFF;  
assign zc_lut_im[(16*DATA_WIDTH)-1 :15*DATA_WIDTH] = 16'h7F3B;

assign zc_lut_re[(17*DATA_WIDTH)-1 :16*DATA_WIDTH] = 16'h73E5;  
assign zc_lut_im[(17*DATA_WIDTH)-1 :16*DATA_WIDTH] = 16'hC9AB;

assign zc_lut_re[(18*DATA_WIDTH)-1 :17*DATA_WIDTH] = 16'h7A92;  
assign zc_lut_im[(18*DATA_WIDTH)-1 :17*DATA_WIDTH] = 16'h24E0;

assign zc_lut_re[(19*DATA_WIDTH)-1 :18*DATA_WIDTH] = 16'h9060;  
assign zc_lut_im[(19*DATA_WIDTH)-1 :18*DATA_WIDTH] = 16'hC15A;

assign zc_lut_re[(20*DATA_WIDTH)-1 :19*DATA_WIDTH] = 16'h830F;  
assign zc_lut_im[(20*DATA_WIDTH)-1 :19*DATA_WIDTH] = 16'hE42B;

assign zc_lut_re[(21*DATA_WIDTH)-1 :20*DATA_WIDTH] = 16'h6AC0;  
assign zc_lut_im[(21*DATA_WIDTH)-1 :20*DATA_WIDTH] = 16'hB95F;

assign zc_lut_re[(22*DATA_WIDTH)-1 :21*DATA_WIDTH] = 16'hD6AB;  
assign zc_lut_im[(22*DATA_WIDTH)-1 :21*DATA_WIDTH] = 16'h86DB;

assign zc_lut_re[(23*DATA_WIDTH)-1 :22*DATA_WIDTH] = 16'h6AC0;  
assign zc_lut_im[(23*DATA_WIDTH)-1 :22*DATA_WIDTH] = 16'hB95F;

assign zc_lut_re[(24*DATA_WIDTH)-1 :23*DATA_WIDTH] = 16'h830F;  
assign zc_lut_im[(24*DATA_WIDTH)-1 :23*DATA_WIDTH] = 16'hE42B;

assign zc_lut_re[(25*DATA_WIDTH)-1 :24*DATA_WIDTH] = 16'h9060;  
assign zc_lut_im[(25*DATA_WIDTH)-1 :24*DATA_WIDTH] = 16'hC15A;

assign zc_lut_re[(26*DATA_WIDTH)-1 :25*DATA_WIDTH] = 16'h7A92;  
assign zc_lut_im[(26*DATA_WIDTH)-1 :25*DATA_WIDTH] = 16'h24E0;

assign zc_lut_re[(27*DATA_WIDTH)-1 :26*DATA_WIDTH] = 16'h73E5;  
assign zc_lut_im[(27*DATA_WIDTH)-1 :26*DATA_WIDTH] = 16'hC9AB;

assign zc_lut_re[(28*DATA_WIDTH)-1 :27*DATA_WIDTH] = 16'h0DFF;  
assign zc_lut_im[(28*DATA_WIDTH)-1 :27*DATA_WIDTH] = 16'h7F3B;

assign zc_lut_re[(29*DATA_WIDTH)-1 :28*DATA_WIDTH] = 16'h7A92;  
assign zc_lut_im[(29*DATA_WIDTH)-1 :28*DATA_WIDTH] = 16'hDB1F;

assign zc_lut_re[(30*DATA_WIDTH)-1 :29*DATA_WIDTH] = 16'h6AC0;  
assign zc_lut_im[(30*DATA_WIDTH)-1 :29*DATA_WIDTH] = 16'h46A0;

assign zc_lut_re[(31*DATA_WIDTH)-1 :30*DATA_WIDTH] = 16'hB585;  
assign zc_lut_im[(31*DATA_WIDTH)-1 :30*DATA_WIDTH] = 16'h97E6;

assign zc_lut_re[(32*DATA_WIDTH)-1 :31*DATA_WIDTH] = 16'hA728;  
assign zc_lut_im[(32*DATA_WIDTH)-1 :31*DATA_WIDTH] = 16'hA3DA;

assign zc_lut_re[(33*DATA_WIDTH)-1 :32*DATA_WIDTH] = 16'h7EA2;  
assign zc_lut_im[(33*DATA_WIDTH)-1 :32*DATA_WIDTH] = 16'h12A3;

assign zc_lut_re[(34*DATA_WIDTH)-1 :33*DATA_WIDTH] = 16'h42AE;  
assign zc_lut_im[(34*DATA_WIDTH)-1 :33*DATA_WIDTH] = 16'h92BD;

assign zc_lut_re[(35*DATA_WIDTH)-1 :34*DATA_WIDTH] = 16'h73E5;  
assign zc_lut_im[(35*DATA_WIDTH)-1 :34*DATA_WIDTH] = 16'h3654;

assign zc_lut_re[(36*DATA_WIDTH)-1 :35*DATA_WIDTH] = 16'hE8C0;  
assign zc_lut_im[(36*DATA_WIDTH)-1 :35*DATA_WIDTH] = 16'h8221;

assign zc_lut_re[(37*DATA_WIDTH)-1 :36*DATA_WIDTH] = 16'h2060;  
assign zc_lut_im[(37*DATA_WIDTH)-1 :36*DATA_WIDTH] = 16'h8429;

assign zc_lut_re[(38*DATA_WIDTH)-1 :37*DATA_WIDTH] = 16'hE8C0;  
assign zc_lut_im[(38*DATA_WIDTH)-1 :37*DATA_WIDTH] = 16'h7DDE;

assign zc_lut_re[(39*DATA_WIDTH)-1 :38*DATA_WIDTH] = 16'h320F;  
assign zc_lut_im[(39*DATA_WIDTH)-1 :38*DATA_WIDTH] = 16'h75CD;

assign zc_lut_re[(40*DATA_WIDTH)-1 :39*DATA_WIDTH] = 16'h8057;  
assign zc_lut_im[(40*DATA_WIDTH)-1 :39*DATA_WIDTH] = 16'hF6A8;

assign zc_lut_re[(41*DATA_WIDTH)-1 :40*DATA_WIDTH] = 16'hFB53;  
assign zc_lut_im[(41*DATA_WIDTH)-1 :40*DATA_WIDTH] = 16'h7FEA;

assign zc_lut_re[(42*DATA_WIDTH)-1 :41*DATA_WIDTH] = 16'h9060;  
assign zc_lut_im[(42*DATA_WIDTH)-1 :41*DATA_WIDTH] = 16'h3EA5;

assign zc_lut_re[(43*DATA_WIDTH)-1 :42*DATA_WIDTH] = 16'h7FFF;  
assign zc_lut_im[(43*DATA_WIDTH)-1 :42*DATA_WIDTH] = 16'h0000;

//Assigning zc_sequence
genvar i;
	generate
	for ( i=0 ; i < SUB_COUNT ; i =i+1) begin : zc_seq_mapper 
	
		if ( ( i < GUARD_COUNT) || (i == DC_INDEX) || (i > SUB_COUNT - GUARD_COUNT-1) )
			begin : guard_zero
				assign zc_seq_re [((i+1)*DATA_WIDTH)-1:(i*DATA_WIDTH)] = 16'h0000 ;
				assign zc_seq_im [((i+1)*DATA_WIDTH)-1:(i*DATA_WIDTH)] = 16'h0000 ;
			end
			
		else
			begin : lut_lookup
				assign zc_seq_re [((i+1)*DATA_WIDTH)-1:(i*DATA_WIDTH)] = zc_lut_re [((i - GUARD_COUNT - (( i> DC_INDEX)?1:0))+1)*DATA_WIDTH-1:(i - GUARD_COUNT - (( i> DC_INDEX)?1:0))*DATA_WIDTH] ;
				assign zc_seq_im [((i+1)*DATA_WIDTH)-1:(i*DATA_WIDTH)] = zc_lut_im [((i - GUARD_COUNT - (( i> DC_INDEX)?1:0))+1)*DATA_WIDTH-1:(i - GUARD_COUNT - (( i> DC_INDEX)?1:0))*DATA_WIDTH] ;
			end
	end
	endgenerate
			
endmodule

`endif
				         
     
