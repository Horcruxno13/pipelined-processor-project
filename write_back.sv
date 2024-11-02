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

module write_back 
#()
(
    input logic clk,
    input logic reset,

    input [31:0] alu_result,
    input [31:0] loaded_data,
    input  control_signals_struct control_signals, //todo = change the type      // Control Signals



    input [4:0] dest_reg, //todo - replace from control signals
    output [31:0] write_data, //todo - write back is a neater name here
    output [4:0] write_reg,
    output write_enable

    alwyas
);
    always_comb begin
        if (reset) begin
            write_data = 0;
            write_reg = 0;
            write_enable = 0;
        end else begin
            // Jump, Store, Branch => Nothing happens
            if (opcode == 7'b0100011 ||          // S-Type Store
                opcode == 7'b1100011 ||          // B-Type Branch
                opcode == 7'b1101111 ||          // JAL J-Type Jump
                opcode == 7'b1100111 ||          // I-Type JALR
                opcode == 7'b0001111 ||          // FENCE (I-Type)
                opcode == 7'b1110011) begin      // System Instructions
                write_data = 0;
                write_reg = 0;
                write_enable = 0;
            end else begin
            // Write back is happening
                write_enable = 1;
                write_reg = dest_reg;
                // Write back from ALU
                if ((opcode == 7'b0110011) ||                // R-Type ALU instructions
                    (opcode == 7'b0111011) ||                // R-Type with multiplication
                    (opcode == 7'b0010011) ||                // I-Type ALU (immediate) instructions
                    (opcode == 7'b0011011) ||                // I-Type ALU (immediate, 32M)
                    (opcode == 7'b0010111)) begin            // AUIPC (U-Type)
                    write_data = alu_result;
                end else if ((opcode == 7'b0000011) ||       // I-Type Load
                             (opcode == 7'b0110111)) begin   // LUI (U-Type)
                    // Write back from data load
                    write_data = loaded_data;
                end
            end
        end
    end
endmodule