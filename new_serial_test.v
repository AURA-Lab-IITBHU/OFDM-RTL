`timescale 1ns/1ps

module tb;

    // -----------------------------
    // Inputs to DUT
    // -----------------------------
    reg clk;
    reg reset;
    reg spi_clk;
    reg spi_cs;
    reg spi_mosi;

    // -----------------------------
    // Outputs from DUT
    // -----------------------------
    wire [7:0] out1;
    wire [7:0] out2;

    // -----------------------------
    // Instantiate DUT
    // -----------------------------
    serial_streaming_input uut (
        .clk(clk),
        .reset(reset),
        .spi_clk(spi_clk),
        .spi_cs(spi_cs),
        .spi_mosi(spi_mosi),
        .out1(out1),
        .out2(out2)
    );

    // -----------------------------
    // Main clock
    // 10 ns period = 100 MHz
    // -----------------------------
    always #5 clk = ~clk;


    // -----------------------------
    // Test data
    // -----------------------------
    reg [2559:0] test_data;

    integer k;


    // -----------------------------
    // SPI task
    // Sends 2560 bits
    // -----------------------------
    task send_spi_data;
        integer k;
        begin

            // Enable SPI
            spi_cs = 1'b0;

            // Send MSB first
            for(k = 2559; k >= 0; k = k - 1)
            begin

                // Put data on MOSI
                spi_mosi = test_data[k];

                // SPI clock LOW
                spi_clk = 1'b0;
                #20;

                // SPI clock HIGH
                spi_clk = 1'b1;
                #20;

            end

            // Finish SPI transaction
            spi_clk = 1'b0;
            spi_cs = 1'b1;
            spi_mosi = 1'b0;

        end
    endtask


    // -----------------------------
    // Test sequence
    // -----------------------------
    initial begin

        // Waveform dump
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);

        // Initial values
        clk = 1'b0;
        reset = 1'b1;
        spi_clk = 1'b0;
        spi_cs = 1'b1;
        spi_mosi = 1'b0;

        // Create test data
        for(k = 0; k < 2560; k = k + 1)
            test_data[k] = k % 2;

        // Hold reset
        #20;

        // Release reset
        reset = 1'b0;

        #20;

        // Send complete 2560-bit packet
        send_spi_data();

        // Wait for data processing and output
        #500;

        $finish;
    end


    // -----------------------------
    // Monitor outputs
    // -----------------------------
    always @(posedge clk) begin

        if(uut.state == uut.outp) begin

            $display(
                "TIME=%0t | COUNT=%0d | OUT1=%h | OUT2=%h",
                $time,
                uut.count,
                out1,
                out2
            );

        end

    end

endmodule