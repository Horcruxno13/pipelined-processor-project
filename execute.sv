module InstructionExecutor (
    input  logic        clk,                // Clock signal
    input  logic        reset,            // Active-low reset
    input  logic [63:0] pc_current,         // Current PC value (64 bits)
    input  logic [63:0] reg_a_contents,         // Current PC value (64 bits)
    input  logic [63:0] reg_b_contents,         // Current PC value (64 bits)
    input  logic [63:0] control_signals,       // Signal to start or remain idle
    output logic [63:0] control_signals_out,    // Instruction bits fetched from cache (64 bits)
    output logic [63:0] reg_b_data_out,        // Address used for fetching (64 bits)
    output logic [63:0] alu_data_out,        // Address used for fetching (64 bits)
    output logic [63:0] pc_I_offset_out,        // Address used for fetching (64 bits)
    output logic        execute_done               // Ready signal indicating fetch completion
);