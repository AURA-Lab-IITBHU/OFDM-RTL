`timescale 1ns/1ps

module tb;

    reg clk;
    reg reset;
    reg [2559:0] new_data;
    reg vl;

    wire [7:0] out1;
    wire [7:0] out2;

    serial_streaming_input dut (
        .clk(clk),
        .reset(reset),
        .new_data(new_data),
        .out1(out1),
        .out2(out2),
        .vl(vl)
    );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    integer i;
    integer errors;

    reg [15:0] expected_word1;
    reg [15:0] expected_word2;


    initial begin

        errors = 0;
        reset = 1;
        vl = 0;
        new_data = 2560'd0;
        #20;

        reset = 0;
        for(i = 0; i < 160; i = i + 1) begin
            new_data[i*16 +: 16] = i;
        end
        vl = 1;
        @(posedge clk);
        @(posedge clk);

        vl = 0;
        #1;
        for(i = 0; i < 80; i = i + 1) begin

            @(posedge clk);
            #1;

            expected_word1 = i * 2;
            expected_word2 = i * 2 + 1;


         
            if(out1 !== expected_word1[15:8]) begin

                $display(
                    "ERROR: cycle %0d | out1 = %h | expected = %h",
                    i,
                    out1,
                    expected_word1[15:8]
                );

                errors = errors + 1;

            end


            if(out2 !== expected_word2[15:8]) begin

                $display(
                    "ERROR: cycle %0d | out2 = %h | expected = %h",
                    i,
                    out2,
                    expected_word2[15:8]
                );

                errors = errors + 1;

            end

            $display(
                "Cycle %0d : out1 = %h | out2 = %h",
                i,
                out1,
                out2
            );

        end
        if(errors == 0) begin
    $display("\n=================================");
    $display("       TEST PASSED");
    $display("=================================\n");
    end
    else begin
    $display("\n=================================");
    $display("       TEST FAILED");
    $display("Errors = %0d", errors);
    $display("=================================\n");
    end


        $finish;

    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
    end

endmodule