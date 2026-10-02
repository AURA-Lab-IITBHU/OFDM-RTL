`timescale 1ns / 1ps

`ifndef UART_RX_V
`define UART_RX_V

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.08.2026 15:19:03
// Design Name: 
// Module Name: uart_rx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_rx(
input clock,
input reset,
input rx,
output reg data_valid,
output reg [7:0] data
    );
    parameter A=0,B=1,C=2,D=3,E=4; //A is idle state;
    //B is start state;
    //C is data loading state;
    //D is stop state;
    //E is error recovery state
    // taking an example of counting 434 cycles
    reg [2:0] state,next_state;
    reg [2:0] count_data;
    reg [8:0] count_clock;
    reg [7:0] temp_store;
    always @(*) begin
    data_valid=1'b0;
    case(state)
    A:next_state=rx?A:B;
    // in start state it has wait for half bit duration and check the rx value
    B: begin 
                    if(count_clock==9'd216)
                   next_state=rx?A:C;
                    else
                    next_state=B;
                    end
                    // in C state it has to check the bit count and also wait for one bit duration
    C:next_state=(count_data==3'd7&&count_clock==9'd433)?D:C;
    // in D state after waiting one bit duartion and then data_valid bit is asserted 
    D: begin
    data_valid = 1'b0;

    if (count_clock == 9'd433) begin
        if (rx == 1'b1) begin
            data_valid = 1'b1;
            next_state = A;
        end
        else begin
            next_state = E;
        end
    end
    else begin
        next_state = D;
    end
end

E: begin
    data_valid = 1'b0;

    if (rx == 1'b1)
        next_state = A;
    else
        next_state = E;
end
    default:next_state=A;
    endcase
    end
    always @(posedge clock) begin
    if(reset==0)begin
    state<=A;
    count_data<=0;
    temp_store<=0;
    end
    else begin
    state<=next_state;
    end
    // counter for counting no. of bits
    if(state==A)
    count_data<=0;
    if(count_clock==9'd433 && state==C) begin
    if(count_data== 3'd7) begin
    temp_store[count_data]<=rx;
    count_data<=0;
    end
    else begin
    temp_store[count_data]<=rx;
    count_data<=count_data+1;
    end
    end
    // counter for counting clock cycles
    end
    always @(posedge clock) begin 
    if(reset==0)
    count_clock<=0;
    else if(state==A||state==E)
    count_clock<=0;
    else if (state == B && count_clock == 9'd216)
    count_clock <= 0;
    else if (state == C && count_clock == 9'd433)
    count_clock <= 0;
else if (state == D && count_clock == 9'd433)
    count_clock <= 0;
    else
    count_clock<=count_clock+1;
    end
    // data is taken based on data is valid or not 
   always @(posedge clock) begin
    if (reset == 1'b0)
        data <= 8'b00000000;
    else if (data_valid)
        data <= temp_store;
end  
endmodule
`endif
