# AXI IP Packaging Guide

When packaging the `Computer.v` module into an AXI4 Peripheral in Vivado, you must make the following modifications to the generated `_S00_AXI.v` file to expose the CPU signals to the ARM processor.

## 1. Update the Address Decoder
Replace the default read address `case` statement (around line 489) with this 32-register 5-bit decoder:

```verilog
    always @(*)
    begin
        case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
            5'h00 : reg_data_out <= slv_reg0;
            5'h01 : reg_data_out <= slv_reg1;
            5'h02 : reg_data_out <= slv_reg2;
            5'h03 : reg_data_out <= slv_reg3;
            5'h04 : reg_data_out <= slv_reg4;
            5'h05 : reg_data_out <= slv_reg5;
            5'h06 : reg_data_out <= slv_reg6;
            5'h07 : reg_data_out <= done;
            5'h08 : reg_data_out <= out0;
            5'h09 : reg_data_out <= out1;
            5'h0A : reg_data_out <= out2;
            5'h0B : reg_data_out <= out3;
            5'h0C : reg_data_out <= total_cycles;
            5'h0D : reg_data_out <= proc_cycles;
            5'h0E : reg_data_out <= io_stall;
            5'h0F : reg_data_out <= io_reg_index;
            5'h10 : reg_data_out <= waiting_for_input;
            default : reg_data_out <= 0;
        endcase
    end
```

## 2. Instantiate the Hardware
Scroll to the very bottom (under `// Add user logic here`) and paste the instantiation of `Computer.v`:

```verilog
    wire done, io_stall, waiting_for_input;
    wire [31:0] io_reg_index, out0, out1, out2, out3, total_cycles, proc_cycles;

    Computer my_cpu (
        .clk(S_AXI_ACLK),
        .reset(slv_reg0[0]),
        .ins_addr(slv_reg1),
        .ins(slv_reg2),
        .done_storing(slv_reg3[0]),
        .copied_io_regs(slv_reg4[0]),
        .input_value(slv_reg5),
        .input_value_valid(slv_reg6[0]),
        
        .done(done), .io_stall(io_stall), .io_reg_index(io_reg_index),
        .out0(out0), .out1(out1), .out2(out2), .out3(out3),
        .total_cycles(total_cycles), .proc_cycles(proc_cycles),
        .waiting_for_input(waiting_for_input)
    );
```
