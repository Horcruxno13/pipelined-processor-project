`include "control_signals_struct.svh"
/* module InstructionWriteBack (
    input  logic        clk,                          // Clock signal
    input  logic        reset,                        // Active-low reset
    input  logic [63:0] loaded_data,                  // Loaded data
    input  logic [63:0] alu_data,                     // ALU result data
    input  logic [63:0] control_signals,              // Control Signals
    output  logic [63:0] dest_reg_out,              // Control Signals
    output  logic [63:0] data_out,              // Control Signals
    output logic        write_back_done               // Ready signal indicating fetch completion
);
endmodule */

module InstructionWriteBack 
#()
(
    input logic clk,
    input logic reset,

    input [63:0] alu_result,
    input [63:0] loaded_data,
    input  control_signals_struct control_signals,
    input logic wb_module_enable,
    input wb_write_complete,
    output [63:0] register_write_data,
    output [4:0] register_write_addr,
    output register_write_enable,
    output write_back_done

);

    always_comb begin
        if (reset) begin
            register_write_data = 64'b0;
            register_write_addr = 5'b0;
            register_write_enable = 0;
            write_back_done = 0;
        end 
        if (wb_module_enable) begin
            if (!wb_write_complete) begin
                // Jump, Store, Branch => Nothing happens
                if (control_signals.opcode == 7'b0100011 ||          // S-Type Store
                    control_signals.opcode == 7'b1100011 ||          // B-Type Branch
                    // control_signals.opcode == 7'b1100111 ||          // I-Type JALR
                    control_signals.opcode == 7'b0001111 ||          // FENCE (I-Type)
                    control_signals.opcode == 7'b1110011) begin      // System Instructions
                    register_write_data = 64'b0;
                    register_write_addr = 5'b0;
                    register_write_enable = 1;
                end else begin
                // Write back is happening
                    register_write_addr = control_signals.dest_reg;
                    // Write back from ALU
                    if ((control_signals.opcode == 7'b0110011) ||                // R-Type ALU instructions
                        (control_signals.opcode == 7'b0111011) ||                // R-Type with multiplication
                        (control_signals.opcode == 7'b0010011) ||                // I-Type ALU (immediate) instructions
                        (control_signals.opcode == 7'b0011011) ||                // I-Type ALU (immediate, 32M)
                        (control_signals.opcode == 7'b0010111) ||                // AUIPC (U-Type)
                        (control_signals.opcode == 7'b0110111)) begin           // LUI (U-Type)) 
                        register_write_data = alu_result;
                        register_write_enable = 1;
                    end else if (control_signals.opcode == 7'b0000011) begin      // I-Type Load
                        // Write back from data load
                        register_write_data = loaded_data;
                        register_write_enable = 1;
                    end else if (
                        (control_signals.opcode ==  7'b1101111)  || //jal
                        (control_signals.opcode == 7'b1100111)      //jalr
                                                            ) begin
                        if (register_write_addr != 5'b0) begin
                            register_write_data = control_signals.pc + 4;
                            register_write_enable = 1;
                        end else begin
                            register_write_data = 64'b0;
                            register_write_enable = 0;
                        end
                    end    
                end
            end else begin
                register_write_enable = 0;
                write_back_done = 1;
            end
        end else begin
            write_back_done = 0;
        end
    end
endmodule