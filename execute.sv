
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
    output logic        jump_enable,                // Domino to halt everything prev
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
            if (
                control_signals.opcode == 7'b1100011 ||          // B-Type Branch
                control_signals.opcode == 7'b1101111 ||          // JAL J-Type Jump
                control_signals.opcode == 7'b1100111)            // I-Type JALR
            begin
                // do pc manipulation
                pc_I_offset_out = pc_current + control_signals.imm; // TODO: @debo - make 3 separate cases
                jump_enable = 1;
                //@debo - see how we can use the ALU output in the cases where it holds the target value
                //@debo, @angad - understand the cases of PC - absolute, relative or +4 simple
            end else begin
                // do alu
                // alu_enable = 1;
                pc_I_offset_out = 64'b0;
                jump_enable = 0;
            end
            execute_done = 1;
        end else begin
            // reg_b_data_out = 64'b0;
            alu_data_out = 64'b0;
            pc_I_offset_out = 64'b0;
            execute_done = 0;
        end
    end

endmodule