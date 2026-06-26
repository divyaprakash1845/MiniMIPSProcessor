`timescale 1ns / 1ps

module tb_GraphAccelerator;

    reg clk;
    reg [4:0] edge_source;
    reg [4:0] edge_dest;
    reg adjacency_val;
    reg [4:0] path_length;
    reg input_done;
    reg [4:0] start_vertex;
    reg [4:0] end_vertex;
    reg start_arm;
    reg stop_arm;

    wire is_there_path;
    wire done;
    wire [31:0] arm_cycles;

    GraphAccelerator uut (
        .clk(clk),
        .edge_source(edge_source),
        .edge_dest(edge_dest),
        .adjacency_val(adjacency_val),
        .path_length(path_length),
        .input_done(input_done),
        .start_vertex(start_vertex),
        .end_vertex(end_vertex),
        .start_arm(start_arm),
        .stop_arm(stop_arm),
        .is_there_path(is_there_path),
        .done(done),
        .arm_cycles(arm_cycles)
    );

    always #5 clk = ~clk;

    integer r, c;

    initial begin
        clk = 0; edge_source = 0; edge_dest = 0; adjacency_val = 0;
        path_length = 0; input_done = 0; start_vertex = 0; end_vertex = 0;
        start_arm = 0; stop_arm = 0;

        // Load Ring Graph Edges
        for (r = 0; r < 32; r = r + 1) begin
            for (c = 0; c < 32; c = c + 1) begin
                @(posedge clk);
                edge_source = r;
                edge_dest = c;
                if ((c == (r + 1) % 32) || (c == (r + 31) % 32)) adjacency_val = 1;
                else adjacency_val = 0;
            end
        end

        @(posedge clk);
        path_length = 31; 
        input_done = 1;
        
        wait(done);
        
        @(posedge clk);
        start_vertex = 0; end_vertex = 15;
        @(posedge clk);
        $display("Is there a path of length 31 from 0 to 15? %b", is_there_path); // Must print 1
        $finish;
    end
endmodule
