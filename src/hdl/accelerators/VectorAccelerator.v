`timescale 1ns / 1ps

// 1. STRUCTURAL FULL ADDER
module FullAdder(
    input a,
    input b,
    input cin,
    output sum,
    output cout
);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));
endmodule

// 2. STRUCTURAL 32-BIT RIPPLE CARRY ADDER
module RippleCarryAdder32(
    input [31:0] A,
    input [31:0] B,
    output [31:0] Sum
);
    wire [32:0] C;
    assign C[0] = 1'b0;
    
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : fa_gen
            FullAdder fa(
                .a(A[i]),
                .b(B[i]),
                .cin(C[i]),
                .sum(Sum[i]),
                .cout(C[i+1])
            );
        end
    endgenerate
endmodule

// 3. MAIN ACCELERATOR MODULE
module VectorAccelerator (
    input wire clk,
    input wire [8:0] index,
    input wire [31:0] value,
    input wire vector_id,
    input wire input_done,
    input wire start_arm,
    input wire stop_arm,
    
    output reg [31:0] reduction_result,
    output reg done,
    output reg [31:0] arm_cycles
);

    reg [31:0] v0 [0:511];
    reg [31:0] v1 [0:511];
    reg [31:0] v2 [0:511];
    
    reg [3:0] state = 0;
    reg [31:0] arm_cycles_reg = 0;

    // Structural Adder for ARM Cycle Counter (No behavioral '+' allowed)
    wire [31:0] next_arm_cycles;
    RippleCarryAdder32 cycle_counter_adder (
        .A(arm_cycles_reg),
        .B(32'd1),
        .Sum(next_arm_cycles)
    );

    // FSM Control
    always @(posedge clk) begin
        case(state)
            0: if (input_done) state <= 1;
            1: state <= 2;
            2: state <= 3;
            3: state <= 4;
            4: state <= 5;
            5: state <= 6;
            6: state <= 7;
            7: state <= 8;
            8: state <= 9;
            9: state <= 10;
            10: state <= 11;
            11: begin
                if (start_arm && !stop_arm) begin
                    arm_cycles_reg <= next_arm_cycles; // Structural increment
                end
            end
            default: state <= 0;
        endcase
    end

    // Output Mapping
    always @(posedge clk) begin
        if (state == 11) begin
            done <= 1;
            reduction_result <= v2[0];
            arm_cycles <= arm_cycles_reg;
        end else begin
            done <= 0;
            reduction_result <= 0;
        end
    end

    // Parallel Structural Datapath & Single-Driver Memory Array
    genvar j;
    generate
        for (j = 0; j < 512; j = j + 1) begin : vector_operations
            wire [31:0] a_in;
            wire [31:0] b_in;
            wire [31:0] rca_sum;

            // Mux Operand A
            assign a_in = (state == 1) ? v0[j] : v2[j];

            // Mux Operand B (Ternary protection against out-of-bounds synthesis)
            assign b_in = (state == 1) ? v1[j] :
                          (state == 2 && j < 256) ? v2[(j < 256) ? j+256 : 0] :
                          (state == 3 && j < 128) ? v2[(j < 128) ? j+128 : 0] :
                          (state == 4 && j < 64) ? v2[(j < 64) ? j+64 : 0] :
                          (state == 5 && j < 32) ? v2[(j < 32) ? j+32 : 0] :
                          (state == 6 && j < 16) ? v2[(j < 16) ? j+16 : 0] :
                          (state == 7 && j < 8) ? v2[(j < 8) ? j+8 : 0] :
                          (state == 8 && j < 4) ? v2[(j < 4) ? j+4 : 0] :
                          (state == 9 && j < 2) ? v2[(j < 2) ? j+2 : 0] :
                          (state == 10 && j < 1) ? v2[(j < 1) ? j+1 : 0] : 32'b0;

            // Instantiate 1 Structural RCA per vector index
            RippleCarryAdder32 rca_inst (
                .A(a_in), 
                .B(b_in), 
                .Sum(rca_sum)
            );

            // Single Driver Memory Writes
            always @(posedge clk) begin
                if (state == 0) begin
                    if (index == j && vector_id == 0) v0[j] <= value;
                    if (index == j && vector_id == 1) v1[j] <= value;
                end 
                else if (state == 1) v2[j] <= rca_sum;
                else if (state == 2 && j < 256) v2[j] <= rca_sum;
                else if (state == 3 && j < 128) v2[j] <= rca_sum;
                else if (state == 4 && j < 64) v2[j] <= rca_sum;
                else if (state == 5 && j < 32) v2[j] <= rca_sum;
                else if (state == 6 && j < 16) v2[j] <= rca_sum;
                else if (state == 7 && j < 8) v2[j] <= rca_sum;
                else if (state == 8 && j < 4) v2[j] <= rca_sum;
                else if (state == 9 && j < 2) v2[j] <= rca_sum;
                else if (state == 10 && j < 1) v2[j] <= rca_sum;
            end
        end
    endgenerate

endmodule
