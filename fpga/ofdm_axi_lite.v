`timescale 1ns / 1ps

// AXI4-Lite wrapper around ofdm_generate_frame (full.v) for a Zynq PS.
//
// Register map (byte offsets from the base address in the Address Editor):
//   0x000  CTRL      RW  bit0 = run. 0 -> core held in reset, DONE cleared.
//                                    1 -> core runs until the first frame completes,
//                                         then it is held in reset so the frame is stable.
//   0x004  STATUS    RO  bit0 = done (a full 4-symbol frame is captured)
//                        bit1 = busy (run=1 and not done)
//   0x008  QPSK0     RW  qpsk_bits[ 31:  0]
//   0x00C  QPSK1     RW  qpsk_bits[ 63: 32]
//   0x010  QPSK2     RW  qpsk_bits[ 95: 64]
//   0x014  QPSK3     RW  qpsk_bits[127: 96]
//   0x018  ID        RO  0x0FDA0001  (bring-up sanity check)
//   0x400  FRAME[0]  RO  frame word n at 0x400 + 4*n, n = 0..319, word = {re[15:0], im[15:0]}
//                        symbol s occupies words 80*s .. 80*s+79 (16 CP + 64 body)
//
// Usage from software: write CTRL=0, write QPSK0..3, write CTRL=1, poll STATUS.done,
// read the 320 frame words. To run again: CTRL=0, change QPSK, CTRL=1.
//
// The frame lives in the core's own 10,240-bit output register, which stays internal
// (never a pin). It is NOT block RAM: it synthesises as flip-flops.

module ofdm_axi_lite #(
    parameter ADDR_W = 12          // 4 KB window; frame window ends at 0x8FC
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET s_axi_aresetn" *)
    input  wire                 s_axi_aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                 s_axi_aresetn,

    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi, WIDTH 32, PROTOCOL AXI4LITE, HAS_BRESP, SUPPORTS_NARROW_BURST 0, FREQ_HZ 50000000, HAS_WSTRB, WSTRB_WIDTH 4, INSERT_VIP 0" *)
    // Three inputs are intentionally unread:
    //   s_axi_awaddr[1:0] / s_axi_araddr[1:0] -- AXI addresses are byte
    //     addresses, but this slave only performs 32-bit word accesses, so the
    //     byte lane carries no information.
    //   s_axi_wstrb -- writes are always full 32-bit words via Xil_Out32.
    // Use 32-bit Xil_Out32 / Xil_In32 in software.
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [ADDR_W-1:0]    s_axi_awaddr,
    input  wire                 s_axi_awvalid,
    output reg                  s_axi_awready,
    input  wire [31:0]          s_axi_wdata,
    input  wire [3:0]           s_axi_wstrb,
    input  wire                 s_axi_wvalid,
    output reg                  s_axi_wready,
    output wire [1:0]           s_axi_bresp,
    output reg                  s_axi_bvalid,
    input  wire                 s_axi_bready,

    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi, WIDTH 32, PROTOCOL AXI4LITE, HAS_BRESP, SUPPORTS_NARROW_BURST 0, FREQ_HZ 50000000, HAS_WSTRB, WSTRB_WIDTH 4, INSERT_VIP 0" *)
    input  wire [ADDR_W-1:0]    s_axi_araddr,
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire                 s_axi_arvalid,
    output reg                  s_axi_arready,
    output reg  [31:0]          s_axi_rdata,
    output wire [1:0]           s_axi_rresp,
    output reg                  s_axi_rvalid,
    input  wire                 s_axi_rready
);

    localparam N_WORDS    = 320;                 // 4 symbols x 80 samples
    localparam FRAME_BITS = N_WORDS * 32;        // 10240, matches ofdm_generate_frame
    localparam [31:0] ID  = 32'h0FDA0001;

    assign s_axi_bresp = 2'b00;                  // OKAY
    assign s_axi_rresp = 2'b00;                  // OKAY

    reg                   run;
    reg                   done;
    reg                   core_rst;
    reg  [127:0]          qpsk_bits;
    wire                  frame_done;
    wire [FRAME_BITS-1:0] ofdm_frame;

    // ------------------------------------------------------------------
    // The OFDM core, unchanged
    // ------------------------------------------------------------------
    ofdm_generate_frame u_core (
        .clk        (s_axi_aclk),
        .rst        (core_rst),
        .qpsk_bits  (qpsk_bits),
        .ofdm_frame (ofdm_frame),
        .frame_done (frame_done)
    );

    // Hold the core in reset after the first frame so ofdm_frame cannot be
    // overwritten while software reads it. This relies on ofdm_frame having
    // no reset in the core (true today). The core's next write to the frame
    // is about 200 cycles after frame_done, far later than this reset lands.
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            done     <= 1'b0;
            core_rst <= 1'b1;
        end else begin
            core_rst <= ~run | done;
            if (!run)            done <= 1'b0;
            else if (frame_done) done <= 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // AXI write channel (AW and W accepted together)
    // ------------------------------------------------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
        end else begin
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            if (s_axi_awready)                    s_axi_bvalid <= 1'b1;
            else if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
        end
    end

    // awready is only high in the cycle where AWVALID and WVALID are both high
    // and both are held stable by the master, so it doubles as the write strobe.
    // Byte strobes are ignored: use full 32-bit writes (Xil_Out32).
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            run       <= 1'b0;
            qpsk_bits <= 128'd0;
        end else if (s_axi_awready) begin
            case (s_axi_awaddr[ADDR_W-1:2])
                10'd0: run                <= s_axi_wdata[0];
                10'd2: qpsk_bits[ 31:  0] <= s_axi_wdata;
                10'd3: qpsk_bits[ 63: 32] <= s_axi_wdata;
                10'd4: qpsk_bits[ 95: 64] <= s_axi_wdata;
                10'd5: qpsk_bits[127: 96] <= s_axi_wdata;
                default: ;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // AXI read channel
    // ------------------------------------------------------------------
    wire [ADDR_W-3:0] ridx = s_axi_araddr[ADDR_W-1:2];
    wire [ADDR_W-3:0] fidx = ridx - 10'd256;     // 0x400 / 4 = 256

    reg [31:0] rmux;
    always @(*) begin
        rmux = 32'd0;
        if (ridx >= 10'd256) begin
            if (fidx < N_WORDS)
                rmux = ofdm_frame[fidx*32 +: 32];
        end else begin
            case (ridx)
                10'd0:   rmux = {31'd0, run};
                10'd1:   rmux = {30'd0, (run & ~done), done};
                10'd2:   rmux = qpsk_bits[ 31:  0];
                10'd3:   rmux = qpsk_bits[ 63: 32];
                10'd4:   rmux = qpsk_bits[ 95: 64];
                10'd5:   rmux = qpsk_bits[127: 96];
                10'd6:   rmux = ID;
                default: rmux = 32'd0;
            endcase
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid && !s_axi_rvalid)
                s_axi_arready <= 1'b1;
            else
                s_axi_arready <= 1'b0;

            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rdata  <= rmux;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
