`ifndef CONTROL_SIGNALS_STRUCT_SVH
`define CONTROL_SIGNALS_STRUCT_SVH

typedef struct packed {
    logic [63:0] imm;
    logic [6:0] opcode;
    logic [63:0] shamt;
    logic [7:0] instruction;
    logic memory_access;
    logic [4:0] dest_reg;
    logic jump_signal;              // Domino to halt everything prev
} control_signals_struct;

`endif