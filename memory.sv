module InstructionMemoryHandler (
    input  logic        clk,                // Clock signal
    input  logic        reset,            // Active-low reset
    input  logic [63:0] pc_I_offset,         // Current PC value (64 bits)
    input  logic [63:0] reg_b_contents,         // Reg B contents
    input  logic [63:0] alu_data,         // ALU result data
    input  logic [63:0] control_signals,       // Control Signals
    output logic [63:0] target_address_out,
    output logic [63:0] control_signals_out,    // Instruction bits fetched from cache (64 bits)
    output logic [63:0] loaded_data_out,
    output logic [63:0] alu_data_out,
    output logic        memory_done               // Ready signal indicating fetch completion
);
endmodule