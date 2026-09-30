module  zc_sequence_generator 
( output wire [DATA_WIDTH-1:0] zc_seq_re[0:SUB_COUNT -1] ,
  output wire [DATA_WIDTH-1:0] zc_seq_im[0:SUB_COUNT-1] );
  
  parameter SUB_COUNT = 64 ;
  parameter GUARD_COUNT = 10 ;
  parameter DC_INDEX = 32 ;
  parameter DATA_WIDTH = 16 ;

// Creating zc_sequence_look_up_table

wire [DATA_WIDTH-1:0] zc_lut_re [0:(SUB_COUNT - (2*GUARD_COUNT) - 2)] ; // for real part
wire [DATA_WIDTH-1:0] zc_lut_im [0:(SUB_COUNT - (2*GUARD_COUNT)- 2)] ; //for imaginary part

// look_up_table (Q1.15 Format )

assign zc_lut_re[0]  = 16'h7FFF;  
assign zc_lut_im[0]  = 16'h0000;

assign zc_lut_re[1]  = 16'h9060; 
assign zc_lut_im[1]  = 16'h3EA5;
 
assign zc_lut_re[2]  = 16'hFB53;  
assign zc_lut_im[2]  = 16'h7FEA;

assign zc_lut_re[3]  = 16'h8057;  
assign zc_lut_im[3]  = 16'hF6A8;

assign zc_lut_re[4]  = 16'h320F;  
assign zc_lut_im[4]  = 16'h75CD;

assign zc_lut_re[5]  = 16'hE8C0;  
assign zc_lut_im[5]  = 16'h7DDE;

assign zc_lut_re[6]  = 16'h2060;  
assign zc_lut_im[6]  = 16'h8429;

assign zc_lut_re[7]  = 16'hE8C0;  
assign zc_lut_im[7]  = 16'h8221;

assign zc_lut_re[8]  = 16'h73E5;  
assign zc_lut_im[8]  = 16'h3654;

assign zc_lut_re[9]  = 16'h42AE;  
assign zc_lut_im[9]  = 16'h92BD;

assign zc_lut_re[10] = 16'h7EA2;  
assign zc_lut_im[10] = 16'h12A3;

assign zc_lut_re[11] = 16'hA728;  
assign zc_lut_im[11] = 16'hA3DA;

assign zc_lut_re[12] = 16'hB585;  
assign zc_lut_im[12] = 16'h97E6;

assign zc_lut_re[13] = 16'h6AC0;  
assign zc_lut_im[13] = 16'h46A0;

assign zc_lut_re[14] = 16'h7A92;  
assign zc_lut_im[14] = 16'hDB1F;

assign zc_lut_re[15] = 16'h0DFF;  
assign zc_lut_im[15] = 16'h7F3B;

assign zc_lut_re[16] = 16'h73E5;  
assign zc_lut_im[16] = 16'hC9AB;

assign zc_lut_re[17] = 16'h7A92;  
assign zc_lut_im[17] = 16'h24E0;

assign zc_lut_re[18] = 16'h9060;  
assign zc_lut_im[18] = 16'hC15A;

assign zc_lut_re[19] = 16'h830F;  
assign zc_lut_im[19] = 16'hE42B;

assign zc_lut_re[20] = 16'h6AC0;  
assign zc_lut_im[20] = 16'hB95F;

assign zc_lut_re[21] = 16'hD6AB;  
assign zc_lut_im[21] = 16'h86DB;

assign zc_lut_re[22] = 16'h6AC0;  
assign zc_lut_im[22] = 16'hB95F;

assign zc_lut_re[23] = 16'h830F;  
assign zc_lut_im[23] = 16'hE42B;

assign zc_lut_re[24] = 16'h9060;  
assign zc_lut_im[24] = 16'hC15A;

assign zc_lut_re[25] = 16'h7A92;  
assign zc_lut_im[25] = 16'h24E0;

assign zc_lut_re[26] = 16'h73E5;  
assign zc_lut_im[26] = 16'hC9AB;

assign zc_lut_re[27] = 16'h0DFF;  
assign zc_lut_im[27] = 16'h7F3B;

assign zc_lut_re[28] = 16'h7A92;  
assign zc_lut_im[28] = 16'hDB1F;

assign zc_lut_re[29] = 16'h6AC0;  
assign zc_lut_im[29] = 16'h46A0;

assign zc_lut_re[30] = 16'hB585;  
assign zc_lut_im[30] = 16'h97E6;

assign zc_lut_re[31] = 16'hA728;  
assign zc_lut_im[31] = 16'hA3DA;

assign zc_lut_re[32] = 16'h7EA2;  
assign zc_lut_im[32] = 16'h12A3;

assign zc_lut_re[33] = 16'h42AE;  
assign zc_lut_im[33] = 16'h92BD;

assign zc_lut_re[34] = 16'h73E5;  
assign zc_lut_im[34] = 16'h3654;

assign zc_lut_re[35] = 16'hE8C0;  
assign zc_lut_im[35] = 16'h8221;

assign zc_lut_re[36] = 16'h2060;  
assign zc_lut_im[36] = 16'h8429;

assign zc_lut_re[37] = 16'hE8C0;  
assign zc_lut_im[37] = 16'h7DDE;

assign zc_lut_re[38] = 16'h320F;  
assign zc_lut_im[38] = 16'h75CD;

assign zc_lut_re[39] = 16'h8057;  
assign zc_lut_im[39] = 16'hF6A8;

assign zc_lut_re[40] = 16'hFB53;  
assign zc_lut_im[40] = 16'h7FEA;

assign zc_lut_re[41] = 16'h9060;  
assign zc_lut_im[41] = 16'h3EA5;

assign zc_lut_re[42] = 16'h7FFF;  
assign zc_lut_im[42] = 16'h0000;

//Assigning zc_sequence
genvar i;
	generate
	for ( i=0 ; i < SUB_COUNT ; i =i+1) begin : zc_seq_mapper 
	
		if ( ( i < GUARD_COUNT) || (i == DC_INDEX) || (i > SUB_COUNT - GUARD_COUNT-1) )
			begin
				assign zc_seq_re [i] = 16'h0000 ;
				assign zc_seq_im [i] = 16'h0000 ;
			end
			
		else
			begin
				assign zc_seq_re [i] = zc_lut_re [i - GUARD_COUNT - (( i> DC_INDEX)?1:0)] ;
				assign zc_seq_im [i] = zc_lut_im [i - GUARD_COUNT - (( i> DC_INDEX)?1:0)] ;
			end
	end
	endgenerate
			
endmodule
				         
     