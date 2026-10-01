`timescale 1ns / 1ps

module tb_parameterized_add_cp;

    // Parameters where symbol_len equals subcarrier_count
    parameter SUBCARRIER_COUNT = 64;
    parameter CP_LENGTH        = 16;
    parameter SYMBOL_LEN       = 64; // Same as subcarrier_count

    // DUT Inputs & Outputs
    reg clk;
    reg [SUBCARRIER_COUNT-1:0] ofdm_symbol;
    wire [SYMBOL_LEN-1:0] ofdm_symbol_cp;

    // Testbench Variables
    reg [SYMBOL_LEN-1:0] expected_ofdm_symbol_cp;
    integer error_count = 0;

    // Instantiate DUT
    parameterized_add_cp #(
        .SYMBOL_LEN(SYMBOL_LEN),
        .SUBCARRIER_COUNT(SUBCARRIER_COUNT),
        .CP_LENGTH(CP_LENGTH)
    ) dut (
        .clk(clk),
        .ofdm_symbol(ofdm_symbol),
        .ofdm_symbol_cp(ofdm_symbol_cp)
    );

    // Clock Generation (10ns period)
    always #5 clk = ~clk;

    // Golden Reference Model matching the exact RTL concatenation
    task compute_expected;
        begin
            expected_ofdm_symbol_cp = {
                ofdm_symbol[SUBCARRIER_COUNT-1 : SUBCARRIER_COUNT-CP_LENGTH], 
                ofdm_symbol[SUBCARRIER_COUNT-CP_LENGTH-1 : 0]
            };
        end
    endtask

    // Output Checking Task
    task check_output;
        input [8*35:1] test_name;
        begin
            compute_expected();
            @(posedge clk);
            #1;

            if (ofdm_symbol_cp !== expected_ofdm_symbol_cp) begin
                $display("[FAIL] %s", test_name);
                $display("       Input Symbol : 64'h%h", ofdm_symbol);
                $display("       Expected     : 64'h%h", expected_ofdm_symbol_cp);
                $display("       Actual       : 64'h%h", ofdm_symbol_cp);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %s", test_name);
                $display("       Input Symbol : 64'h%h", ofdm_symbol);
                $display("       Output CP    : 64'h%h", ofdm_symbol_cp);
            end
        end
    endtask

    // Test Sequence
    initial begin
        clk = 0;
        ofdm_symbol = 64'd0;
        #10;

        // Test Case 1: All Ones
        ofdm_symbol = 64'hFFFF_FFFF_FFFF_FFFF;
        check_output("Test Case 1: All Ones");

        // Test Case 2: Marker Test (0xDEAD prepends, LSB bits truncated)
        ofdm_symbol = 64'hDEAD_BEEF_1234_5678;
        check_output("Test Case 2: Truncated CP Output");

        // Test Case 3: Alternating Pattern
        ofdm_symbol = 64'hAAAA_AAAA_AAAA_AAAA;
        check_output("Test Case 3: Alternating Bits");

        #10;
        $display("\n========================================");
        if (error_count == 0) begin
            $display("   ALL TESTS PASSED PERFECTLY!");
        end else begin
            $display("   TEST FAILED WITH %0d ERROR(S)", error_count);
        end
        $display("========================================\n");
        $finish;
    end

endmodule