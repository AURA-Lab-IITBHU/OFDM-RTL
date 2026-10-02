
module serial_streaming_input(
    input clk,
    input reset,
    input spi_clk,
    input spi_cs,
    input spi_mosi,
    output reg [7:0] out1,
    output reg [7:0] out2
);

reg [15:0] arr[0:79][0:1];
integer i,j;
reg [6:0] count;
parameter reset_state=2'd0,inpu=2'd1,outp=2'd2;
reg [1:0] state,next_state;
reg [2559:0] new_data;
reg [11:0] spi_count;
reg vl;
reg spi_clk_prev;

always @(posedge clk) 
 begin
    if(reset) begin
        new_data<=2560'd0;
        spi_count<=12'd0;
        vl<=1'b0;
        spi_clk_prev<=1'b0;
    end
    else begin
        spi_clk_prev<=spi_clk;
        if(spi_cs) 
        begin
            spi_count<=12'd0;
            vl<=1'b0;
        end
        else if(spi_clk && !spi_clk_prev) 
        begin
            new_data<={new_data[2558:0],spi_mosi};
            if(spi_count==12'd2559) begin
                spi_count<=12'd0;
                vl<=1'b1;
            end
            else 
            begin
                spi_count<=spi_count+1'b1;
                vl<=1'b0;
            end
        end
        else 
        begin
            vl<=1'b0;
        end
    end
end

always @(posedge clk) 
begin
    if(reset)
        state<=reset_state;
    else
        state<=next_state;
end

always @(*) 
begin
    case(state)
        reset_state:
            if(vl)
                next_state=inpu;
            else
                next_state=reset_state;
        inpu:
            next_state=outp;
        outp:
            if(count==7'd80)
                next_state=reset_state;
            else
                next_state=outp;
        default:
            next_state=reset_state;
    endcase
end

always @(posedge clk) 
begin
    if(vl) begin
        for(i=0;i<80;i=i+1)
            for(j=0;j<2;j=j+1)
                arr[i][j]<=new_data[(i*32+j*16)+:16];
    end
end

always @(posedge clk) 
begin
    if(reset)
        count<=7'd0;
    else if(state==inpu)
        count<=7'd0;
    else if(state==outp && count<7'd80)
        count<=count+1'b1;
end

always @(posedge clk) 
begin
    if(reset) begin
        out1<=8'd0;
        out2<=8'd0;
    end
    else if(state==outp && count<7'd80) begin
        out1<=arr[count][0][15:8];
        out2<=arr[count][1][15:8];
    end
end
endmodule
