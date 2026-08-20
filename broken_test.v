module broken_test(
    input clk,
    input rst,
    output reg out
);

    always @(posedge clk) begin
        if (rst)
            out <= 0
        else
            out <= 1;
    end

endmodule
