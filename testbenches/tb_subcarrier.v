`timescale 1ns / 1ps

module tb_parameterized_map_to_subcarriers;

    parameter SUBCARRIER_COUNT = 64;
    parameter GUARD_COUNT      = 10;
    parameter DC               = 32;
    parameter LAST_GUARD_INDEX = 9;
    parameter DATA_WIDTH       = 16;

    reg clk;
    reg sync;
    reg ref_sym;
    reg header;
    reg [SUBCARRIER_COUNT*32-1:0] zc_seq;
    reg [SUBCARRIER_COUNT*32-1:0] qpsk_symbol;
    wire [SUBCARRIER_COUNT*32-1:0] subcarriers;

    reg [SUBCARRIER_COUNT*32-1:0] expected_subcarriers;
    integer error_count = 0;
    integer i;

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

    task compute_expected;
        begin
            for (i = 0; i < SUBCARRIER_COUNT; i = i + 1) begin
                if ((i == DC) || (i < GUARD_COUNT) || (i >= SUBCARRIER_COUNT - GUARD_COUNT)) begin
                    expected_subcarriers[i*32 +: 32] = 32'h0000_0000;
                end else if (sync) begin
                    expected_subcarriers[i*32 +: 32] = zc_seq[i*32 +: 32];
                end else if (ref_sym) begin
                    expected_subcarriers[i*32 +: 32] = 32'h7FFF_0000;
                end else if ((i - LAST_GUARD_INDEX) % 6 == 0) begin
                    expected_subcarriers[i*32 +: 32] = 32'h7FFF_0000;
                end else if (header) begin
                    expected_subcarriers[i*32 +: 32] = 32'h7FFF_0000;
                end else begin
                    expected_subcarriers[i*32 +: 32] = qpsk_symbol[i*32 +: 32];
                end
            end
        end
    endtask

    task check_output;
        input [8*35:1] test_name;
        begin
            compute_expected();
            @(posedge clk);
            #1;

            if (subcarriers !== expected_subcarriers) begin
                $display("[FAIL] %s", test_name);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %s", test_name);
            end
        end
    endtask

    initial begin
        clk         = 0;
        sync        = 0;
        ref_sym     = 0;
        header      = 0;
        zc_seq      = {SUBCARRIER_COUNT{32'h7FFF_0000}};
        qpsk_symbol = {SUBCARRIER_COUNT{32'h1234_5678}};

        #10;

        // TC1: Sync - ZC sequence
        sync    = 1;
        ref_sym = 0;
        header  = 0;
        check_output("TC1: Sync Output (ZC Sequence)");

        // TC2: Ref Symbol
        sync    = 0;
        ref_sym = 1;
        header  = 0;
        check_output("TC2: Ref Sym Output (All Ones)");

        // TC3: Header Symbol
        sync    = 0;
        ref_sym = 0;
        header  = 1;
        check_output("TC3: Header Output (All Ones)");

        // TC4: QPSK Payload
        sync        = 0;
        ref_sym     = 0;
        header      = 0;
        qpsk_symbol = {SUBCARRIER_COUNT{32'hABCD_EF01}};
        check_output("TC4: QPSK Payload Output");

        // TC5: Pilot Subcarriers (isolated)
        sync        = 0;
        ref_sym     = 0;
        header      = 0;
        qpsk_symbol = {SUBCARRIER_COUNT{32'h0000_0000}};
        check_output("TC5: Pilot Subcarriers Output");

        #10;
        $display("\n========================================");
        $display("   FINAL RESULTS: %0d ERROR(S)", error_count);
        $display("========================================\n");
        $finish;
    end

endmodule