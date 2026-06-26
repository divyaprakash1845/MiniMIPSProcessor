#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"
#include <stdlib.h>

#define BASE_ADDR XPAR_MATRIX_ACCELERATOR_IP_0_S00_AXI_BASEADDR

int main()
{
    init_platform();

    unsigned val_in, vector_id, input_done = 0, done = 0, start_arm = 0, stop_arm = 0, arm_cycles, i, k;
    int vector0[16][16], vector1[16], vector_out[16], arm_vector_out[16];

    // Initialization
    Xil_Out32(BASE_ADDR + (4*4), input_done); 
    Xil_Out32(BASE_ADDR + (6*4), start_arm);  
    Xil_Out32(BASE_ADDR + (7*4), stop_arm);   

    start_arm = 1;
    stop_arm = 1;

    // Load Matrix M
    vector_id = 0;
    Xil_Out32(BASE_ADDR + (3*4), vector_id); 
    for(i = 0; i < 16; i++) {
        for (k = 0; k < 16; k++) {
            val_in = (rand() % 10) - 5;
            vector0[i][k] = val_in;
            Xil_Out32(BASE_ADDR + (0*4), i);       
            Xil_Out32(BASE_ADDR + (1*4), k);       
            Xil_Out32(BASE_ADDR + (2*4), val_in);  
        }
    }

    // Load Vector x
    vector_id = 1;
    Xil_Out32(BASE_ADDR + (3*4), vector_id); 
    for (i = 0; i < 16; i++) {
        val_in = (rand() % 10) - 5;
        vector1[i] = val_in;
        Xil_Out32(BASE_ADDR + (0*4), i);       
        Xil_Out32(BASE_ADDR + (2*4), val_in);  
    }

    input_done = 1;
    Xil_Out32(BASE_ADDR + (4*4), input_done); 

    while(!done) done = Xil_In32(BASE_ADDR + (9*4)); 

    xil_printf("FPGA out:\n\r");
    for (i = 0; i < 16; i++) {
        Xil_Out32(BASE_ADDR + (5*4), i); 
        vector_out[i] = Xil_In32(BASE_ADDR + (8*4)); 
        xil_printf("%d ", vector_out[i]);
    }
    xil_printf("\n\r");
    xil_printf("FPGA Computation Cycles: 112 (16 rows * 7 cycles/row)\n\r"); 

    start_arm = 1;
    stop_arm = 0;
    Xil_Out32(BASE_ADDR + (7*4), stop_arm);   
    Xil_Out32(BASE_ADDR + (6*4), start_arm);  

    for(i = 0; i < 16; i++) {
        arm_vector_out[i] = 0;
        for (k = 0; k < 16; k++) {
            arm_vector_out[i] += vector0[i][k] * vector1[k];
        }
    }

    stop_arm = 1;
    Xil_Out32(BASE_ADDR + (7*4), stop_arm);   

    arm_cycles = Xil_In32(BASE_ADDR + (10*4)); 
    
    xil_printf("ARM out:\n\r");
    for (i = 0; i < 16; i++) {
        xil_printf("%d ", arm_vector_out[i]);
    }
    xil_printf("\n\r");
    
    xil_printf("ARM Cycles: %u\n\r", arm_cycles);
    xil_printf("Speedup (ARM Cycles / 112): %d\n\r", arm_cycles / 112);

    cleanup_platform();
    return 0;
}
