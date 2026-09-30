`timescale 1ns / 1ps

module tb_parameterized_map_to_subcarriers;

    // Modified parameters to allow non-zero active data subcarriers
    parameter SUBCARRIER_COUNT = 64;
    parameter GUARD_COUNT      = 6;
    parameter DC               = 32;
    parameter LAST_GUARD_INDEX = 5; // First guard index edge

    // DUT Inputs & Outputs
    reg clk;
    reg sync;
    reg ref_sym;
    reg header;
    reg [SUBCARRIER_COUNT-1:0] zc_seq;
    reg [SUBCARRIER_COUNT-1:0] qpsk_symbol;
    wire [SUBCARRIER_COUNT-1:0] subcarriers;

    // TB Variables
    reg [SUBCARRIER_COUNT-1:0] expected_subcarriers;
    integer error_count = 0;
    integer i;

    // Instantiate DUT
    parameterized_map_to_subcarriers #(
        .SUBCARRIER_COUNT(SUBCARRIER_COUNT),
        .GUARD_COUNT(GUARD_COUNT),
        .DC(DC),
        .LAST_GUARD_INDEX(LAST_GUARD_INDEX)
    ) dut (
        .clk(clk),
        .sync(sync),
        .ref_sym(ref_sym),
        .header(header),
        .zc_seq(zc_seq),
        .qpsk_symbol(qpsk_symbol),
        .subcarriers(subcarriers)
    );

    always #5 clk = ~clk;

    // Output computation reference model
    task compute_expected;
        begin
            for (i = 0; i < SUBCARRIER_COUNT; i = i + 1) begin
                if ((i == DC) || (i < GUARD_COUNT) || (i >= SUBCARRIER_COUNT - GUARD_COUNT)) begin
                    expected_subcarriers[i] = 1'b0;
                end else if (sync) begin
                    expected_subcarriers[i] = zc_seq[i];
                end else if (ref_sym) begin
                    expected_subcarriers[i] = 1'b1;
                end else if ((i - LAST_GUARD_INDEX) % 6 == 0) begin
                    expected_subcarriers[i] = 1'b1;
                end else if (header) begin
                    expected_subcarriers[i] = 1'b1;
                end else begin
                    expected_subcarriers[i] = qpsk_symbol[i];
                end
            end
        end
    endtask

    // Check output task
    task check_output;
        input [8*35:1] test_name;
        begin
            compute_expected();
            @(posedge clk);
            #1;

            if (subcarriers === {SUBCARRIER_COUNT{1'b0}}) begin
                $display("[WARNING] %s: Output is entirely zero!", test_name);
            end

            if (subcarriers !== expected_subcarriers) begin
                $display("[FAIL] %s", test_name);
                $display("       Expected: %b", expected_subcarriers);
                $display("       Actual:   %b", subcarriers);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %s", test_name);
                $display("       Subcarriers: %b", subcarriers);
            end
        end
    endtask

    initial begin
        clk         = 0;
        sync        = 0;
        ref_sym     = 0;
        header      = 0;
        zc_seq      = {SUBCARRIER_COUNT{1'b1}};
        qpsk_symbol = {SUBCARRIER_COUNT{1'b1}};

        #10;

        // -------------------------------------------------------------
        // Test Case 1: Non-Zero Output via Sync Signal (Zadoff-Chu Sequence)
        // Active subcarriers (indices 6-31 and 33-57) map to zc_seq values
        // -------------------------------------------------------------
        sync    = 1;
        ref_sym = 0;
        header  = 0;
        check_output("TC1: Non-Zero Sync Output");

        // -------------------------------------------------------------
        // Test Case 2: Non-Zero Output via Reference Symbol Mode
        // Active subcarriers driven high (COMPLEX_ONE = 1'b1)
        // -------------------------------------------------------------
        sync    = 0;
        ref_sym = 1;
        header  = 0;
        check_output("TC2: Non-Zero Ref Sym Output");

        // -------------------------------------------------------------
        // Test Case 3: Non-Zero Output via Header Mode
        // Active subcarriers driven high for header symbol
        // -------------------------------------------------------------
        sync    = 0;
        ref_sym = 0;
        header  = 1;
        check_output("TC3: Non-Zero Header Output");

        // -------------------------------------------------------------
        // Test Case 4: Non-Zero Output via QPSK Data Payload
        // Standard data pass-through on active subcarrier positions
        // -------------------------------------------------------------
        sync        = 0;
        ref_sym     = 0;
        header      = 0;
        qpsk_symbol = 64'hFFFF_FFFF_FFFF_FFFF;
        check_output("TC4: Non-Zero QPSK Payload Output");

        // -------------------------------------------------------------
        // Test Case 5: Non-Zero Output via Pilot Subcarriers
        // Active subcarriers satisfying (i - LAST_GUARD_INDEX) % 6 == 0 drive 1'b1
        // -------------------------------------------------------------
        sync        = 0;
        ref_sym     = 0;
        header      = 0;
        qpsk_symbol = 64'h0000_0000_0000_0000; // Zero payload to isolate pilots
        check_output("TC5: Non-Zero Pilot Subcarriers Output");

        #10;
        $display("\n========================================");
        $display("   FINAL RESULTS: %0d ERROR(S)", error_count);
        $display("========================================\n");
        $finish;
    end

endmodule