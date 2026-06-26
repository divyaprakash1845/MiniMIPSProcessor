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
            FullAdder fa(.a(A[i]), .b(B[i]), .cin(C[i]), .sum(Sum[i]), .cout(C[i+1]));
        end
    endgenerate
endmodule

// 3. MAIN GRAPH ACCELERATOR MODULE
module GraphAccelerator (
    input wire clk,
    input wire [4:0] edge_source,
    input wire [4:0] edge_dest,
    input wire adjacency_val,
    input wire [4:0] path_length,
    input wire input_done,
    input wire [4:0] start_vertex,
    input wire [4:0] end_vertex,
    input wire start_arm,
    input wire stop_arm,

    output reg is_there_path,
    output reg done,
    output reg [31:0] arm_cycles
);

    reg [31:0] A [0:31];
    reg [31:0] A_transposed [0:31];
    reg [31:0] B [0:31];
    reg [31:0] C [0:31];

    reg [3:0] state = 0;
    reg [4:0] k_counter = 0;
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
            1: begin
                if (path_length == 1) state <= 8;
                else begin
                    state <= 2;
                    k_counter <= 1;
                end
            end
            2: state <= 3;
            3: state <= 4;
            4: state <= 5;
            5: state <= 6;
            6: begin
                if (k_counter < path_length - 1) begin
                    k_counter <= k_counter + 1; // FSM control counter increment
                    state <= 2;
                end else begin
                    state <= 8;
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

    // Output Mapping
    always @(posedge clk) begin
        if (state == 8) begin
            done <= 1;
            is_there_path <= B[start_vertex][end_vertex];
            arm_cycles <= arm_cycles_reg;
        end else begin
            done <= 0;
            is_there_path <= 0;
            arm_cycles <= 0;
        end
    end

    // Parallel Boolean Computations
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : compute_blocks
            integer j;
            always @(posedge clk) begin
                if (state == 0) begin
                    if (edge_source == i) begin
                        if (adjacency_val) A[i] <= A[i] | (1 << edge_dest);
                        else A[i] <= A[i] & ~(1 << edge_dest);
                    end
                    if (edge_dest == i) begin
                        if (adjacency_val) A_transposed[i] <= A_transposed[i] | (1 << edge_source);
                        else A_transposed[i] <= A_transposed[i] & ~(1 << edge_source);
                    end
                end
                else if (state == 1) begin
                    B[i] <= A[i];
                end
                else if (state == 6) begin
                    B[i] <= C[i];
                end
                // Bitwise Boolean Inner Product (No adders needed!)
                else if (state == 2 && i >= 0 && i < 8) begin
                    for (j = 0; j < 32; j = j + 1) C[i][j] <= |(B[i] & A_transposed[j]);
                end
                else if (state == 3 && i >= 8 && i < 16) begin
                    for (j = 0; j < 32; j = j + 1) C[i][j] <= |(B[i] & A_transposed[j]);
                end
                else if (state == 4 && i >= 16 && i < 24) begin
                    for (j = 0; j < 32; j = j + 1) C[i][j] <= |(B[i] & A_transposed[j]);
                end
                else if (state == 5 && i >= 24 && i < 32) begin
                    for (j = 0; j < 32; j = j + 1) C[i][j] <= |(B[i] & A_transposed[j]);
                end
            end
        end
    endgenerate

endmodule
