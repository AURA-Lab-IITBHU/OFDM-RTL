module serial_streaming_input(
    input clk,
    input reset,
    input wire [2559:0] new_data,
    output reg [7:0]out1,
    output reg [7:0]out2,
    input vl
);

  
    reg [15:0]arr[0:159];

    integer i,j;

    reg [6:0]count;

    parameter res_state = 2'd0,inpu= 2'd1,outp= 2'd2;
    reg [1:0]state,next_state;
    always @(posedge clk) begin
        if (reset)
            state<=res_state;
        else
            state<=next_state;
    end


    // ------------------------------------------------
    // Next-state logic
    // ------------------------------------------------
    always @(*) begin
        case (state)
            res_state:begin
                if (vl)
                    next_state = inpu;
                else
                    next_state = res_state;
            end
            inpu:begin
                next_state = outp;
            end
            outp:begin
                if (count == 7'd80)
                    next_state = inpu;
                else
                    next_state = outp;
            end
            default:begin
                next_state = res_state;
            end
        endcase

    end
    always@(posedge clk)begin

        if(state == inpu)begin
            if(vl)begin
                for(i =0;i<80;i=i+1)
                begin
                    for(j=0;j<2;j=j+1)
                    begin
                        arr[i*2+j]<=new_data[(i*32 + j*16)+:16];
                    end
                end
            end
        end
    end
    always @(posedge clk) begin
        if (reset)
            count <= 7'd0;
        else if (state == inpu)
            count <= 7'd0;
        else if (state == outp && count < 7'd80)
            count <= count + 1'b1;

    end
    always @(posedge clk) begin
        if (state == outp && count < 7'd80) begin
            out1 <= arr[count*2][15:8];
            out2 <= arr[count*2+1][15:8];
        end
    end

endmodule