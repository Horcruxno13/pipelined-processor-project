`include "Sysbus.defs"
`include "fetcher.sv"
`include "pipeline_register.sv"
`include "pipeline_reg_struct.svh"
`include "write_back.sv"

module top
#(
  ID_WIDTH = 13,
  ADDR_WIDTH = 64,
  DATA_WIDTH = 64,
  STRB_WIDTH = DATA_WIDTH/8
)
(
  input  clk,
         reset,
         hz32768timer,

  // 64-bit addresses of the program entry point and initial stack pointer
  input  [63:0] entry,
  input  [63:0] stackptr,
  input  [63:0] satp,

  // interface to connect to the bus
  output  wire [ID_WIDTH-1:0]    m_axi_awid,
  output  wire [ADDR_WIDTH-1:0]  m_axi_awaddr,
  output  wire [7:0]             m_axi_awlen,
  output  wire [2:0]             m_axi_awsize,
  output  wire [1:0]             m_axi_awburst,
  output  wire                   m_axi_awlock,
  output  wire [3:0]             m_axi_awcache,
  output  wire [2:0]             m_axi_awprot,
  output  wire                   m_axi_awvalid,
  input   wire                   m_axi_awready,
  output  wire [DATA_WIDTH-1:0]  m_axi_wdata,
  output  wire [STRB_WIDTH-1:0]  m_axi_wstrb,
  output  wire                   m_axi_wlast,
  output  wire                   m_axi_wvalid,
  input   wire                   m_axi_wready,
  input   wire [ID_WIDTH-1:0]    m_axi_bid,
  input   wire [1:0]             m_axi_bresp,
  input   wire                   m_axi_bvalid,
  output  wire                   m_axi_bready,
  output  wire [ID_WIDTH-1:0]    m_axi_arid,
  output  wire [ADDR_WIDTH-1:0]  m_axi_araddr,
  output  wire [7:0]             m_axi_arlen,
  output  wire [2:0]             m_axi_arsize,
  output  wire [1:0]             m_axi_arburst,
  output  wire                   m_axi_arlock,
  output  wire [3:0]             m_axi_arcache,
  output  wire [2:0]             m_axi_arprot,
  output  wire                   m_axi_arvalid,
  input   wire                   m_axi_arready,
  input   wire [ID_WIDTH-1:0]    m_axi_rid,
  input   wire [DATA_WIDTH-1:0]  m_axi_rdata,
  input   wire [1:0]             m_axi_rresp,
  input   wire                   m_axi_rlast,
  input   wire                   m_axi_rvalid,
  output  wire                   m_axi_rready,
  input   wire                   m_axi_acvalid,
  output  wire                   m_axi_acready,
  input   wire [ADDR_WIDTH-1:0]  m_axi_acaddr,
  input   wire [3:0]             m_axi_acsnoop
);


// Initial PC
logic [63:0] initial_pc;
logic [63:0] target_address;
logic initial_selector;

// Assign initial PC value from entry point
assign [63:0] initial_pc = entry;
assign target_address = 0;
assign mux_selector = 0;

  // Ready/valid handshakes for Fetch, Decode, and Execute stages
  logic fetcher_done, fetch_ready;

   //InstructionFetcher's pipeline register vars
   logic if_id_valid_reg, if_id_valid_reg_next;
   logic [31:0] if_id_instruction_reg, if_id_instruction_reg_next;
   logic [63:0] if_id_pc_plus_i_reg, if_id_pc_plus_i_reg_next;

    //InstructionFetcher instantiation
    InstructionFetcher instructionFetcher (
        .clk(clk),
        .reset(reset),
        .pc_current(initial_pc),
        .target_address(target_address),
        .select_target(mux_selector),
        .instruction_out(if_id_instruction_reg_next),
        .address_out(if_id_pc_plus_i_reg_next),
        .fetcher_done(fetcher_done),
    );

  // Fetcher ready logic
  assign fetch_ready = ~if_id_valid_reg;

    // IF/ID Pipeline Register Logic (between Fetch and Decode stages)
    always_ff @(posedge clk) begin
        if (reset) begin
            if_id_instruction_reg <= 32'b0;
            if_id_pc_plus_i_reg <= 64'b0;
            if_id_valid_reg <= 1'b0;
        end else begin
            if (fetcher_done && fetch_ready) begin
                // Load fetched instruction into IF/ID pipeline registers
                if_id_instruction_reg <= if_id_instruction_reg_next;
                if_id_pc_plus_i_reg <= if_id_pc_plus_i_reg_next;
                if_id_valid_reg <= 1'b1; // Data in IF/ID is valid
            end
            /* // When decode stage reads the data
            if (decode_ready) begin
                if_id_valid_reg <= 1'b0; // Clear valid once read by decode
            end */
        end
    end

    // DECODER STARTS
    logic decode_done, decode_ready;

    //InstructionDecoder's pipeline register vars
    logic id_ex_valid_reg, id_ex_valid_reg_next;
    logic [63:0] id_ex_reg_a_reg, id_ex_reg_a_reg_next;
    logic [63:0] id_ex_reg_b_reg, id_ex_reg_b_reg_next;
    logic [63:0] id_ex_pc_plus_I_reg, id_ex_pc_plus_I_reg_next;
    logic [63:0] id_ex_control_signals_reg, id_ex_control_signals_reg_next;

    InstructionDecoder instructionDecoder (
        .clk(clk),
        .instruction(if_id_instruction_reg),
        .pc_current(if_id_pc_plus_i_reg),
        .decode_enable(if_id_valid_reg)
        .reg_a_out(id_ex_reg_a_reg_next),      // Example output: reg_a
        .reg_b_out(id_ex_reg_b_reg_next),      // Example output: reg_b
        .pc_plus_I_out(id_ex_pc_plus_I_reg_next), // Example output: PC + 1
        .control_signals(id_ex_control_signals_reg_next), // Example output: control signals
        .decode_complete(decode_done)
    );

    // Decoder ready logic
    // assign decode_ready = ~id_ex_valid_reg || execute_ready;
    assign decode_ready = ~id_ex_valid_reg;

    // ID/EX Pipeline Register Logic (between Decode and Execute stages)
    always_ff @(posedge clk) begin
        if (reset) begin
            id_ex_pc_plus_1_reg <= 64'b0;
            id_ex_reg_a_reg <= 64'b0;
            id_ex_reg_b_reg <= 64'b0;
            id_ex_control_signals_reg <= 64'b0;
            id_ex_imm_reg <= 64'b0;
            id_ex_valid_reg <= 1'b0;
        end else begin
            if (decode_done && decode_ready) begin
                // Load decoded instruction into ID/EX pipeline registers
                id_ex_pc_plus_1_reg <= id_ex_pc_plus_1_reg_next;
                id_ex_reg_a_reg <= id_ex_reg_a_reg_next;
                id_ex_reg_b_reg <= id_ex_reg_b_reg_next;
                id_ex_control_signals_reg <= id_ex_control_signals_reg_next;
                id_ex_imm_reg <= id_ex_imm_reg_next;
                id_ex_valid_reg <= 1'b1; // Data in ID/EX is valid
            end
            // When execute stage reads the data
/*             if (execute_ready) begin
                id_ex_valid_reg <= 1'b0; // Clear valid once read by execute
            end */
        end
    end

    // EXECUTOR STARTS
    logic execute_done, execute_ready;

    //InstructionExecutor's pipeline register vars
    logic ex_mem_valid_reg, ex_mem_valid_reg_next;
    logic [63:0] ex_mem_pc_plus_I_offset_reg, ex_mem_pc_plus_I_offset_reg_next;
    logic [63:0] ex_mem_alu_data, ex_mem_reg_alu_data_next;
    logic [63:0] ex_mem_reg_b_data, ex_mem_reg_b_data_next;
    logic [63:0] ex_mem_control_signals_reg, ex_mem_control_signals_reg_next;

    InstructionExecutor instructionExecutor (
        clk(clk),
        reset(reset),
        pc_current(id_ex_pc_plus_1_reg),
        reg_a_contents(id_ex_reg_a_reg), 
        reg_b_contents(id_ex_reg_b_reg), 
        control_signals(id_ex_control_signals_reg),
        control_signals_out(ex_mem_control_signals_reg_next), 
        reg_b_data_out(ex_mem_reg_b_data_next),
        alu_data_out(ex_mem_reg_alu_data_next),
        pc_I_offset_out(ex_mem_pc_plus_I_offset_reg_next),
        execute_done(execute_done) 
    );
    
    // Execute logic ready
    assign execute_ready = ~id_ex_imm_reg;

    // EX/MEM Pipeline Register Logic (between Execute and Memory stages)
    always_ff @(posedge clk) begin
        if (reset) begin
            ex_mem_pc_plus_I_offset_reg <= 64'b0;
            ex_mem_alu_data <= 64'b0;
            ex_mem_reg_b_data <= 64'b0;
            ex_mem_control_signals_reg <= 64'b0;
        end else begin
            if (execute_done && execute_ready) begin
                // Load decoded instruction into EX/MEM pipeline registers
                ex_mem_pc_plus_I_offset_reg <= ex_mem_pc_plus_I_offset_reg_next;
                ex_mem_alu_data <= ex_mem_alu_data_next;
                ex_mem_reg_b_data <= ex_mem_reg_b_data_next;
                ex_mem_control_signals_reg <= ex_mem_control_signals_reg_next;
            end
            // When execute stage reads the data
/*             if (execute_ready) begin
                id_ex_valid_reg <= 1'b0; // Clear valid once read by execute
            end */
        end
    end


    // MEMORY STARTS
    logic memory_done, memory_ready;

    //InstructionMemory's pipeline register vars
    logic mem_wb_valid_reg, mem_wb_valid_reg_next;
    logic [63:0] mem_wb_target_address, mem_wb_target_address_next;
    logic [63:0] mem_wb_control_signals_reg, mem_wb_control_signals_reg_next;
    logic [63:0] mem_wb_loaded_data, mem_wb_loaded_data_next;
    logic [63:0] mem_wb_alu_data, mem_wb_reg_alu_data_next;

    InstructionMemoryHandler instructionMemoryHandler(
        clk(clk),                
        reset(reset),            
        pc_I_offset(ex_mem_pc_plus_I_offset_reg),        
        reg_b_contents(ex_mem_reg_b_data),         
        alu_data(ex_mem_reg_alu_data),    
        control_signals(ex_mem_control_signals_reg),    
        target_address_out(mem_wb_target_address_next),
        control_signals_out(mem_wb_control_signals_reg_next),  
        loaded_data_out(mem_wb_loaded_data_next),
        alu_data_out(mem_wb_alu_data_next),
        memory_done(memory_done) 
    );

    assign memory_ready = ~ex_mem_imm_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            mem_wb_target_address <= 64'b0;
            mem_wb_control_signals_reg <= 64'b0;
            mem_wb_loaded_data <= 64'b0;
            mem_wb_alu_data <= 64'b0;
        end else begin
            if (memory_done && memory_ready) begin
                // Load decoded instruction into EX/MEM pipeline registers
                mem_wb_target_address <= mem_wb_target_address_next;
                mem_wb_control_signals_reg <= mem_wb_control_signals_reg_next;
                mem_wb_loaded_data <= mem_wb_loaded_data_next;
                mem_wb_alu_data <= mem_wb_alu_data_next;
            end
            // When execute stage reads the data
/*             if (execute_ready) begin
                id_ex_valid_reg <= 1'b0; // Clear valid once read by execute
            end */
        end
    end

    // WRITE BACK STARTS
    logic write_back_done, write_back_ready;

    //InstructionWriteBacks's output vars
    logic [63:0] wb_dest_reg_out, wb_dest_reg_out_next;
    logic [63:0] wb_data_out, wb_data_out_next;

    InstructionWriteBack instructionMemoryHandler (
        clk(clk),
        reset(reset),
        loaded_data(mem_wb_loaded_data),
        alu_data(mem_wb_alu_data),
        control_signals(mem_wb_control_signals_reg),
        dest_reg_out(wb_dest_reg_out_next),
        data_out(wb_data_out_next),
        write_back_done(write_back_done)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            wb_dest_reg_out <= 64'b0;
            wb_data_out <= 64'b0;
        end else begin
            if (write_back_done && write_back_done) begin
                // Load decoded instruction to feed into register
                wb_dest_reg_out <= wb_dest_reg_out_next;
                wb_data_out <= wb_data_out_next;
            end
            // When execute stage reads the data
/*             if (execute_ready) begin
                id_ex_valid_reg <= 1'b0; // Clear valid once read by execute
            end */
        end
    end
  
endmodule
