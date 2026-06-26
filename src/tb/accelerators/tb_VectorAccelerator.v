`timescale 1ns / 1ps

module tb_VectorAccelerator;

    reg clk;
    reg [8:0] index;
    reg [31:0] value;
    reg vector_id;
    reg input_done;
    reg start_arm;
    reg stop_arm;
    
    wire [31:0] reduction_result;
    wire done;
    wire [31:0] arm_cycles;

    VectorAccelerator uut (
        .clk(clk),
        .index(index),
        .value(value),
        .vector_id(vector_id),
        .input_done(input_done),
        .start_arm(start_arm),
        .stop_arm(stop_arm),
        .reduction_result(reduction_result),
        .done(done),
        .arm_cycles(arm_cycles)
    );

    always #5 clk = ~clk;

    integer i;

    initial begin
        clk = 0; index = 0; value = 0; vector_id = 0; 
        input_done = 0; start_arm = 0; stop_arm = 0;

        // Load v0
        for (i = 0; i < 512; i = i + 1) begin
            @(posedge clk);
            vector_id = 0; index = i; value = 1;
        end

        // Load v1
        for (i = 0; i < 512; i = i + 1) begin
            @(posedge clk);
            vector_id = 1; index = i; value = 2;
        end

        @(posedge clk);
        input_done = 1;
        
        wait(done);
        $display("Hardware Output: %d", reduction_result); // Must print 1536
        $finish;
    end
endmodule
