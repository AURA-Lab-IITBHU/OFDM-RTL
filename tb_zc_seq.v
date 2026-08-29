`timescale 1ns / 100ps
module tb_zc_seq;

parameter SUB_COUNT = 64;
parameter GUARD_COUNT = 10;
parameter DC_INDEX = 32;
parameter DATA_WIDTH = 16;

integer i;
integer error = 0;

wire [DATA_WIDTH-1:0]zc_re[0:SUB_COUNT-1];
wire [DATA_WIDTH-1:0]zc_im[0:SUB_COUNT-1];

zc_sequence_generator #(
    .SUB_COUNT(SUB_COUNT),
    .GUARD_COUNT(GUARD_COUNT),
    .DC_INDEX(DC_INDEX),
    .DATA_WIDTH(DATA_WIDTH)
) dut_zc_seq (
    .zc_seq_re(zc_re),
    .zc_seq_im(zc_im)
);

initial
    begin
        #15;
        for (i=0 ; i < 64 ; i = i+1)
        begin

            //Checking lower guard
            if(i < GUARD_COUNT)
            begin
                if ((zc_re[i] != 16'h0000) || (zc_im[i] != 16'h0000) )
                begin
                    $display("FAIL: Lower guard band at index %0d is not zero! Re: %h, Im: %h", i, zc_re[i], zc_im[i]);
                    error = error + 1;
                end
                else $display("Index : %d , Re: %h , Im: %h", i, zc_re[i], zc_im[i]);
            end

            //Checking dc guard
            else if(i == DC_INDEX)
            begin
                if ((zc_re[i] != 16'h0000) || (zc_im[i] != 16'h0000) )
                begin
                    $display("FAIL: dc index at index %0d is not zero! Re: %h, Im: %h", i, zc_re[i], zc_im[i]);
                    error = error + 1;
                end
                else $display("Index : %d , Re: %h , Im: %h", i, zc_re[i], zc_im[i]);
            end

            //Checking upper Guard
             else if(i > SUB_COUNT - GUARD_COUNT - 1)
            begin
                if ((zc_re[i] != 16'h0000) || (zc_im[i] != 16'h0000) )
                begin
                    $display("FAIL: Upper guard band at index %0d is not zero! Re: %h, Im: %h", i, zc_re[i], zc_im[i]);
                    error = error + 1;
                end
                else $display("Index : %d , Re: %h , Im: %h", i, zc_re[i], zc_im[i]);
            end

            //Checking remaining bits
             else $display("Index : %d , Re: %h , Im: %h", i, zc_re[i], zc_im[i]);
        end
    end

    
initial
    begin
        $dumpfile ("zc.vcd");
        $dumpvars (0,tb_zc_seq);
    end

endmodule


