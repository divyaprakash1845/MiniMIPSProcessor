module Processor(
    input clk, input reset, input copied_io_regs,
    input [31:0] input_value, input input_value_valid,
    input [31:0] mem_data_in, 
    
    output reg [31:0] pc, output reg done, output reg io_stall, output reg [31:0] io_reg_index,
    output reg [31:0] out0, out1, out2, out3, output reg [31:0] total_cycles, output reg [31:0] proc_cycles,
    output reg waiting_for_input,
    
    output [7:0] data_addr, output data_addr_valid, output [1:0] data_mem_command, output [31:0] store_value
);
    reg [31:0] instr; 
    wire [5:0] opcode = instr[31:26];
    wire [4:0] rs = instr[25:21];
    wire [4:0] rt = instr[20:16];
    wire [4:0] rd = instr[15:11];
    wire [5:0] func = instr[5:0];
    wire [15:0] imm = instr[15:0];
    wire [31:0] imm_ext = {{16{imm[15]}}, imm}; 
    wire [31:0] imm_zero_ext = {16'b0, imm};
    wire [25:0] jump_target = instr[25:0];

    reg [31:0] regs [0:31];
    
    // STRICT $0 HARDWIRE FIX
    wire [31:0] rs_val = (rs == 5'd0) ? 32'b0 : regs[rs];
    wire [31:0] rt_val = (rt == 5'd0) ? 32'b0 : regs[rt];

    // Structural PC Adders
    wire [31:0] pc_plus_one, pc_plus_offset;
    RippleCarryAdder32 pc_adder(.A(pc), .B(32'd1), .Cin(1'b0), .Sum(pc_plus_one), .Cout());
    RippleCarryAdder32 branch_adder(.A(pc), .B(imm_ext), .Cin(1'b0), .Sum(pc_plus_offset), .Cout());

    wire is_mem_op = (opcode == 6'h23 || opcode == 6'h20 || opcode == 6'h24 || opcode == 6'h21 || opcode == 6'h25 || opcode == 6'h2b || opcode == 6'h28 || opcode == 6'h29);
    wire [31:0] alu_add_out;
    RippleCarryAdder32 alu_adder(.A(rs_val), .B((opcode == 6'h8 || opcode == 6'ha || opcode == 6'hb || is_mem_op) ? imm_ext : rt_val), .Cin(1'b0), .Sum(alu_add_out), .Cout());

    wire [31:0] sub_b_in = (opcode == 6'ha || opcode == 6'hb) ? imm_ext : rt_val;
    wire [31:0] alu_sub_out; wire sub_cout;
    RippleCarryAdder32 alu_subber(.A(rs_val), .B(~sub_b_in), .Cin(1'b1), .Sum(alu_sub_out), .Cout(sub_cout));

    wire z_flag = (alu_sub_out == 32'd0); wire rs_sign = rs_val[31];
    wire slt_res = (rs_val[31] == sub_b_in[31]) ? alu_sub_out[31] : rs_val[31];
    wire sltu_res = ~sub_cout;
    wire branch_cond = 
        ((opcode == 6'h4) & z_flag) | ((opcode == 6'h5) & ~z_flag) |
        ((opcode == 6'h1 & rt == 5'd0) & rs_sign) | ((opcode == 6'h1 & rt == 5'd1) & ~rs_sign) |
        ((opcode == 6'h6) & (rs_sign | z_flag)) | ((opcode == 6'h7) & (~rs_sign & ~z_flag));

    // Big-Endian Subword Extraction
    wire [1:0] byte_sel = alu_add_out[1:0];
    wire [7:0] ext_byte = (byte_sel == 2'b00) ? mem_data_in[31:24] : (byte_sel == 2'b01) ? mem_data_in[23:16] : (byte_sel == 2'b10) ? mem_data_in[15:8] : mem_data_in[7:0];
    wire [15:0] ext_half = (byte_sel[1] == 1'b0) ? mem_data_in[31:16] : mem_data_in[15:0];
    
    wire [31:0] sb_val = (byte_sel == 2'b00) ? {rt_val[7:0], mem_data_in[23:0]} : (byte_sel == 2'b01) ? {mem_data_in[31:24], rt_val[7:0], mem_data_in[15:0]} : (byte_sel == 2'b10) ? {mem_data_in[31:16], rt_val[7:0], mem_data_in[7:0]} : {mem_data_in[31:8], rt_val[7:0]};
    wire [31:0] sh_val = (byte_sel[1] == 1'b0) ? {rt_val[15:0], mem_data_in[15:0]} : {mem_data_in[31:16], rt_val[15:0]};

    localparam FETCH = 3'd0, EXEC = 3'd1, STALL1 = 3'd2, STALL2 = 3'd3, HALT = 3'd4, STALL_INPUT_1 = 3'd5, STALL_INPUT_2 = 3'd6;
    reg [2:0] state;

    assign data_addr_valid = (state == EXEC) && is_mem_op;
    assign data_addr = alu_add_out[9:2]; 
    assign data_mem_command = (state == EXEC && opcode == 6'h2b) ? 2'd1 : (state == EXEC && (opcode == 6'h28 || opcode == 6'h29)) ? 2'd2 : 2'd0;
    assign store_value = (opcode == 6'h2b) ? rt_val : (opcode == 6'h28) ? sb_val : sh_val;

    always @(posedge clk) begin
        if (reset) begin
            pc <= 32'd0; state <= FETCH; done <= 0; io_stall <= 0; io_reg_index <= 0;
            total_cycles <= 0; proc_cycles <= 0; out0 <= 0; out1 <= 0; out2 <= 0; out3 <= 0; waiting_for_input <= 0;
            regs[0] <= 32'b0; // Explicitly reset $0
        end else begin
            total_cycles <= total_cycles + 1;
            case (state)
                FETCH: begin
                    if (!done) begin 
                        instr <= mem_data_in; 
                        proc_cycles <= proc_cycles + 1; state <= EXEC; 
                    end
                end
                EXEC: begin
                    proc_cycles <= proc_cycles + 1;
                    
                    if (opcode == 6'b000000 && func == 6'hc) begin 
                        if (rs_val == 32'd1003) begin waiting_for_input <= 1; state <= STALL_INPUT_1; end
                        else if (rs_val == 32'd1004) begin 
                            if (io_reg_index == 4) begin io_stall <= 1; state <= STALL1; end 
                            else begin
                                if (io_reg_index == 0) out0 <= regs[rd];
                                else if (io_reg_index == 1) out1 <= regs[rd];
                                else if (io_reg_index == 2) out2 <= regs[rd];
                                else if (io_reg_index == 3) out3 <= regs[rd];
                                io_reg_index <= io_reg_index + 1; pc <= pc_plus_one; state <= FETCH;
                            end
                        end
                        else if (rs_val == 32'd1001) begin done <= 1; state <= HALT; end
                    end
                    else if (is_mem_op) begin 
                        if (opcode == 6'h23 && rt != 0) regs[rt] <= mem_data_in; // lw
                        else if (opcode == 6'h20 && rt != 0) regs[rt] <= {{24{ext_byte[7]}}, ext_byte}; // lb
                        else if (opcode == 6'h24 && rt != 0) regs[rt] <= {24'b0, ext_byte}; // lbu
                        else if (opcode == 6'h21 && rt != 0) regs[rt] <= {{16{ext_half[15]}}, ext_half}; // lh
                        else if (opcode == 6'h25 && rt != 0) regs[rt] <= {16'b0, ext_half}; // lhu
                        pc <= pc_plus_one; state <= FETCH;
                    end
                    else if (opcode == 6'h0f && rt != 0) begin regs[rt] <= {imm, 16'b0}; pc <= pc_plus_one; state <= FETCH; end // lui
                    else if (opcode == 6'h0d && rt != 0) begin regs[rt] <= rs_val | imm_zero_ext; pc <= pc_plus_one; state <= FETCH; end // ori
                    else if (opcode == 6'h4 || opcode == 6'h5 || opcode == 6'h1 || opcode == 6'h6 || opcode == 6'h7) begin pc <= branch_cond ? pc_plus_offset : pc_plus_one; state <= FETCH; end
                    else if (opcode == 6'h2 || opcode == 6'h3) begin if (opcode == 6'h3 && rd != 0) regs[31] <= pc_plus_one; pc <= {6'b0, jump_target}; state <= FETCH; end
                    else if (opcode == 6'h0 && (func == 6'h8 || func == 6'h9)) begin if (func == 6'h9 && rd != 0) regs[31] <= pc_plus_one; pc <= rs_val; state <= FETCH; end
                    else if (opcode == 6'ha || opcode == 6'hb || (opcode == 6'h0 && (func == 6'h2a || func == 6'h2b))) begin if ((opcode == 6'h0) ? rd != 0 : rt != 0) regs[(opcode == 6'h0) ? rd : rt] <= {31'b0, (opcode == 6'ha || (opcode == 6'h0 && func == 6'h2a)) ? slt_res : sltu_res}; pc <= pc_plus_one; state <= FETCH; end
                    else begin if (opcode == 6'h8 && rt != 0) regs[rt] <= alu_add_out; else if (opcode == 6'h0 && rd != 0) begin if (func == 6'h24) regs[rd] <= rs_val & rt_val; else if (func == 6'h25) regs[rd] <= rs_val | rt_val; else if (func == 6'h20) regs[rd] <= alu_add_out; else if (func == 6'h22) regs[rd] <= alu_sub_out; end pc <= pc_plus_one; state <= FETCH; end
                end
                STALL1: begin if (copied_io_regs) begin io_stall <= 0; io_reg_index <= 0; state <= STALL2; end end
                STALL2: begin if (!copied_io_regs) state <= EXEC; end
                STALL_INPUT_1: begin if (input_value_valid) begin waiting_for_input <= 0; if(rd != 0) regs[rd] <= input_value; state <= STALL_INPUT_2; end end
                STALL_INPUT_2: begin if (!input_value_valid) begin pc <= pc_plus_one; state <= FETCH; end end
                HALT: begin end
            endcase
        end
    end
endmodule
