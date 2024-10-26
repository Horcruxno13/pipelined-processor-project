module pipeline_register 
#()
(
    input clk,
    input reset,

    // ------------------ Flags for pipeline movement
    input if_data_ready, id_data_ready, ex_data_ready, mem_data_ready,
    input id_valid, ex_valid, mem_valid, wb_valid,

    output logic if_id_push_done,
    output logic id_ex_push_done,
    output logic ex_mem_push_done,
    output logic mem_wb_push_done,

    // ------------------- Data in from prev stages
    // From fetch
    input if_pc,
    input if_instruction,

    // From decode
    input [63:0] pc,
    input [31:0] reg_data1,
    input [31:0] reg_data2,
    input [31:0] imm,
    input [4:0]  rs1, rs2, rd,
    input [3:0]  alu_control,
    input        reg_write,

    // From execute
    input [31:0] alu_result,
    input [31:0] reg_data2,
    input [4:0]  rd,
    input        mem_write,
    input        reg_write

    // From memory access
    logic [31:0] alu_result,
    logic [31:0] mem_read_data,
    logic [4:0]  rd,
    logic        reg_write

    // Output registers
    output if_id_reg_struct  if_id_reg,
    output id_ex_reg_struct  id_ex_reg,
    output ex_mem_reg_struct ex_mem_reg,
    output mem_wb_reg_struct mem_wb_reg
);
    logic if_id_push_done_next,
    logic id_ex_push_done_next,
    logic ex_mem_push_done_next,
    logic mem_wb_push_done_next,

    always_ff @posedge(clk) begin
        if (reset) begin
            if_id_reg <= '0;
            id_ex_reg <= '0;
            ex_mem_reg <= '0;
            mem_wb_reg <= '0;
            if_id_push_done <= 0;
            id_ex_push_done <= 0;
            ex_mem_push_done <= 0;
            mem_wb_push_done <= 0;
        end else begin
            if_id_push_confirmed <= if_id_push_confirmed_next;
            id_ex_push_confirmed <= id_ex_push_confirmed_next;
            ex_mem_push_confirmed <= ex_mem_push_confirmed_next;
            mem_wb_push_confirmed <= mem_wb_push_confirmed_next;

            // Populate IF/ID Register
            if (if_data_ready && id_valid) begin
                if_id.pc          <= if_pc;
                if_id.instruction <= if_instruction;
            end

            // Populate ID/EX Register
            if (id_data_ready && ex_valid) begin
                id_ex.pc          <= id_pc;
                id_ex.reg_data1   <= id_reg_data1;
                id_ex.reg_data2   <= id_reg_data2;
                id_ex.imm         <= id_imm;
                id_ex.rs1         <= id_rs1;
                id_ex.rs2         <= id_rs2;
                id_ex.rd          <= id_rd;
                id_ex.alu_control <= id_alu_control;
                id_ex.reg_write   <= id_reg_write;
            end

            // Populate EX/MEM Register
            if (ex_data_ready && mem_valid) begin
                ex_mem.alu_result <= ex_alu_result;
                ex_mem.reg_data2  <= ex_reg_data2;
                ex_mem.rd         <= ex_rd;
                ex_mem.mem_write  <= ex_mem_write;
                ex_mem.reg_write  <= ex_reg_write;
            end

            // Populate MEM/WB Register
            if (mem_data_ready && wb_valid) begin
                mem_wb.alu_result    <= mem_alu_result;
                mem_wb.mem_read_data <= mem_read_data;
                mem_wb.rd            <= mem_rd;
                mem_wb.reg_write     <= mem_reg_write;
            end
        end
    end

    always_comb begin
        if (if_data_ready && id_valid) begin
            if_id_push_confirmed_next = 1;
        end else begin
            if_id_push_confirmed_next = 0;
        end

        if (id_data_ready && ex_valid) begin 
            id_ex_push_confirmed_next = 1;
        end else begin
            id_ex_push_confirmed_next = 0;
        end

        if (ex_data_ready && mem_valid) begin
            ex_mem_push_confirmed_next = 1;
        end else begin
            ex_mem_push_confirmed_next = 0;
        end

        if (mem_data_ready && wb_valid) begin
            mem_wb_push_confirmed_next = 1;
        end else begin
            mem_wb_push_confirmed_next = 0;
        end
    end

endmodule