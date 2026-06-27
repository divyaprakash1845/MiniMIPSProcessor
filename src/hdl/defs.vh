// defs.vh
`define OP_REG 6'h0
`define OP_J 6'h2
`define OP_BEQ 6'h4
`define OP_ADDI 6'h8
`define OP_ANDI 6'hc
`define OP_ORI 6'hd
`define OP_XORI 6'he

`define FUNC_SLL 6'h0
`define FUNC_SRL 6'h2
`define FUNC_SRA 6'h3
`define FUNC_SLLV 6'h4
`define FUNC_SRLV 6'h6
`define FUNC_SRAV 6'h7
`define FUNC_SYSCALL 6'hc
`define FUNC_ADD 6'h20
`define FUNC_SUB 6'h22
`define FUNC_AND 6'h24
`define FUNC_OR 6'h25
`define FUNC_XOR 6'h26
`define FUNC_NOR 6'h27
`define READ_COMMAND 1'b0 // Memory read command
`define WRITE_COMMAND 1'b1 // Memory write command
`define SYS_exit 32'd1001 // Syscall number for exit
`define SYS_write 32'd1004 // Syscall number for print
