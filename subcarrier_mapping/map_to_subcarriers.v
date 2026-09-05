module parameterized_map_to_subcarriers #(
parameter SUBCARRIER_COUNT = 64,
parameter GUARD_COUNT = 6,
parameter DC = 32,
parameter LAST_GUARD_INDEX = 5)(
input clk,
input sync,
input ref_sym,
input header,
input [SUBCARRIER_COUNT-1:0] zc_seq,
input [SUBCARRIER_COUNT-1:0] qpsk_symbol,
output reg [SUBCARRIER_COUNT-1:0] subcarriers

);
integer i;
localparam  COMPLEX_ZERO = 1'b0;
localparam COMPLEX_ONE = 1'b1;

always @(posedge clk) begin
    
    for (i=0; i < SUBCARRIER_COUNT; i = i+1)begin
        if ((i == DC) || (i < GUARD_COUNT) || (i >= SUBCARRIER_COUNT - GUARD_COUNT)) begin 
            subcarriers[i] <= COMPLEX_ZERO; //complex fixed values for reference symbol
        end
        else if (sync) begin
            subcarriers[i] <= zc_seq[i]; //complex fixed values for sync symbol
        end
        else if (ref_sym) begin
            subcarriers[i] <= COMPLEX_ONE; //complex fixed values for reference symbol
        end
        else if ((i-LAST_GUARD_INDEX)%6 == 0) begin
            subcarriers[i] <= COMPLEX_ONE;
        end
        else if (header) begin
            subcarriers[i] <= COMPLEX_ONE; //complex fixed values for header reference symbol
        end
        else begin
            subcarriers[i] <= qpsk_symbol[i]; //complex fixed values for data symbol
        end
    end
end
endmodule