/*
 * Bare-metal Zynq-7000 app for the OFDM frame generator.
 *
 *   SD:qpsk.bin (16 bytes) -> AXI-Lite regs -> ofdm core -> 320 words -> SD:frame.bin (1280 bytes)
 *
 * Vitis setup: standalone BSP with the "xilffs" library enabled (SD, FAT32).
 * Set OFDM_BASE to the base address shown in the Vivado Address Editor.
 *
 * Every failure path prints the FatFs FRESULT and, for a short read/write, the
 * byte count actually transferred. An earlier revision printed only
 * "ERROR: SD mount failed", which is indistinguishable from a missing card, an
 * exFAT card, an unmounted BSP drive and a disabled PS SDIO peripheral -- the
 * FRESULT is what separates them.
 *
 * File formats (all little-endian):
 *   qpsk.bin  : 16 bytes = qpsk_bits[127:0], byte 0 is bits 7:0
 *   frame.bin : 320 x u32, each {re[31:16], im[15:0]} (signed Q1.15)
 */

#include <stdio.h>
#include "xil_types.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "ff.h"

#define OFDM_BASE      0x43C00000U      /* <-- match the Address Editor */

#define REG_CTRL       0x000
#define REG_STATUS     0x004
#define REG_QPSK0      0x008            /* 4 consecutive words */
#define REG_ID         0x018
#define FRAME_OFFSET   0x400

#define STATUS_DONE    0x1U
#define OFDM_ID        0x0FDA0001U
#define N_WORDS        320
#define POLL_LIMIT     1000000U

static FATFS fs;
static u32 qpsk_words[4]        __attribute__((aligned(32)));
static u32 frame_words[N_WORDS] __attribute__((aligned(32)));

static int read_qpsk(const char *path)
{
    FIL f;
    UINT br = 0;
    FRESULT r;

    r = f_open(&f, path, FA_READ);
    if (r != FR_OK) {
        xil_printf("f_open(%s) FRESULT=%d\r\n", path, (int)r);
        return -1;
    }
    r = f_read(&f, qpsk_words, sizeof(qpsk_words), &br);
    f_close(&f);
    if (r != FR_OK) {
        xil_printf("f_read FRESULT=%d\r\n", (int)r);
        return -2;
    }
    if (br != sizeof(qpsk_words)) {
        xil_printf("qpsk.bin short read: %u bytes (need %u)\r\n",
                   br, (unsigned)sizeof(qpsk_words));
        return -3;
    }
    return 0;
}

static int write_frame(const char *path)
{
    FIL f;
    UINT bw = 0;
    FRESULT r;

    r = f_open(&f, path, FA_WRITE | FA_CREATE_ALWAYS);
    if (r != FR_OK) {
        xil_printf("f_open(%s) FRESULT=%d\r\n", path, (int)r);
        return -1;
    }
    r = f_write(&f, frame_words, sizeof(frame_words), &bw);
    f_close(&f);
    if (r != FR_OK) {
        xil_printf("f_write FRESULT=%d\r\n", (int)r);
        return -2;
    }
    if (bw != sizeof(frame_words)) {
        xil_printf("short write: %u bytes (need %u)\r\n",
                   bw, (unsigned)sizeof(frame_words));
        return -3;
    }
    return 0;
}

int main(void)
{
    FRESULT mr;
    int r;

    xil_printf("\r\nOFDM frame generator on Zynq\r\n");

    /* Check the core is present */
    u32 id = Xil_In32(OFDM_BASE + REG_ID);
    if (id != OFDM_ID) {
        xil_printf("ERROR: ID reg = 0x%08x, expected 0x%08x. Check OFDM_BASE / bitstream.\r\n",
                   id, OFDM_ID);
        return -1;
    }

    /* Mount SD (prints the real error code on failure) */
    mr = f_mount(&fs, "0:/", 1);
    if (mr != FR_OK) {
        xil_printf("ERROR: SD mount failed, FRESULT=%d\r\n", (int)mr);
        xil_printf("  1=DISK_ERR 3=NOT_READY 12=NOT_ENABLED 13=NO_FILESYSTEM\r\n");
        return -1;
    }
    xil_printf("SD mounted\r\n");

    /* Read payload bits */
    r = read_qpsk("0:/qpsk.bin");
    if (r != 0) {
        xil_printf("ERROR: could not read 16 bytes from qpsk.bin (%d)\r\n", r);
        return -1;
    }

    /* Reset core and clear done, load payload bits, then run. */
    Xil_Out32(OFDM_BASE + REG_CTRL, 0);
    for (int i = 0; i < 4; i++)
        Xil_Out32(OFDM_BASE + REG_QPSK0 + 4 * i, qpsk_words[i]);
    Xil_Out32(OFDM_BASE + REG_CTRL, 1);

    /* Wait for done */
    u32 polls = 0;
    while (!(Xil_In32(OFDM_BASE + REG_STATUS) & STATUS_DONE)) {
        if (++polls > POLL_LIMIT) {
            xil_printf("ERROR: timeout waiting for frame done\r\n");
            return -1;
        }
    }
    xil_printf("Frame done after %u polls\r\n", polls);

    /* Read frame out of the core */
    for (int n = 0; n < N_WORDS; n++)
        frame_words[n] = Xil_In32(OFDM_BASE + FRAME_OFFSET + 4 * n);

    /* Write to SD */
    r = write_frame("0:/frame.bin");
    if (r != 0) {
        xil_printf("ERROR: could not write frame.bin (%d)\r\n", r);
        return -1;
    }

    xil_printf("Wrote frame.bin (%d bytes). Check it on the host with check_frame.py\r\n",
               (int)sizeof(frame_words));
    return 0;
}
