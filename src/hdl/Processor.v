`timescale 1ns / 1ps
`include "defs.vh"

module Processor(
    input clk, 
    output halt, 
    input reset, 
    output reg [7:0] pc, 
    input [31:0] ins, 
    output [31:0] io_reg1, 
    output [31:0] io_reg2, 
    output [31:0] io_reg3, 
    output [31:0] io_reg4
);

    // --- Combinational Wires (Cycle 1) ---
    wire [5:0] opcode;             
    wire [5:0] func;               
    wire [4:0] shift_amount;       
    wire [4:0] src1_addr;          
    wire [4:0] src2_addr;          
    wire [31:0] src1;              
    wire [31:0] src2;              
    wire [4:0] dest_addr;          
    wire [15:0] imm;               

    // --- Inter-Stage Registers (Cycle 1 -> Cycle 2) ---
    reg [5:0]  opcode_reg;
    reg [5:0]  func_reg;
    reg [4:0]  shift_amount_reg;
    reg [31:0] src1_reg;
    reg [31:0] alu_src2_reg;
    reg [4:0]  dest_addr_reg;

    // --- Combinational Wires (Cycle 2) ---
    wire [31:0] dest_data;         
    wire dest_data_valid;          

    // --- Inter-Stage Registers (Cycle 2 -> Cycle 3) ---
    reg [31:0] dest_data_reg;
    reg dest_valid_reg;

    // --- FSM States ---
    reg [1:0] state;
    localparam S_FETCH_READ = 2'd0; // Cycle 1
    localparam S_EXECUTE    = 2'd1; // Cycle 2
    localparam S_WRITEBACK  = 2'd2; // Cycle 3

    // --- System / Control Registers ---
    reg [31:0] io_reg [0:3];       
    reg [1:0] io_reg_index;        
    reg fetched;                   
    reg halt_reg;

    assign halt = halt_reg;
    assign io_reg1 = io_reg[0];
    assign io_reg2 = io_reg[1];
    assign io_reg3 = io_reg[2];
    assign io_reg4 = io_reg[3];

    // --- Decode Instruction (Combinational in Cycle 1) ---
    assign opcode = ins[31:26];
    assign src1_addr = ins[25:21]; // rs
    assign src2_addr = ins[20:16]; // rt
    assign dest_addr = (opcode == `OP_REG) ? ins[15:11] : ins[20:16]; 
    assign shift_amount = ins[10:6];
    assign func = ins[5:0];
    assign imm = ins[15:0];

    // Extend the immediate value
    wire [31:0] sign_ext_imm = {{16{imm[15]}}, imm}; 
    wire [31:0] zero_ext_imm = {16'b0, imm};         
    
    // Mux for the ALU's second input (Evaluated in Cycle 1)
    wire [31:0] alu_src2 = (opcode == `OP_REG) ? src2 : 
                           ((opcode == `OP_ANDI) || (opcode == `OP_ORI) || (opcode == `OP_XORI)) ? zero_ext_imm : 
                           sign_ext_imm;

    // --- Structural PC Increment ---
    wire [31:0] pc_plus_one_32;
    RippleCarryAdder32 pc_adder(
        .A({24'b0, pc}),
        .B(32'd1),
        .Sum(pc_plus_one_32)
    );
    wire [7:0] pc_next = pc_plus_one_32[7:0];

    // --- Module Instantiations ---
    
    // Register File Reads in Cycle 1, Writes in Cycle 3
    RegisterFile rf (
        src1_addr, 
        src2_addr, 
        src1, 
        src2, 
        dest_addr_reg,     // From Cycle 1 register
        dest_data_reg,     // From Cycle 2 register
        dest_valid_reg,    // From Cycle 2 register
        clk
    );

    // ALU Executes in Cycle 2 based purely on registered inputs
    ALU alu (
        src1_reg,          // Registered!
        alu_src2_reg,      // Registered!
        shift_amount_reg,  // Registered!
        opcode_reg,        // Registered!
        func_reg,          // Registered!
        dest_data,         
        dest_data_valid    
    );

    // --- Sequential Logic (The Three-State FSM) ---
    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'b0;
            io_reg_index <= 2'b0;
            fetched <= 1'b0;
            state <= S_FETCH_READ;
            halt_reg <= 1'b0;
            dest_valid_reg <= 1'b0;
        end
        else begin
            case (state)
                S_FETCH_READ: begin
                    fetched <= 1'b1;
                    if (!halt_reg) begin
                        // Load Cycle 1 -> Cycle 2 inter-stage registers
                        opcode_reg <= opcode;
                        func_reg <= func;
                        shift_amount_reg <= shift_amount;
                        src1_reg <= src1;
                        alu_src2_reg <= alu_src2;
                        dest_addr_reg <= dest_addr;
                        
                        state <= S_EXECUTE;
                    end
                end

                S_EXECUTE: begin
                    if (!halt_reg) begin
                        // Load Cycle 2 -> Cycle 3 inter-stage registers
                        dest_data_reg <= dest_data;
                        dest_valid_reg <= dest_data_valid;
                        
                        // Determine Halt combinationally in the execute stage
                        if ((opcode_reg == `OP_REG) && (func_reg == `FUNC_SYSCALL) && (src1_reg == `SYS_exit)) begin
                            halt_reg <= 1'b1;
                        end

                        state <= S_WRITEBACK;
                    end
                end

                S_WRITEBACK: begin
                    // Pulse write enable off immediately after this cycle
                    dest_valid_reg <= 1'b0; 

                    if (!halt_reg) begin
                        pc <= pc_next; // Strict structural update using pc_adder!
                        state <= S_FETCH_READ;
                    end
                end
            endcase
        end
    end

    // --- I/O Syscall Logic (Negedge) ---
    // Moved to the execute cycle (Cycle 2) as required by Milestone 3
    always @(negedge clk) begin
        if (state == S_EXECUTE) begin
            if ((opcode_reg == `OP_REG) && (func_reg == `FUNC_SYSCALL) && (src1_reg == `SYS_write)) begin
                io_reg_index <= io_reg_index + 1;
                // alu_src2_reg holds the value of src2 (which is $rt) for OP_REG instructions
                io_reg[io_reg_index] <= alu_src2_reg; 
            end
        end
    end

endmodule
