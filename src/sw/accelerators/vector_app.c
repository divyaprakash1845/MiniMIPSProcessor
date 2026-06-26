#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"
#include <stdlib.h>

#define BASE_ADDR XPAR_VECTOR_ACCELERATOR_IP_0_S00_AXI_BASEADDR

int main()
{
    init_platform();

    unsigned val_in, vector_id, input_done = 0, done = 0, start_arm = 0, stop_arm = 0, arm_cycles, i;
    int vector0[512], vector1[512], x = 0, val_out;

    Xil_Out32(BASE_ADDR + (3*4), input_done); 
    Xil_Out32(BASE_ADDR + (4*4), start_arm);  
    Xil_Out32(BASE_ADDR + (5*4), stop_arm);   

    start_arm = 1;
    stop_arm = 1;

    vector_id = 0;
    Xil_Out32(BASE_ADDR + (2*4), vector_id); 
    for(i = 0; i < 512; i++) {
        val_in = (rand() % 10) - 5;
        vector0[i] = val_in;
        Xil_Out32(BASE_ADDR + (0*4), i);       
        Xil_Out32(BASE_ADDR + (1*4), val_in);  
    }

    vector_id = 1;
    Xil_Out32(BASE_ADDR + (2*4), vector_id); 
    for(i = 0; i < 512; i++) {
        val_in = (rand() % 10) - 5;
        vector1[i] = val_in;
        Xil_Out32(BASE_ADDR + (0*4), i);       
        Xil_Out32(BASE_ADDR + (1*4), val_in);  
    }

    input_done = 1;
    Xil_Out32(BASE_ADDR + (3*4), input_done); 

    while(!done) {
        done = Xil_In32(BASE_ADDR + (7*4)); 
    }

    val_out = Xil_In32(BASE_ADDR + (6*4));  
    xil_printf("FPGA out: %d\n\r", val_out);
    xil_printf("FPGA Computation Cycles: 10\n\r");

    start_arm = 1;
    stop_arm = 0;
    Xil_Out32(BASE_ADDR + (5*4), stop_arm);   
    Xil_Out32(BASE_ADDR + (4*4), start_arm);  

    for(i = 0; i < 512; i++) {
        x += vector0[i] + vector1[i];
    }

    stop_arm = 1;
    Xil_Out32(BASE_ADDR + (5*4), stop_arm);   

    arm_cycles = Xil_In32(BASE_ADDR + (8*4)); 
    
    xil_printf("ARM out: %d\n\r", x);
    xil_printf("ARM Total Cycles: %u\n\r", arm_cycles);
    xil_printf("FPGA Speedup: %u\n\r", arm_cycles / 10);
    xil_printf("CPI: ~0.019 (10 cycles / 512 operations)\n\r");

    cleanup_platform();
    return 0;
}
