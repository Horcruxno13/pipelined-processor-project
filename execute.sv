
`include "control_signals_struct.svh"

module InstructionExecutor (
    input  logic        clk,                        // Clock signal
    input  logic        reset,                      // Active-low reset
    input  logic [63:0] pc_current,                 // Current PC value (64 bits)
    input  logic [63:0] reg_a_contents,
    input  logic [63:0] reg_b_contents,
    input  control_signals_struct control_signals, 
    input logic execute_enable,
    input logic [63:0] register [31:0],

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
        .pc_alu(pc_current),
        .result(alu_data_out)
    );

    logic localJumpSignal = 0;
    logic signed [63:0] signed_imm;
    logic [11:0] imm_12bit;
    logic [19:0] imm_20bit;

    logic ecall_done;

    always_ff @(posedge clk) begin 
        if (execute_enable && ecall_done == 0) begin
            if (control_signals.instruction == 8'd57) begin
                do_ecall(register[17], register[10], register[11], register[12], register[13], register[14], register[15], register[16], alu_data_out);
                ecall_done <= 1;
            end else begin
                ecall_done <= 0;
            end
        end
    end



    always_comb begin
        if (reset) begin
            // reg_b_data_out = 64'b0;
            alu_data_out = 64'b0;
            pc_I_offset_out = 64'b0;
            execute_done = 0;
        end else if (execute_enable) begin
            if(control_signals.opcode == 7'b1100011) begin                      // B-Type Branch (Conditional Jump)
                if (alu_data_out == 1) begin  // branch conditions not met 
                    // Extract the lower 12 bits of the immediate
                    imm_12bit = control_signals.imm[11:0];

                    // Sign-extend the 12-bit immediate to 64 bits
                    
                    signed_imm = {{52{imm_12bit[11]}}, imm_12bit};  // imm_12bit[11] is the sign bit

                    // Perform the addi operation to compute the effective address
                    pc_I_offset_out = control_signals.pc + $signed(signed_imm);
                    localJumpSignal = 1;
                end else begin          // not met
                    pc_I_offset_out = 64'b0;
                    localJumpSignal = 0;
                end
            end else if(control_signals.opcode == 7'b1101111) begin            // JAL J-Type Jump (Unconditional Jump)

                imm_20bit = control_signals.imm[19:0];
                signed_imm = {{44{imm_20bit[19]}}, imm_20bit}; 
                pc_I_offset_out = pc_current + $signed(signed_imm);
                localJumpSignal = 1;

            end else if (control_signals.opcode == 7'b1100111) begin           // I-Type JALR (Unconditional Jump with rs1)

                imm_20bit = control_signals.imm[19:0];
                signed_imm = {{44{imm_20bit[19]}}, imm_20bit}; 
                pc_I_offset_out = reg_a_contents + $signed(signed_imm);
                localJumpSignal = 1;
            
            end else begin
                // no branches, just alu which always runs in comb
                pc_I_offset_out = 64'b0;
                localJumpSignal = 0;
            end
            control_signals_out = control_signals;
            control_signals_out.jump_signal = localJumpSignal;

            if (control_signals.instruction == 8'd57) begin         //ECALL CASE
                if (ecall_done) begin
                    execute_done = 1;
                end else begin
                    execute_done = 0;
                end 
            end else begin
                execute_done = 1;
            end
        end else begin
            // reg_b_data_out = 64'b0;
            // alu_data_out = 64'b0;
            pc_I_offset_out = 64'b0;
            execute_done = 0;
        end
    end

endmodule