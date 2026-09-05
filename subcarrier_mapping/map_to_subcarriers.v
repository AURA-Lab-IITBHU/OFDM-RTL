module parameterized_map_to_subcarriers #(
parameter subcarrier_count = 10,
parameter guard_count = 6,
parameter dc = 3,
parameter last_guard_index =7)(
input clk,
input sync,
input ref_sym,
input header,
input [subcarrier_count-1:0] zc_seq,
input [subcarrier_count-1:0] qpsk_symbol,
output reg [subcarrier_count-1:0] subcarriers

);
integer i;
localparam [subcarrier_count-1:0] COMPLEX_ZERO = {subcarrier_count{1'b0}};
localparam [subcarrier_count-1:0] COMPLEX_ONE = {{(subcarrier_count-1){1'b0}},1'b1};

always @(posedge clk) begin
    
    for (i=0; i < subcarrier_count; i = i+1)begin
        if ((i == dc) || (i < guard_count) || (i >= subcarrier_count - guard_count)) begin 
            subcarriers[i] <= COMPLEX_ZERO[i];//complex fixed valyes for reference symbol
        end
        else if (sync) begin
            subcarriers[i] <= zc_seq[i]; //complex fixed values for sync symbol
        end
        else if (ref_sym) begin
            subcarriers[i] <= COMPLEX_ONE[i]; //complex fixed values for reference symbol
        end
        else if ((i-last_guard_index)%6 == 0) begin
            subcarriers[i] <= COMPLEX_ONE[i];
        end
        else if (header) begin
            subcarriers[i] <= COMPLEX_ONE[i]; //complex fixed values for header reference symbol
        end
        else begin
            subcarriers[i] <= qpsk_symbol[i]; //complex fixed values for data symbol
        end
    end
end
endmodule