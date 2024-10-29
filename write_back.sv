module InstructionWriteBack (
    input  logic        clk,                          // Clock signal
    input  logic        reset,                        // Active-low reset
    input  logic [63:0] loaded_data,                  // Loaded data
    input  logic [63:0] alu_data,                     // ALU result data
    input  logic [63:0] control_signals,              // Control Signals
    output  logic [63:0] dest_reg_out,              // Control Signals
    output  logic [63:0] data_out,              // Control Signals
    output logic        write_back_done               // Ready signal indicating fetch completion
);
endmodule