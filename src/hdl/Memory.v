`timescale 1ns / 1ps
`include "defs.vh"

module Memory(
    input write_enable, 
    input clk, 
    input command, 
    input [7:0] address, 
    input [31:0] word_in, 
    output [31:0] word_out
);

    reg [31:0] Mem [0:255];

    // Combinational Read: If command is READ_COMMAND, output the word at the address. 
    // Otherwise, output 0 (or high impedance depending on strict design, but 0 is safe here).
    assign word_out = (command == `READ_COMMAND) ? Mem[address] : 32'b0;

    // Sequential Write: Triggered on posedge clk
    always @ (posedge clk) begin
        if ((command == `WRITE_COMMAND) && (write_enable == 1'b1)) begin
            Mem[address] <= word_in; // Store word_in
        end
    end

endmodule
