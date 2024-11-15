
`include "control_signals_struct.svh"

module InstructionExecutor (
    input  logic        clk,                        // Clock signal
    input  logic        reset,                      // Active-low reset
    input  logic [63:0] pc_current,                 // Current PC value (64 bits)
    input  logic [63:0] reg_a_contents,
    input  logic [63:0] reg_b_contents,
    input  control_signals_struct control_signals, 
    input logic execute_enable,

    output logic [63:0] alu_data_out,               // ALU data output
    output logic [63:0] pc_I_offset_out,            // PC value to jump to
    output  control_signals_struct control_signals_out, 
    output logic        execute_done                // Ready signal indicating execute completion
);
    alu ALU_unit(
        .instruction(control_signals.instruction),
        .rs1(reg_a_contents),
        .rs2(reg_b_contents),
        .imm(control_signals.imm),
        .shamt(control_signals.shamt),
        // .alu_enable(alu_enable),
        .result(alu_data_out)
    );


    always_comb begin
        if (reset) begin
            // reg_b_data_out = 64'b0;
            alu_data_out = 64'b0;
            pc_I_offset_out = 64'b0;
            execute_done = 0;
        end else if (execute_enable) begin
            if(control_signals.opcode == 7'b1100011) begin                      // B-Type Branch (Conditional Jump)
                if (alu_data_out == 1) begin  // branch conditions met 
                    pc_I_offset_out = pc_current + control_signals.imm;
                    control_signals_out.jump_signal = 1;
                end else begin          // not met
                    pc_I_offset_out = 64'b0;
                    control_signals_out.jump_signal = 0;
                end
            end else if(control_signals.opcode == 7'b1101111) begin            // JAL J-Type Jump (Unconditional Jump)
                pc_I_offset_out = pc_current + control_signals.imm;
                control_signals_out.jump_signal = 1;
            end else if (control_signals.opcode == 7'b1100111) begin           // I-Type JALR (Unconditional Jump with rs1)
                pc_I_offset_out = pc_current + control_signals.imm + reg_a_contents;
                control_signals_out.jump_signal = 1;
            end else begin
                // no branches, just alu which always runs in comb
                pc_I_offset_out = 64'b0;
                control_signals_out.jump_signal = 0;
            end
            control_signals_out.imm = control_signals.imm;
            control_signals_out.shamt = control_signals.shamt;
            control_signals_out.opcode = control_signals.opcode;
            control_signals_out.instruction = control_signals.instruction;
            control_signals_out.memory_access = control_signals.memory_access;
            control_signals_out.dest_reg = control_signals.dest_reg;
            execute_done = 1;
        end else begin
            // reg_b_data_out = 64'b0;
            alu_data_out = 64'b0;
            pc_I_offset_out = 64'b0;
            execute_done = 0;
        end
    end

endmodule