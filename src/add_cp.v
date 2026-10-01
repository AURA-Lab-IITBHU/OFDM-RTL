module parameterized_add_cp #( 
parameter SYMBOL_LEN = 64,
parameter SUBCARRIER_COUNT = 64,
parameter CP_LENGTH = 4)(
input clk,
input [SUBCARRIER_COUNT-1:0] ofdm_symbol,
output reg [SYMBOL_LEN-1:0] ofdm_symbol_cp
);

always @(posedge clk) begin
    ofdm_symbol_cp <= {ofdm_symbol[SUBCARRIER_COUNT-1:SUBCARRIER_COUNT-CP_LENGTH], ofdm_symbol[SUBCARRIER_COUNT-CP_LENGTH-1:0]} ;
end
endmodule
