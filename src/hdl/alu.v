`timescale 1ns / 1ps
`include "defs.vh"

module ALU (
    input [31:0] src1, 
    input [31:0] src2, 
    input [4:0] shift_amount, 
    input [5:0] opcode, 
    input [5:0] func, 
    output [31:0] dest, 
    output dest_valid
);

    reg [31:0] result;
    reg result_valid;

    assign dest = result;            
    assign dest_valid = result_valid; 

    // --- Strict Structural Arithmetic ---
    wire is_sub = (opcode == `OP_REG && func == `FUNC_SUB);
    wire [31:0] add_sub_b = is_sub ? ~src2 : src2;
    wire [31:0] add_sum;
    
    // +1 for subtraction (2's complement) using our strict RippleCarryAdder32
    wire [31:0] sub_b_plus_one;
    RippleCarryAdder32 rca_sub_inc (.A(~src2), .B(32'd1), .Sum(sub_b_plus_one));
    
    wire [31:0] adder_b = is_sub ? sub_b_plus_one : src2;
    RippleCarryAdder32 rca_main (.A(src1), .B(adder_b), .Sum(add_sum));

    always @(*) begin
        // Default assignments to prevent inferred latches
        result = 32'b0;
        result_valid = 1'b0;

        case (opcode)
            `OP_REG: begin
                case (func)
                    // Shift operations (using shift_amount)
                    `FUNC_SLL: begin result = src2 << shift_amount; result_valid = 1'b1; end
                    `FUNC_SRL: begin result = src2 >> shift_amount; result_valid = 1'b1; end
                    `FUNC_SRA: begin result = $signed(src2) >>> shift_amount; result_valid = 1'b1; end
                    
                    // Variable shift operations (using src1)
                    `FUNC_SLLV: begin result = src2 << src1[4:0]; result_valid = 1'b1; end
                    `FUNC_SRLV: begin result = src2 >> src1[4:0]; result_valid = 1'b1; end
                    `FUNC_SRAV: begin result = $signed(src2) >>> src1[4:0]; result_valid = 1'b1; end
                    
                    // Arithmetic and Logical operations (Using Structural Adder for ADD/SUB)
                    `FUNC_ADD: begin result = add_sum; result_valid = 1'b1; end
                    `FUNC_SUB: begin result = add_sum; result_valid = 1'b1; end
                    `FUNC_AND: begin result = src1 & src2; result_valid = 1'b1; end
                    `FUNC_OR:  begin result = src1 | src2; result_valid = 1'b1; end
                    `FUNC_XOR: begin result = src1 ^ src2; result_valid = 1'b1; end
                    `FUNC_NOR: begin result = ~(src1 | src2); result_valid = 1'b1; end
                    
                    // Syscall
                    `FUNC_SYSCALL: begin 
                        result = 32'b0; 
                        result_valid = 1'b0; // Handled sequentially in Processor module
                    end
                endcase
            end
            
            // Immediate operations
            `OP_ADDI: begin result = add_sum; result_valid = 1'b1; end // Using Structural Adder
            `OP_ANDI: begin result = src1 & src2; result_valid = 1'b1; end
            `OP_ORI:  begin result = src1 | src2; result_valid = 1'b1; end
            `OP_XORI: begin result = src1 ^ src2; result_valid = 1'b1; end
        endcase
    end

endmodule
