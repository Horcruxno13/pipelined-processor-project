typedef struct packed {
    logic [63:0] pc;            // Program Counter
    logic [31:0] instruction;   // Fetched instruction
} control_signals_struct;