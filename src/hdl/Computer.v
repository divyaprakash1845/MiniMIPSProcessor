module Computer(
    input clk, input reset, input done_storing, input copied_io_regs, input [31:0] ins_addr, input [31:0] ins,
    input [31:0] input_value, input input_value_valid,
    output done, output io_stall, output [31:0] io_reg_index, output [31:0] out0, out1, out2, out3,
    output [31:0] total_cycles, output [31:0] proc_cycles, output waiting_for_input
);
    reg [31:0] imem [0:255];
    wire [31:0] pc;
    
    wire [7:0] data_addr;
    wire data_addr_valid;
    wire [1:0] data_mem_command;
    wire [31:0] store_value;

    wire [7:0] active_addr = data_addr_valid ? data_addr : pc[7:0];
    wire [31:0] mem_data_out = imem[active_addr];

    always @(posedge clk) begin
        if (!done_storing && !reset) begin
            imem[ins_addr[7:0]] <= ins;
        end
        else if (data_addr_valid && (data_mem_command == 1 || data_mem_command == 2)) begin
            imem[data_addr] <= store_value;
        end
    end

    Processor cpu(
        .clk(clk), .reset(reset || !done_storing), .copied_io_regs(copied_io_regs),
        .input_value(input_value), .input_value_valid(input_value_valid), .mem_data_in(mem_data_out),
        .pc(pc), .done(done), .io_stall(io_stall), .io_reg_index(io_reg_index),
        .out0(out0), .out1(out1), .out2(out2), .out3(out3), .total_cycles(total_cycles), 
        .proc_cycles(proc_cycles), .waiting_for_input(waiting_for_input),
        .data_addr(data_addr), .data_addr_valid(data_addr_valid), .data_mem_command(data_mem_command), .store_value(store_value)
    );
endmodule
