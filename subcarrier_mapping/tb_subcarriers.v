module parameterized_tb_map_to_subcarriers #(
    parameter subcarrier_count =10,
    parameter guard_count = 6,
    parameter dc = 3,
    parameter last_guard_index = 7
)( );
    reg clk;
    reg [subcarrier_count-1:0] zc_seq;
    reg [subcarrier_count-1:0] qpsk_symbol;
    wire [subcarrier_count-1:0] subcarriers;

    parameterized_map_to_subcarriers #(
        .subcarrier_count(subcarrier_count),
        .guard_count(guard_count),
        .dc(dc),
        .last_guard_index(last_guard_index)
    ) uut (
        .clk(clk),
        .sync(sync),
        .ref_sym(ref_sym),
        .header(header),
        .zc_seq(zc_seq),
        .qpsk_symbol(qpsk_symbol),
        .subcarriers(subcarriers)
    );

    always #5 clk = ~clk; 

    

    initial begin
        clk = 0;
        header = 1'b0;
        ref_sym = 1'b0;;
        sync = 1'b0;
        zc_seq = 10'b1010101010;
        qpsk_symbol = 10'b1100110011;
        #5 header = 1'b1;
        #5 ref_sym = 1'b1;
        #5 zc_seq = 10'b1111001101;
        #5 ref_sym = 1'b0;
        #5 qpsk_symbol = 10'b0011001100;
    end
      
    initial begin
        $dumpfile("map_to_subcarriers.vcd");
        $dumpvars(0,uut);
        $monitor("T = %d, zc_seq = %b, qpsk_symbol = %b, subcarriers = %b", $time, qpsk_symbol, zc_seq, subcarriers);
          #100 $finish;
    end

    
endmodule