module serial_streaming_input(
    input clk,
    input reset,
    input wire [2559:0] new_data,
    output reg[7:0] out1,
    output reg[7:0] out2,
    input vl
    );

    reg [15:0] arr[0:79][0:1];
    integer i,j;
    reg [6:0]count;
    parameter reset_state=1'd0,inpu =1'd1,outp =1'd2;
    reg [1:0]state,next_state;

    always@(posedge clk)begin
        if(reset)
            state<=reset_state;
        else
        state<=next_state;   
    end

    always@(*)
        begin
            case(state)
            reset_state:if(reset&&vl)
                            next_state=inpu;
                        else
                            next_state=reset_state;
            inpu:next_state=outp;
            outp:if(count==7'd80)
                   next_state=inpu;
                   else
                   next_state=outp;
                default:next_state=reset_state;
            endcase
        end

    always@(posedge clk)begin
        if(state==inpu)begin
        if(vl)
        begin
            for( i=0;i<80;i=i+1)
               for(j =0;j<2;j=j+1)
                    arr[i][j]<=new_data[(i*32+j*16)+:16];
        end
        end
    end

    always@(posedge clk)begin
        if(reset)
            count<=7'd0;
        else if(state==outp)
            count<=count+1;
    end

    always@(posedge clk)begin
        if(state==outp && count!=7'd80)begin
            out1 <= arr[count][0][15:8];
            out2 <= arr[count][1][15:8];
        end
    end
endmodule