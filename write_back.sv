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

    output [63:0] write_data, //todo - write back is a neater name here
    output [4:0] write_reg,
    output write_enable
);
    always_comb begin
        if (reset) begin
            write_data = 64'b0;
            write_reg = 5'b0;
            write_enable = 0;
        end 
        
        if (wb_module_enable) begin
            // Jump, Store, Branch => Nothing happens
            if (control_signals.opcode == 7'b0100011 ||          // S-Type Store
                control_signals.opcode == 7'b1100011 ||          // B-Type Branch
                // control_signals.opcode == 7'b1100111 ||          // I-Type JALR
                control_signals.opcode == 7'b0001111 ||          // FENCE (I-Type)
                control_signals.opcode == 7'b1110011) begin      // System Instructions
                write_data = 64'b0;
                write_reg = 5'b0;
                write_enable = 0;
            end else begin
            // Write back is happening
                
                write_reg = control_signals.dest_reg;
                // Write back from ALU
                if ((control_signals.opcode == 7'b0110011) ||                // R-Type ALU instructions
                    (control_signals.opcode == 7'b0111011) ||                // R-Type with multiplication
                    (control_signals.opcode == 7'b0010011) ||                // I-Type ALU (immediate) instructions
                    (control_signals.opcode == 7'b0011011) ||                // I-Type ALU (immediate, 32M)
                    (control_signals.opcode == 7'b0010111)) begin            // AUIPC (U-Type)
                    write_data = alu_result;
                    write_enable = 1;
                end else if ((control_signals.opcode == 7'b0000011) ||       // I-Type Load
                             (control_signals.opcode == 7'b0110111)) begin   // LUI (U-Type)
                    // Write back from data load
                    write_data = loaded_data;
                    write_enable = 1;
                end else if (
                    (control_signals.opcode ==  7'b1101111)  || //jal
                    (control_signals.opcode == 7'b1100111)      //jalr
                                                        ) begin
                    if (write_reg != 5'b0) begin
                        write_data = control_signals.pc;
                        write_enable = 1;
                    end else begin
                        write_data = 64'b0;
                        write_enable = 0;
                    end
                end    
            end
        end else begin
            write_data = 64'b0;
            write_reg = 5'b0;
            write_enable = 0;
        end
    end
endmodule