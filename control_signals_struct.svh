typedef struct packed {
    logic [63:0] imm;
    logic [6:0] opcode;
    logic [63:0] shamt;
    logic [7:0] instruction;
} control_signals_struct;