#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"

#define BASE_ADDR XPAR_GRAPH_ACCELERATOR_IP_0_S00_AXI_BASEADDR

int main()
{
    init_platform();

    unsigned i, j, k, A[32], AT[32], B[32], input_done = 0;
    unsigned start_arm = 0, stop_arm = 0, val_in, path_length, val_out;
    unsigned start_vertex, end_vertex, done = 0, arm_cycles, count = 0;

    Xil_Out32(BASE_ADDR + (4*4), input_done); // reg4
    Xil_Out32(BASE_ADDR + (7*4), start_arm); // reg7
    Xil_Out32(BASE_ADDR + (8*4), stop_arm); // reg8

    start_arm = 1;
    stop_arm = 1;

    for (i = 0; i < 32; i++) {
        A[i] = 0;
        AT[i] = 0;
    }

    // Load Ring Graph Edges
    for (i = 0; i < 32; i++) {
        for (j = 0; j < 32; j++) {
            if ((j == ((i+1)%32)) || (j == ((i+31)%32))) {
                val_in = 1;
                A[i] = A[i] | (1<<j);
                AT[j] = AT[j] | (1<<i);
            } else {
                val_in = 0;
            }
            Xil_Out32(BASE_ADDR + (0*4), i); // reg0: edge_source
            Xil_Out32(BASE_ADDR + (1*4), j); // reg1: edge_dest
            Xil_Out32(BASE_ADDR + (2*4), val_in); // reg2: adjacency_val
        }
    }

    path_length = 31;
    Xil_Out32(BASE_ADDR + (3*4), path_length); // reg3

    // Trigger Accelerator
    input_done = 1;
    Xil_Out32(BASE_ADDR + (4*4), input_done); // reg4

    // Wait for FPGA
    while (!done) done = Xil_In32(BASE_ADDR + (10*4)); // reg10

    xil_printf("FPGA output: Pair of vertices having a path of length %u:\n\r", path_length);
    for (i = 0; i < 32; i++) {
        for (j = 0; j < 32; j++) {
            Xil_Out32(BASE_ADDR + (5*4), i); // reg5: start_vertex
            Xil_Out32(BASE_ADDR + (6*4), j); // reg6: end_vertex
            val_out = Xil_In32(BASE_ADDR + (9*4)); // reg9: is_there_path
            if (val_out) {
                xil_printf("(%u, %u) ", i, j);
                count++;
            }
        }
    }
    xil_printf("\n\rFPGA pair count: %u\n\r", count);
    
    // ARM Execution Tracking
    Xil_Out32(BASE_ADDR + (8*4), 0); // ensure stop_arm is 0
    Xil_Out32(BASE_ADDR + (7*4), 1); // start_arm

    for (i = 1; i < path_length; i++) {
        for (j = 0; j < 32; j++) {
            B[j] = 0;
            for (k = 0; k < 32; k++) {
                if (A[j] & AT[k]) B[j] = B[j] | (1<<k);
            }
            A[j] = B[j];
        }
    }

    Xil_Out32(BASE_ADDR + (8*4), 1); // stop_arm
    count = 0;

    xil_printf("ARM output: Pair of vertices having a path of length %u:\n\r", path_length);
    for (i = 0; i < 32; i++) {
        for (j = 0; j < 32; j++) {
            if ((A[i] >> j) & 0x1) {
                xil_printf("(%u, %u) ", i, j);
                count++;
            }
        }
    }
    
    arm_cycles = Xil_In32(BASE_ADDR + (11*4)); // reg11
    xil_printf("\n\rARM pair count: %u\n\r", count);
    xil_printf("ARM cycles: %u\n\r", arm_cycles);

    unsigned expected_fpga_cycles = 5 * (path_length - 1) + 1;
    xil_printf("FPGA execution cycles: %u\n\r", expected_fpga_cycles);
    xil_printf("Speedup (~1000 expected): %u\n\r", arm_cycles / expected_fpga_cycles);

    cleanup_platform();
    return 0;
}
