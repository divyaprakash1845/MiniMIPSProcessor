#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"

// VERIFY THIS MATCHES YOUR xparameters.h FILE!
#define BASE_ADDR XPAR_MIPS_V2_IP_0_S00_AXI_BASEADDR

void execute_mips(unsigned int* code, int len, int print_char_mode, const char* title) {
    unsigned r = 1, a, ds = 0, d, tc, pc, wfi, ivv = 0, f, dcir = 0, cnt;
    int iv, o[4];

    xil_printf("\n\r===========================================\n\r");
    xil_printf("%s\n\r", title);
    xil_printf("===========================================\n\r");

    // 1. Safe Hardware Reset
    Xil_Out32(BASE_ADDR, r);
    Xil_Out32(BASE_ADDR + 12, ds);
    Xil_Out32(BASE_ADDR + 16, dcir);
    Xil_Out32(BASE_ADDR + 24, ivv);
    r = 0; Xil_Out32(BASE_ADDR, r);

    // 2. Push Machine Code
    for (a = 0; a < len; a++) {
        Xil_Out32(BASE_ADDR + 4, a);
        Xil_Out32(BASE_ADDR + 8, code[a]);
    }
    
    // 3. Start Execution
    ds = 1; Xil_Out32(BASE_ADDR + 12, ds);

    // 4. AXI Polling Handshake Loop
    while (1) {
        f = 0; d = 0; wfi = 0;
        while (!f && !d && !wfi) {
            f = Xil_In32(BASE_ADDR + 56);
            d = Xil_In32(BASE_ADDR + 28);
            wfi = Xil_In32(BASE_ADDR + 64);
        }

        if (wfi) {
            xil_printf("Enter Input (Press Ctrl+J to submit): ");
            scanf("%d", &iv);
            xil_printf("%d\n\r", iv); 
            
            Xil_Out32(BASE_ADDR + 20, iv);
            ivv = 1; Xil_Out32(BASE_ADDR + 24, ivv); 
            ivv = 0; Xil_Out32(BASE_ADDR + 24, ivv); 
        }

        if (f) {
            for(int i=0; i<4; i++) o[i] = Xil_In32(BASE_ADDR + 32 + (i*4));
            
            dcir = 1; Xil_Out32(BASE_ADDR + 16, dcir); 
            dcir = 0; Xil_Out32(BASE_ADDR + 16, dcir); 
            
            for (int i = 0; i < 4; i++) {
                if (print_char_mode) xil_printf("%c", o[i]);
                else xil_printf("Intermediate Out: %d\n\r", o[i]);
            }
        }
        
        if (d) {
            cnt = Xil_In32(BASE_ADDR + 60);
            for(int i=0; i<cnt; i++) {
                int val = Xil_In32(BASE_ADDR + 32 + (i*4));
                if (print_char_mode) xil_printf("%c", val);
                else xil_printf("Final Out: %d\n\r", val);
            }
            
            // STRICT INTEGER MATH FOR CPI (Avoids %f float crash)
            tc = Xil_In32(BASE_ADDR + 48);
            pc = Xil_In32(BASE_ADDR + 52);
            int cpi_w = pc / len;
            int cpi_f = ((pc * 100) / len) % 100;
            
            xil_printf("\n\r[Status] Total Cycles: %d | Comp Cycles: %d | CPI: %d.%02d\n\r", tc, pc, cpi_w, cpi_f);
            break; 
        }
    }
}

int main() {
    init_platform();

    unsigned int p1[] = {
        0x3C014865, 0x34216C6C, 0xAC010200, 0x3C016F20, 0x3421576F, 0xAC010204, 
        0x3C01726C, 0x34216421, 0xAC010208, 0x2001000A, 0xA001020C, 0x20110000, 
        0x2012000D, 0x0232402A, 0x11000007, 0x20090200, 0x01314820, 0x91300000, 
        0x200103EC, 0x0020800C, 0x22310001, 0x0800000D, 0x200103E9, 0x0020000C
    };

    unsigned int p2[] = {
        0x200103EB, 0x0020800C, 0x200103EB, 0x0020880C, 0x2A080200, 0x15000007, 
        0x32080001, 0x15000005, 0x00114040, 0x02084020, 0x29090401, 0x11200001, 
        0x0800000F, 0x00008020, 0x08000026, 0x00009020, 0x0251402A, 0x1100000A, 
        0x32480001, 0x15000002, 0x02404820, 0x08000017, 0x00124822, 0x00125040, 
        0x020A5020, 0xA5490000, 0x22520001, 0x08000010, 0x00009020, 0x00009820, 
        0x0251402A, 0x11000006, 0x00125040, 0x020A5020, 0x85490000, 0x02699820, 
        0x22520001, 0x0800001E, 0x02608020, 0x200103EC, 0x0020800C, 0x200103E9, 0x0020000C
    };

    unsigned int p3[] = {
        0x201D0400, 0x200103EB, 0x0020800C, 0x2A080000, 0x15000004, 0x02002020, 
        0x0C00000E, 0x00408020, 0x0800000A, 0x2010FFFF, 0x200103EC, 0x0020800C, 
        0x200103E9, 0x0020000C, 0x23BDFFF8, 0xAFBF0004, 0xAFA40000, 0x14800003, 
        0x00001020, 0x23BD0008, 0x03E00008, 0x2084FFFF, 0x0C00000E, 0x8FA40000, 
        0x00821020, 0x8FBF0004, 0x23BD0008, 0x03E00008
    };
    
    execute_mips(p1, sizeof(p1)/4, 1, "PROGRAM 1: HELLO WORLD (LBU test)");
    execute_mips(p2, sizeof(p2)/4, 0, "PROGRAM 2: ARRAY MATH (LH/SH test)");
    execute_mips(p3, sizeof(p3)/4, 0, "PROGRAM 3: RECURSIVE SUM (JAL/$sp test)");

    xil_printf("\n\r===========================================\n\r");
    xil_printf("ALL HARDWARE TESTS COMPLETED.\n\r");

    cleanup_platform();
    return 0;
}
