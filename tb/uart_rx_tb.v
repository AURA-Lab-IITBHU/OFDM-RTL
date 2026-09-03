`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.08.2026 13:04:31
// Design Name: 
// Module Name: uart_rx_tb
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
`timescale 1ns/1ps

module uart_rx_tb;

    parameter BIT_CYCLES   = 434;
    parameter CLOCK_PERIOD = 10;

    reg clock;
    reg reset;
    reg rx;

    wire data_valid;
    wire [7:0] data;

    integer passed_tests;
    integer failed_tests;
    integer received_count;

    reg [7:0] last_received_data;

    uart_rx dut (
        .clock(clock),
        .reset(reset),
        .rx(rx),
        .data_valid(data_valid),
        .data(data)
    );

    // Generate clock
    initial begin
        clock = 1'b0;
        forever #(CLOCK_PERIOD/2) clock = ~clock;
    end

    /*
     * Record received data.
     *
     * data_valid rises before the clock edge on which data is
     * transferred from temp_store into data. Therefore, wait for
     * that clock edge before checking data.
     */
    always @(posedge data_valid) begin
        @(posedge clock);
        #1;

        last_received_data = data;
        received_count = received_count + 1;

        $display("[%0t] Received byte = 0x%02h",
                 $time, data);
    end

    // Wait for a specified number of clock cycles
    task wait_clock_cycles;
        input integer number_of_cycles;
        integer i;
        begin
            for (i = 0; i < number_of_cycles; i = i + 1)
                @(posedge clock);
        end
    endtask

    // Transmit one UART bit
    task send_uart_bit;
        input bit_value;
        begin
            @(negedge clock);
            rx = bit_value;
            wait_clock_cycles(BIT_CYCLES);
        end
    endtask

    /*
     * Send one UART frame:
     * 1 start bit
     * 8 data bits, LSB first
     * 1 stop bit
     */
    task send_uart_byte;
        input [7:0] byte_to_send;
        integer bit_number;
        begin
            $display("[%0t] Sending byte = 0x%02h",
                     $time, byte_to_send);

            // Start bit
            send_uart_bit(1'b0);

            // Data bits: LSB first
            for (bit_number = 0;
                 bit_number < 8;
                 bit_number = bit_number + 1) begin

                send_uart_bit(byte_to_send[bit_number]);
            end

            // Stop bit
            send_uart_bit(1'b1);
        end
    endtask

    // Send frame with an invalid LOW stop bit
    task send_bad_stop_frame;
        input [7:0] byte_to_send;
        integer bit_number;
        begin
            $display("[%0t] Sending byte 0x%02h with bad stop bit",
                     $time, byte_to_send);

            // Start bit
            send_uart_bit(1'b0);

            // Eight data bits
            for (bit_number = 0;
                 bit_number < 8;
                 bit_number = bit_number + 1) begin

                send_uart_bit(byte_to_send[bit_number]);
            end

            // Invalid stop bit
            send_uart_bit(1'b0);

            // Return line to idle so error state can recover
            @(negedge clock);
            rx = 1'b1;

            wait_clock_cycles(BIT_CYCLES);
        end
    endtask

    // Check the most recently received byte
    task check_received_byte;
        input [7:0] expected_data;
        input integer expected_count;
        begin
            wait_clock_cycles(5);

            if ((received_count == expected_count) &&
                (last_received_data == expected_data)) begin

                passed_tests = passed_tests + 1;

                $display("PASS: Expected 0x%02h, received 0x%02h",
                         expected_data, last_received_data);
            end
            else begin
                failed_tests = failed_tests + 1;

                $display("FAIL: Expected data 0x%02h, received 0x%02h",
                         expected_data, last_received_data);

                $display("      Expected count %0d, actual count %0d",
                         expected_count, received_count);
            end
        end
    endtask

    initial begin
        reset = 1'b0;
        rx = 1'b1;

        passed_tests = 0;
        failed_tests = 0;
        received_count = 0;
        last_received_data = 8'h00;

        // Apply active-low reset
        wait_clock_cycles(5);

        @(negedge clock);
        reset = 1'b1;

        wait_clock_cycles(5);

        // --------------------------------------------
        // Test 1: Normal alternating data pattern
        // --------------------------------------------
        $display("\nTEST 1: Receive 0xA5");

        send_uart_byte(8'hA5);
        check_received_byte(8'hA5, 1);

        // --------------------------------------------
        // Test 2: Receive all ones
        // --------------------------------------------
        $display("\nTEST 2: Receive 0xFF");

        send_uart_byte(8'hFF);
        check_received_byte(8'hFF, 2);

        // --------------------------------------------
        // Test 3: Receive all zeros
        // --------------------------------------------
        $display("\nTEST 3: Receive 0x00");

        send_uart_byte(8'h00);
        check_received_byte(8'h00, 3);

        // --------------------------------------------
        // Test 4: False start bit
        // --------------------------------------------
        $display("\nTEST 4: False start bit");

        @(negedge clock);
        rx = 1'b0;

        // LOW for less than half a bit
        wait_clock_cycles(100);

        @(negedge clock);
        rx = 1'b1;

        // Give the receiver enough time to reject it
        wait_clock_cycles(BIT_CYCLES);

        if (received_count == 3) begin
            passed_tests = passed_tests + 1;
            $display("PASS: False start bit was rejected");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("FAIL: False start generated data_valid");
        end

        // --------------------------------------------
        // Test 5: Invalid stop bit
        // --------------------------------------------
        $display("\nTEST 5: Invalid stop bit");

        send_bad_stop_frame(8'h3C);
        wait_clock_cycles(5);

        if (received_count == 3) begin
            passed_tests = passed_tests + 1;
            $display("PASS: Bad stop bit was rejected");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("FAIL: Bad stop bit generated data_valid");
        end

        // --------------------------------------------
        // Test 6: Recovery after stop-bit error
        // --------------------------------------------
        $display("\nTEST 6: Recovery after bad stop bit");

        send_uart_byte(8'h5A);
        check_received_byte(8'h5A, 4);

        // --------------------------------------------
        // Test 7: Consecutive frames
        // --------------------------------------------
        $display("\nTEST 7: Consecutive frames");

        send_uart_byte(8'h12);
        send_uart_byte(8'h34);

        wait_clock_cycles(10);

        if ((received_count == 6) &&
            (last_received_data == 8'h34)) begin

            passed_tests = passed_tests + 1;
            $display("PASS: Consecutive frames received");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("FAIL: Consecutive frame test failed");
            $display("      Received count = %0d", received_count);
            $display("      Last data = 0x%02h", last_received_data);
        end

        // Final result
        $display("\n----------------------------------");
        $display("Passed tests: %0d", passed_tests);
        $display("Failed tests: %0d", failed_tests);

        if (failed_tests == 0)
            $display("OVERALL TEST PASSED");
        else
            $display("OVERALL TEST FAILED");

        $display("----------------------------------\n");

        $finish;
    end

endmodule
