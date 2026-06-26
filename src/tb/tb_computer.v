`timescale 1ns / 1ps
module tb_computer;
    reg clk, reset, done_storing, copied_io_regs, input_value_valid;
    reg [31:0] ins_addr, ins, input_value;
    wire done, io_stall, waiting_for_input;
    wire [31:0] io_reg_index, out0, out1, out2, out3, total_cycles, proc_cycles;

    Computer dut (
        .clk(clk), .reset(reset), .done_storing(done_storing), .copied_io_regs(copied_io_regs),
        .ins_addr(ins_addr), .ins(ins), .input_value(input_value), .input_value_valid(input_value_valid),
        .done(done), .io_stall(io_stall), .io_reg_index(io_reg_index),
        .out0(out0), .out1(out1), .out2(out2), .out3(out3),
        .total_cycles(total_cycles), .proc_cycles(proc_cycles), .waiting_for_input(waiting_for_input)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1; done_storing = 0; copied_io_regs = 0; input_value_valid = 0;
        #20 reset = 0;

        // Simple Test: print integer 5
        ins_addr = 0; ins = 32'h20020005; #10; // addi $2, $0, 5
        ins_addr = 1; ins = 32'h200103EC; #10; // addi $1, $0, 1004 (print)
        ins_addr = 2; ins = 32'h0020100C; #10; // syscall $1, $2
        ins_addr = 3; ins = 32'h200103E9; #10; // addi $1, $0, 1001 (exit)
        ins_addr = 4; ins = 32'h0020000C; #10; // syscall $1, $0
        
        done_storing = 1;

        wait(done);
        $display("Simulation Complete. Output: %d", out0);
        $finish;
    end
endmodule
