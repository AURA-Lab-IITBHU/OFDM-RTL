# OFDM RTL

A 64-point OFDM transmitter in synthesizable Verilog-2001, plus a Zynq bring-up
path that reads its payload from an SD card and writes the generated frame back
out. The RTL is verified against the C++ reference in `ofdm_hls.cc.cpp`.

## Signal chain

```
qpsk_signal_128 -> map_to_subcarriers -> parallel_to_serial
                -> ifft_64 -> serial_to_parallel -> add_cp -> ofdm_frame
```

- 64 subcarriers, 32 bits each (`{re[15:0], im[15:0]}`, both Q1.15).
- 10 guard subcarriers on each side, DC at index 32.
- 4 symbols of 64 samples, each with a 16-sample cyclic prefix: 320 words total.
- `GUARD_COUNT = 10`, `LAST_GUARD_INDEX = 9`. **Set these together** — the
  latter also sets the pilot phase `(i - LAST_GUARD_INDEX) % 6`.
- Subcarrier content per symbol: 0 = Zernkor Chu sync, 1 = all-ones reference,
  2 = header, 3 = QPSK payload with pilots overriding at the pilot phase.

## Layout

| Path | Contents |
| --- | --- |
| `full.v` | top level `ofdm_generate_frame`; `` `include `` aggregator plus chain wiring |
| `src/` | all RTL, including the vendored r22sdf FFT core |
| `testbenches/` | self-checking testbenches |
| `fpga/` | AXI-Lite wrapper, Vitis bare-metal app, host checker |
| `r22sdf-master/` | upstream FFT licence |

Module names often do **not** match filenames — `src/zc_seq.v` defines
`zc_sequence_generator`, `src/add_cp.v` defines `parameterized_add_cp`, and so
on. Grep for `module`, not for filenames.

## Simulation

Everything elaborates as plain **Verilog-2001**; `-g2012` is not required and
not needed by Vivado. `-I src` is required because `src/ifft_64.v` `` `include ``s
bare filenames.

```sh
# lint the whole tree
iverilog -Wall -t null -I src full.v src/*.v testbenches/*.v

# strict lint: must be warning-free on both tops
verilator --lint-only -Wall -Isrc --top-module ofdm_generate_frame full.v
verilator --lint-only -Wall -Isrc --top-module ofdm_axi_lite fpga/ofdm_axi_lite.v full.v

# run a testbench (list the DUT explicitly; there is no auto-discovery)
iverilog -I src -o /tmp/sim.vvp src/zc_seq.v testbenches/tb_zc_seq.v && vvp /tmp/sim.vvp
iverilog -I src -o /tmp/sim.vvp full.v   testbenches/tb_full.v      && vvp /tmp/sim.vvp
iverilog -I src -o /tmp/sim.vvp full.v   testbenches/tb_ofdm_frame.v && vvp /tmp/sim.vvp
iverilog -I src -o /tmp/sim.vvp full.v fpga/ofdm_axi_lite.v \
                                  testbenches/tb_ofdm_axi_lite.v   && vvp /tmp/sim.vvp
```

Note the Verilator flag is `-Isrc` with no space — `-I src` is an Icarus spelling
and Verilator rejects it.

Both `verilator --lint-only -Wall` runs are warning-free, and CI enforces it. The
handful of warnings that *are* intentional are waived inline with
`/* verilator lint_off RULE */` directly above the code they cover, each with a
comment saying why. There are no global `-Wno-` flags, so a genuinely new
warning fails the build. Current waivers:

| Rule | Where | Why |
| --- | --- | --- |
| `WIDTHTRUNC` | `Butterfly.v`, `Multiply.v`, `SdfUnit.v` | Vendored r22sdf; the fixed-point `>>>` scaling narrows on purpose |
| `DECLFILENAME` | `zc_seq.v`, `map_to_subcarriers.v`, `add_cp.v`, `full.v`, `FFT64.v`, `Twiddle64.v` | Module name intentionally differs from the filename used by the build commands |
| `UNUSEDSIGNAL` | `full.v` | `parallel_to_serial.frame_done` is driven but unread (see below) |
| `UNUSEDSIGNAL` | `ifft_64.v` | `br_overflow` is not propagated to the port list (see Known limitations) |
| `UNUSEDSIGNAL` | `ofdm_axi_lite.v` | `s_axi_wstrb` and the `[1:0]` byte lane of the AXI addresses are intentionally ignored |

Two Verilator gotchas if you extend this: `-file "glob"` inside a `lint_off`
metacomment is a **syntax error** (so vendored-file waivers must live in the
vendored file), and a comment whose first word is `verilator` is parsed as a
pragma directive, not prose.

Testbenches print `[PASS]`/`[FAIL]` lines and an `error_count` summary, then
always exit 0 — **read the output, do not trust `$?`**.

Accuracy against the floating-point model:

- IFFT: max **2 LSB** (radix-2² per-stage truncation).
- Full 320-word frame: max **2 LSB** (`tb_full.v`, live real-arithmetic golden).
- `fpga/check_frame.py` against the RTL: max **1.6 LSB**.

`testbenches/tb_full.v` computes its golden IFFT live and drives a pseudo-random
payload; `testbenches/tb_ofdm_frame.v` compares against a generated table of
absolute values. They are independent on purpose — agreement between them is
what makes the end-to-end result meaningful.

## FPGA bring-up (Zynq-7000 / ZedBoard)

The design is a plain AXI4-Lite slave. There is no streaming interface and no
DDR traffic: the core generates one frame, is held in reset, and software reads
the 320 words back over AXI. Frame storage is **flip-flops, not BRAM** (~10,240
FFs plus a 320:1 × 32-bit read mux), so watch utilisation and post-synthesis
timing on that mux.

### Vivado

1. Create a project targeting your Zynq device, enable `FCLK_CLK0` (50 MHz is
   assumed by the `FREQ_HZ` attribute in `fpga/ofdm_axi_lite.v` — change it if
   you use a different clock).
2. Block design: add `Zynq PS7` with **Enable FCLK_CLK0** and **DDR off**.
3. Run Block Automation to export `FCLK_CLK0` and `FCLK_RESET0_N`.
4. Add `fpga/ofdm_axi_lite.v` as a module. It should appear with an
   `s_axi` AXI4-Lite interface — the `XIL_INTERFACENAME` attributes make this
   explicit rather than relying on Vivado's port-name inference.
5. Connect `s_axi_aclk` ← `FCLK_CLK0`, `s_axi_aresetn` ← `FCLK_RESET0_N`
   **directly** — `FCLK_RESET0_N` is already active-low, like
   `s_axi_aresetn`, so no inverter is needed. Let Connection Automation wire
   the AXI-Lite port.
6. Add an XDC constraining `s_axi_aclk` to your `FCLK_CLK0` period (20 ns for
   50 MHz), otherwise timing analysis reports the clock unconstrained.
7. Validate, then Generate Bitstream.

Set include directories to the repo root and `src/` if you ever add the RTL as
design sources directly; `full.v` uses `src/`-prefixed paths.

### Vitis (standalone)

1. Create a standalone (bare-metal, `xstandalone` platform) application.
2. In the BSP settings, enable the **`xilffs`** FatFs library so `ff.h` exists.
3. Check the drive string in the BSP's `ffs.c` matches what `main.c` passes to
   `f_mount` (`"0:/"`). On some Vitis versions this needs editing.
4. Copy `fpga/main.c` into the application `src/`.
5. Set `OFDM_BASE` in `main.c` to whatever the Vivado Address Editor assigned.
6. Build, program the FPGA, and run.

### SD card flow

`main.c` reads a 16-byte payload from `qpsk.bin` at the card root, writes the
frame to `frame.bin` at the card root, and prints progress over UART.

```sh
python3 fpga/check_frame.py gen qpsk.bin 1        # make a payload
# ... run on board, copy frame.bin back ...
python3 fpga/check_frame.py check qpsk.bin frame.bin
```

`check_frame.py` needs numpy. `check_frame.py check` exits non-zero on failure
and prints a per-symbol LSB error and a cyclic-prefix exactness check.

File formats, all little-endian:

- `qpsk.bin` — 16 bytes = `qpsk_bits[127:0]`, byte 0 holds bits 7:0.
- `frame.bin` — 320 × `u32`, each `{re[31:16], im[15:0]}` signed Q1.15,
  symbol `s` at words `80*s .. 80*s+79` (16 CP then 64 body).

### Register map

Byte offsets from the base address:

| Offset | Name | Access | Meaning |
| --- | --- | --- | --- |
| `0x000` | `CTRL` | RW | bit0 = run. 0 holds the core in reset and clears `done`; 1 runs until the first frame completes, then freezes it |
| `0x004` | `STATUS` | RO | bit0 = done, bit1 = busy |
| `0x008..0x014` | `QPSK0..3` | RW | `qpsk_bits` |
| `0x018` | `ID` | RO | `0x0FDA0001` |
| `0x400 + 4n` | `FRAME[n]` | RO | `n = 0..319`, word = `{re, im}` |

Sequence: write `CTRL=0`, write `QPSK0..3`, write `CTRL=1`, poll `STATUS.done`,
then read the 320 words. To re-run, write `CTRL=0` again first — that is what
clears `done`.

## Known limitations

- Frame storage is flip-flops, not block RAM.
- The AXI write channel requires `AWVALID` and `WVALID` together. Legal AXI, but
  it would deadlock a master that waits for `AWREADY` before asserting
  `WVALID`; the Xilinx interconnect sends both, so this is fine in practice.
- `wstrb` is ignored; use full 32-bit writes.
- Negating `16'h8000` is a no-op in `ifft_64.v`, so a full-scale −1.0 input is
  off by one LSB.
- `src/uart_rx.v` is unrelated to the OFDM chain and has no testbench.