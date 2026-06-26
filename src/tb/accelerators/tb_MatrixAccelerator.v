`timescale 1ns / 1ps

module tb_MatrixAccelerator;

    reg clk;
    reg [3:0] row_id;
    reg [3:0] col_id;
    reg [31:0] value;
    reg vector_id;
    reg input_done;
    reg [3:0] index;
    reg start_arm;
    reg stop_arm;

    wire [31:0] y_val_out;
    wire done;
    wire [31:0] arm_cycles;

    MatrixAccelerator uut (
        .clk(clk),
        .row_id(row_id),
        .col_id(col_id),
        .value(value),
        .vector_id(vector_id),
        .input_done(input_done),
        .index(index),
        .start_arm(start_arm),
        .stop_arm(stop_arm),
        .y_val_out(y_val_out),
        .done(done),
        .arm_cycles(arm_cycles)
    );

    always #5 clk = ~clk;

    integer r, c;

    initial begin
        clk = 0; row_id = 0; col_id = 0; value = 0; vector_id = 0; 
        input_done = 0; index = 0; start_arm = 0; stop_arm = 0;

        // Load Matrix M with 1s
        for (r = 0; r < 16; r = r + 1) begin
            for (c = 0; c < 16; c = c + 1) begin
                @(posedge clk);
                vector_id = 0; row_id = r; col_id = c; value = 1;
            end
        end

        // Load Vector x with 2s
        for (r = 0; r < 16; r = r + 1) begin
            @(posedge clk);
            vector_id = 1; row_id = r; value = 2;
        end

        @(posedge clk);
        input_done = 1;
        
        wait(done);
        
        index = 0;
        @(posedge clk);
        $display("Hardware Output y[0]: %d", y_val_out); // Must print 32
        $finish;
    end
endmodule
