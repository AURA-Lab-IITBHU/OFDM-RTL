`timescale 1ns / 1ps

module tb_parameterized_add_cp;

    parameter SUBCARRIER_COUNT = 64;
    parameter CP_LENGTH        = 16;
    parameter SYMBOL_LEN       = 80;

    reg clk;
    reg [SUBCARRIER_COUNT*32-1:0] ofdm_symbol;
    wire [SYMBOL_LEN*32-1:0] ofdm_symbol_cp;

    reg [SYMBOL_LEN*32-1:0] expected_ofdm_symbol_cp;
    integer error_count = 0;
    integer j;

    parameterized_add_cp #(
        .SYMBOL_LEN(SYMBOL_LEN),
        .SUBCARRIER_COUNT(SUBCARRIER_COUNT),
        .CP_LENGTH(CP_LENGTH)
    ) dut (
        .clk(clk),
        .ofdm_symbol(ofdm_symbol),
        .ofdm_symbol_cp(ofdm_symbol_cp)
    );

    always #5 clk = ~clk;

    task compute_expected;
        begin
            expected_ofdm_symbol_cp = {SYMBOL_LEN*32{1'b0}};
            for (j = 0; j < CP_LENGTH; j = j + 1)
                expected_ofdm_symbol_cp[j*32 +: 32] = ofdm_symbol[(SUBCARRIER_COUNT - CP_LENGTH + j)*32 +: 32];
            for (j = CP_LENGTH; j < SYMBOL_LEN; j = j + 1)
                expected_ofdm_symbol_cp[j*32 +: 32] = ofdm_symbol[(j - CP_LENGTH)*32 +: 32];
        end
    endtask

    task check_output;
        input [8*35:1] test_name;
        begin
            compute_expected();
            @(posedge clk);
            #1;

            if (ofdm_symbol_cp !== expected_ofdm_symbol_cp) begin
                $display("[FAIL] %s", test_name);
                $display("       Input Symbol  : %0d'h%h", SUBCARRIER_COUNT*32, ofdm_symbol);
                $display("       Expected CP   : %0d'h%h", SYMBOL_LEN*32, expected_ofdm_symbol_cp);
                $display("       Actual CP     : %0d'h%h", SYMBOL_LEN*32, ofdm_symbol_cp);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %s", test_name);
                $display("       Input Symbol  : %0d'h%h", SUBCARRIER_COUNT*32, ofdm_symbol);
                $display("       Output CP     : %0d'h%h", SYMBOL_LEN*32, ofdm_symbol_cp);
            end
        end
    endtask

    initial begin
        clk = 0;
        ofdm_symbol = {SUBCARRIER_COUNT{32'h0000_0000}};
        #10;

        // Test Case 1: All Ones
        ofdm_symbol = {SUBCARRIER_COUNT{32'h7FFF_7FFF}};
        check_output("Test Case 1: All Ones");

        // Test Case 2: Marker test - CP is top CP_LENGTH samples prepended
        ofdm_symbol = {64{32'hDEAD_BEEF}};
        check_output("Test Case 2: CP Prepend");

        // Test Case 3: Alternating Pattern
        ofdm_symbol = {64{32'hAAAA_AAAA}};
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