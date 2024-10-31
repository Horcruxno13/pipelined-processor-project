// decoder.v
module InstructionDecoder (
    input logic clk,
    // input logic reset, 

    input logic [31:0] instruction,                 // Single 32-bit instruction input
    input logic decode_enable,
    
    output logic [6:0] opcode,                      // opcode
    output logic [4:0] rd,                          // Destination register
    output logic [4:0] rs1,                         // Source register 1
    output logic [4:0] rs2,                         // Source register 2
    output signed [63:0] imm,                       // Immediate value
    output logic [63:0] shamt,                      // Shift amount
    output logic [7:0] instruction_type,            // Instruction type
    output control_signals_struct control_signals_out,
    output logic decode_complete
);

    logic [2:0] funct3;
    logic [6:0] funct7;

    // Decoding logic purely combinational
    always_comb begin
        // Extract fields from the instruction
        if (decode_enable) begin
            if (instruction != 64'b0) begin
                opcode = instruction[6:0];
                rd = instruction[11:7];
                rs1 = instruction[19:15];
                rs2 = instruction[24:20];
                funct3 = instruction[14:12];
                funct7 = instruction[31:25];
                imm = 64'b0; // Default to zero
                shamt = 64'b0; // Default to zero
                instruction_type = 8'b11111111; // Default to unknown

                // Decoding based on opcode
                case (opcode)
                        // R-type Instructions
                        7'b0110011: begin
                            rd = instruction[11:7];
                            funct3 = instruction[14:12];
                            rs1 = instruction[19:15];
                            rs2 = instruction[24:20];
                            funct7 = instruction[31:25];
                            // $display("R-type instruction detected");
                            // $display("RD: %h", rd);
                            // $display("Funct3: %h", funct3);
                            // $display("RS1: %h", rs1);
                            // $display("RS2: %h", rs2);
                            // $display("Funct7: %h", funct7);
                            // $display("IMM: %d", imm);


                            case(funct3)
                                3'b000: begin
                                    if (funct7 == 7'b0000000) instruction_type = 8'd0; // ADD
                                    else if (funct7 == 7'b0100000) instruction_type = 8'd1; // SUB
                                    else if (funct7 == 7'b0000001) instruction_type = 8'd10; // MUL
                                end
                                3'b001: begin
                                    if (funct7 == 7'b0000001) instruction_type = 8'd11; // MULH
                                    // else if (funct7 == 7'b0000010) instruction_type = 8'd12; // MULHSU
                                    // else if (funct7 == 7'b0000011) instruction_type = 8'd13; // MULHU
                                end
                                3'b100: begin
                                    if (funct7 == 7'b0000001) instruction_type = 8'd14; // DIV
                                end
                                3'b101: begin
                                    if (funct7 == 7'b0000001) instruction_type = 8'd15; // DIVU
                                end
                                3'b110: begin
                                    if (funct7 == 7'b0000001) instruction_type = 8'd16; // REM
                                end
                                3'b111: begin
                                    if (funct7 == 7'b0000001) instruction_type = 8'd17; // REMU
                                end
                                3'b010: begin
                                    if (funct7 == 7'b0000000) instruction_type = 8'd8; // SLT
                                    else if (funct7 == 7'b0000001) instruction_type = 8'd12; // MULHSU
                                end
                                3'b011: begin
                                    if (funct7 == 7'b0000000) instruction_type = 8'd9; // SLTU
                                    else if (funct7 == 7'b0000001) instruction_type = 8'd13; // MULHU
                                end
                                3'b100: instruction_type = 8'd2; // XOR
                                3'b110: instruction_type = 8'd3; // OR
                                3'b111: instruction_type = 8'd4; // AND
                                3'b001: instruction_type = 8'd5; // SLL
                                3'b101: begin
                                    if (funct7 == 7'b0000000) instruction_type = 8'd6; // SRL
                                    else if (funct7 == 7'b0100000) instruction_type = 8'd7; // SRA
                                end
                                default: instruction_type = 8'b11111111; // New value for unknown R-type
                            endcase
                        end

                        // I-type Instructions
                        7'b0010011: begin
                            rd = instruction[11:7];
                            funct3 = instruction[14:12];
                            rs1 = instruction[19:15];
                            imm = {52'b0, instruction[31:20]};
                            // $display("I-type instruction detected");
                            // $display("RD: %d", rd);
                            // $display("Funct3: %b", funct3);
                            // $display("RS1: %d", rs1);
                            // $display("RS2: %d", rs2);
                            // $display("Funct7: %b", funct7);
                            // $display("IMM: %d", imm);

                            case(funct3)
                                3'b000: instruction_type = 8'd18; // ADDI
                                3'b100: instruction_type = 8'd19; // XORI
                                3'b110: instruction_type = 8'd20; // ORI
                                3'b111: instruction_type = 8'd21; // ANDI
                                3'b001: begin 
                                                    instruction_type = 8'd22; // SLLI
                                                    shamt[5:0] = instruction[25:20];
                                                end
                                3'b101: begin
                                                        shamt[5:0] = instruction[25:20];
                                    if (instruction[31:26] == 6'b000000) instruction_type = 8'd23; // SRLI
                                    else if (instruction[31:26] == 6'b010000) instruction_type = 8'd24; // SRAI
                                end
                                3'b010: instruction_type = 8'd25; // SLTI
                                3'b011: instruction_type = 8'd26; // SLTIU
                                default: instruction_type = 8'b11111111; // New value for unknown I-type
                            endcase
                        end

                        // S-type Instructions
                        7'b0100011: begin
                            funct3 = instruction[14:12];
                            rs1 = instruction[19:15];
                            rs2 = instruction[24:20];
                            imm = {52'b0, instruction[31:25], instruction[11:7]};
                            // $display("S-type instruction detected");
                            // $display("RD: %h", rd);
                            // $display("Funct3: %h", funct3);
                            // $display("RS1: %h", rs1);
                            // $display("RS2: %h", rs2);
                            // $display("Funct7: %h", funct7);
                            // $display("IMM: %d", imm);

                            case(funct3)
                                3'b000: instruction_type = 8'd43;   // SB (new value)
                                3'b001: instruction_type = 8'd44;   // SH (new value)
                                3'b010: instruction_type = 8'd45;   // SW (new value)
                                3'b011: instruction_type = 8'd46;   // SD (new value)
                                default: instruction_type = 8'b11111111;  // New value for unknown Store
                            endcase
                        end

                        // B-type Instructions
                        7'b1100011: begin
                            funct3 = instruction[14:12];
                            rs1 = instruction[19:15];
                            rs2 = instruction[24:20];
                            imm = {52'b0, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                            // $display("B-type instruction detected");
                            // $display("RD: %h", rd);
                            // $display("Funct3: %h", funct3);
                            // $display("RS1: %h", rs1);
                            // $display("RS2: %h", rs2);
                            // $display("Funct7: %h", funct7);
                            // $display("IMM: %d", imm);

                            case(funct3)
                                3'b000: instruction_type = 8'd47;   // BEQ (new value)
                                3'b001: instruction_type = 8'd48;   // BNE (new value)
                                3'b100: instruction_type = 8'd49;   // BLT (new value)
                                3'b101: instruction_type = 8'd50;   // BGE (new value)
                                3'b110: instruction_type = 8'd51;   // BLTU (new value)
                                3'b111: instruction_type = 8'd52;   // BGEU (new value)
                                default: instruction_type = 8'b11111111;  // New value for unknown Branch
                            endcase
                        end

                        // JAL (J-type)
                        7'b1101111: begin
                            rd = instruction[11:7];
                            imm = {44'b0, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
                            instruction_type = 8'd53; // JAL (new value)
                        end

                        // JALR (I-type)
                        7'b1100111: begin
                            rd = instruction[11:7];
                            funct3 = instruction[14:12];
                            rs1 = instruction[19:15];
                            imm = {52'b0, instruction[31:20]};
                            instruction_type = 8'd54; // JALR (new value)
                        end

                        // LUI (U-type)
                        7'b0110111: begin
                            rd = instruction[11:7];
                            imm = {44'b0,instruction[31:12]};
                            instruction_type = 8'd55; // LUI (new value)
                        end

                        // AUIPC (U-type)
                        7'b0010111: begin
                            rd = instruction[11:7];
                            imm = {44'b0,instruction[31:12]};
                            instruction_type = 8'd56; // AUIPC (new value)
                        end

                        // System Instructions
                        7'b1110011: begin
                            funct3 = instruction[14:12];
                            case(funct3)
                                3'b000: begin
                                    if (instruction[31:20] == 12'h000)
                                        instruction_type = 8'd57; // ECALL (new value)
                                    else if (instruction[31:20] == 12'h001)
                                        instruction_type = 8'd58; // EBREAK (new value)
                                    else
                                        instruction_type = 8'b11111111; // New value for unknown System
                                end
                                default: instruction_type = 8'b11111111; // New value for unknown System
                            endcase
                            imm = {52'b0,instruction[31:20]}; // Immediate for I-type system
                        end

                        // Load Instructions
                        7'b0000011: begin
                            funct3 = instruction[14:12];
                            case(funct3)
                                3'b000: instruction_type = 8'd59; // LB (new value)
                                3'b001: instruction_type = 8'd60; // LH (new value)
                                3'b010: instruction_type = 8'd61; // LW (new value)
                                3'b100: instruction_type = 8'd62; // LBU (new value)
                                3'b101: instruction_type = 8'd63; // LHU (new value)
                                3'b110: instruction_type = 8'd64; // LWU (new value)
                                3'b011: instruction_type = 8'd65; // LD (new value)
                            endcase
                        end

                        // W-type Instructions
                        7'b0111011: begin
                            rd = instruction[11:7];
                            funct3 = instruction[14:12];
                            rs1 = instruction[19:15];
                            rs2 = instruction[24:20];
                            funct7 = instruction[31:25];
                            // $display("W-type instruction detected");
                            // $display("RD: %d", rd);
                            // $display("Funct3: %b", funct3);
                            // $display("RS1: %d", rs1);
                            // $display("RS2: %d", rs2);
                            // $display("Funct7: %b", funct7);
                            // $display("IMM: %d", imm);
                            case(funct3)
                                3'b000: begin
                                    if (funct7 == 7'b0000000) instruction_type = 8'd33; // ADDW
                                    else if (funct7 == 7'b0100000) instruction_type = 8'd34; // SUBW
                                    else if (funct7 == 7'b0000001) instruction_type = 8'd38; // MULW
                                end
                                3'b001: instruction_type = 8'd35; // SLLW
                                3'b100: instruction_type = 8'd39; // DIVW
                                3'b110: instruction_type = 8'd41; // REMW
                                3'b111: instruction_type = 8'd42; // REMUW
                                3'b101: begin
                                    if (funct7 == 7'b0000000) instruction_type = 8'd36; // SRLW
                                    else if (funct7 == 7'b0100000) instruction_type = 8'd37; // SRAW
                                    else if (funct7 == 7'b0000001) instruction_type = 8'd40; // DIVUW
                                end
                            endcase
                        end
                        
                        // IW-type Instructions
                        7'b0011011: begin
                            rd = instruction[11:7];
                            funct3 = instruction[14:12];
                            rs1 = instruction[19:15];
                            imm = {52'b0, instruction[31:20]};
                            
                            // $display("IW-type instruction detected");
                            // $display("RD: %h", rd);
                            // $display("Funct3: %h", funct3);
                            // $display("RS1: %h", rs1);
                            // $display("RS2: %h", rs2);
                            // $display("Funct7: %h", funct7);
                            // $display("IMM: %d", imm);
                            
                            case(funct3)
                                3'b000: instruction_type = 8'd29; // ADDIW
                                3'b001: begin
                                                    instruction_type = 8'd30; // SLLIW
                                                    shamt[4:0] = instruction[24:20];
                                                end
                                3'b101: begin
                                                    shamt[4:0] = instruction[24:20];
                                                    if (funct7 == 7'b0000000) instruction_type = 8'd31; // SRLIW
                                                    else if (funct7 == 7'b0100000) instruction_type = 8'd32; // SRAIW
                                end
                                default: instruction_type = 8'b11111111; // Unknown Instruction
                            endcase
                        end

/*                      FENCE (I-Type) Instructions
                        7'b0001111: begin
                            pred = instruction[27:24];
                            succ = instruction[23:20];
                            instruction_type = 8'd66;  // FENCE (new value)
                        end */

                        default: instruction_type = 8'b11111111; // Unknown Instruction
                    endcase
                    control_signals_out.imm <= imm;
                    control_signals_out.opcode <= opcode;
                    control_signals_out.shamt <= shamt;
                    control_signals_out.instruction <= instruction_type;
                    if (instruction_type == 8'b11111111) begin
                        $display("CANNOT DETECT TYPE");
                    end
            end else begin
                rd = 5'b0;
                rs1 = 5'b0;
                rs2 = 5'b0;
                imm = 64'b0; // Default to zero
                shamt = 64'b0; // Default to zero
                instruction_type = 8'b0; // Default to unknown
                //decode_complete_next = 0;
            end
            decode_complete = 1;
        end else begin
            rd = 5'b0;
            rs1 = 5'b0;
            rs2 = 5'b0;
            imm = 64'b0; // Default to zero
            shamt = 64'b0; // Default to zero
            instruction_type = 8'b0; // Default to unknown
            decode_complete = 0;
        end
        
    end
endmodule