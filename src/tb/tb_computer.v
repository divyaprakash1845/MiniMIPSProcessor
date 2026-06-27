`timescale 1ns / 1ps
`include "defs.vh"

module tb_computer;
    reg clk, reset, done_storing;
    reg [7:0] ins_addr;
    reg [31:0] ins;
    wire done;
    wire [31:0] out_reg1, out_reg2, out_reg3, out_reg4, total_cycles, proc_cycles;

    Computer uut(
        .reset(reset),
        .ins_addr(ins_addr),
        .ins(ins),
        .clk(clk),
        .done_storing(done_storing),
        .done(done),
        .out_reg1(out_reg1),
        .out_reg2(out_reg2),
        .out_reg3(out_reg3),
        .out_reg4(out_reg4),
        .total_cycles(total_cycles),
        .proc_cycles(proc_cycles)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1; done_storing = 0; ins_addr = 0; ins = 0;
        #20 reset = 0;
        
        // Let's load instructions to test the 3-cycle processor:
        // Instruction 0: addi $r1, $r0, 1001 (0x200103E9) (Loads SYS_exit into $r1)
        // Instruction 1: addi $r2, $r0, 42   (0x2002002A) (Loads 42 into $r2)
        // Instruction 2: add  $r3, $r1, $r2  (0x00221820) (Adds $r1 and $r2)
        // Instruction 3: syscall (with rs=$r1) (0x0020000C) (Triggers SYS_exit)

        @(posedge clk); ins_addr = 0; ins = 32'h200103E9;
        @(posedge clk); ins_addr = 1; ins = 32'h2002002A;
        @(posedge clk); ins_addr = 2; ins = 32'h00221820;
        @(posedge clk); ins_addr = 3; ins = 32'h0020000C;
        
        @(posedge clk); done_storing = 1;

        wait(done);
        $display("Processor halted successfully! Total cycles: %d, Proc cycles: %d", total_cycles, proc_cycles);
        $finish;
    end
endmodule
