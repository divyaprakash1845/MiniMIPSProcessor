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

// 3. MAIN MATRIX ACCELERATOR MODULE
module MatrixAccelerator (
    input wire clk,
    input wire [3:0] row_id,
    input wire [3:0] col_id,
    input wire [31:0] value,
    input wire vector_id, // 0 for M, 1 for x
    input wire input_done,
    input wire [3:0] index, // requested index to output y
    input wire start_arm,
    input wire stop_arm,

    output reg [31:0] y_val_out,
    output reg done,
    output reg [31:0] arm_cycles
);

    reg [31:0] M [0:15][0:15];
    reg [31:0] x [0:15];
    reg [31:0] y [0:15];
    reg [31:0] v [0:15];
    reg [31:0] w [0:15];

    reg [3:0] state = 0;
    reg [3:0] current_row = 0;
    reg [31:0] arm_cycles_reg = 0;

    // Structural Adder for ARM Cycle Counter (No behavioral '+' allowed)
    wire [31:0] next_arm_cycles;
    RippleCarryAdder32 cycle_counter_adder (
        .A(arm_cycles_reg),
        .B(32'd1),
        .Sum(next_arm_cycles)
    );

    // FSM State Control & Single-Driver Memory Assignments
    always @(posedge clk) begin
        if (state == 0) begin
            if (vector_id == 0) M[row_id][col_id] <= value;
            if (vector_id == 1) x[row_id] <= value; 
            if (input_done) begin
                state <= 1;
                current_row <= 0;
            end
        end
        else begin
            case(state)
                1: state <= 2;
                2: state <= 3;
                3: state <= 4;
                4: state <= 5;
                5: state <= 6;
                6: state <= 7;
                7: begin
                    y[current_row] <= w[0]; // Capture structural reduction result
                    if (current_row == 15) begin
                        state <= 8;
                    end else begin
                        current_row <= current_row + 1; // Counter increment allowed for FSM control
                        state <= 1;
                    end
                end
                8: begin
                    if (start_arm && !stop_arm) begin
                        arm_cycles_reg <= next_arm_cycles; // Structural increment
                    end
                end
                default: state <= 0;
            endcase
        end
    end

    // Parallel Structural Computations (v, w) mapped via Generate
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : compute_blocks
            
            // Route inputs for the structural Ripple Carry Adder
            wire [31:0] a_in = w[i];
            wire [31:0] b_in = (state == 3 && i < 8) ? w[(i < 8) ? i+8 : 0] :
                               (state == 4 && i < 4) ? w[(i < 4) ? i+4 : 0] :
                               (state == 5 && i < 2) ? w[(i < 2) ? i+2 : 0] :
                               (state == 6 && i == 0) ? w[1] : 32'b0;
            wire [31:0] rca_sum;

            // Instantiate 1 Structural RCA per vector index
            RippleCarryAdder32 rca_inst (
                .A(a_in), 
                .B(b_in), 
                .Sum(rca_sum)
            );

            always @(posedge clk) begin
                if (state == 1) v[i] <= M[current_row][i];
                else if (state == 2) w[i] <= v[i] * x[i]; // Behavioral '*' as explicitly mandated by manual
                else if (state == 3 && i < 8) w[i] <= rca_sum;
                else if (state == 4 && i < 4) w[i] <= rca_sum;
                else if (state == 5 && i < 2) w[i] <= rca_sum;
                else if (state == 6 && i == 0) w[i] <= rca_sum;
            end
        end
    endgenerate

    // Output Mapping
    always @(posedge clk) begin
        if (state == 8) begin
            done <= 1;
            y_val_out <= y[index];
            arm_cycles <= arm_cycles_reg;
        end else begin
            done <= 0;
            y_val_out <= 0;
            arm_cycles <= 0;
        end
    end

endmodule
