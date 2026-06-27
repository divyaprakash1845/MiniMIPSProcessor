`timescale 1ns / 1ps
`include "defs.vh"

module Computer(
    input reset, 
    input [7:0] ins_addr, 
    input [31:0] ins, 
    input clk, 
    input done_storing, 
    output reg done,
    output [31:0] out_reg1, 
    output [31:0] out_reg2, 
    output [31:0] out_reg3, 
    output [31:0] out_reg4, 
    output [31:0] total_cycles, 
    output [31:0] proc_cycles
);

    wire [7:0] pc;                 // Output of Processor [cite: 374, 375]
    wire [31:0] ins_fetched;       // Output of Memory [cite: 376]
    wire ins_mem_command;          // Input to Memory [cite: 376]
    
    reg [31:0] counter_total;      // Counts total_cycles [cite: 377, 378]
    reg [31:0] counter_proc;       // Counts proc_cycles [cite: 379, 380]
    wire halt;                     // Output of Processor [cite: 381, 382]

    // Instantiate Memory [cite: 387]
    // Write enable is active only when not resetting and not done storing
    // Address is either the external ins_addr (during loading) or PC (during execution)
    Memory mem(
        ~reset & ~done_storing, 
        clk,
        ins_mem_command, 
        done_storing ? pc : ins_addr, 
        ins,
        ins_fetched
    );

    // Instantiate Processor [cite: 388]
    // Processor is held in reset (~done_storing) while instructions are being loaded
    Processor proc(
        clk, 
        halt, 
        ~done_storing, 
        pc,
        ins_fetched, 
        out_reg1, 
        out_reg2, 
        out_reg3, 
        out_reg4
    );

    // Continuous assignments [cite: 390, 391, 392]
    assign total_cycles = counter_total;
    assign proc_cycles = counter_proc;
    assign ins_mem_command = done_storing ? `READ_COMMAND : `WRITE_COMMAND;

    // Sequential logic for cycle counting and completion [cite: 396]
    always @(posedge clk) begin
        if (reset) begin
            counter_total <= 32'b0; // [cite: 398]
            counter_proc  <= 32'b0; // [cite: 399]
            done          <= 1'b0;  // [cite: 400]
        end
        else begin
            // The system is done when the processor signals a halt
            done <= halt; 
            
            // Total cycles count up every clock cycle after reset
            counter_total <= counter_total + 1; 
            
            // Processor cycles only count when the processor is actively running
            // (after storing is done and before it halts)
            if (done_storing && !halt) begin
                counter_proc <= counter_proc + 1; 
            end
        end
    end

endmodule
