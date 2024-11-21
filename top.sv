`include "Sysbus.defs"
`include "fetcher.sv"
// `include "pipeline_register.sv"
`include "pipeline_reg_struct.svh"
`include "write_back.sv"
`include "decoder.sv"
`include "execute.sv"
`include "memory.sv"
`include "control_signals_struct.svh"


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

// Initialise Register


logic [63:0] register [31:0];
// logic register_busy [31:0];
logic [4:0] destination_reg;
logic raw_dependency;

logic reg_write_enable;
logic [4:0] reg_write_addr;
logic [4:0] reg_reset_busy_addr;
logic [63:0] reg_write_data;
logic [4:0] read_addr1, read_addr2;
logic [63:0] read_data1, read_data2;

logic instruction_cache_reading;
logic data_cache_reading;

logic upstream_disable;
logic downstream_disable;



register_file registerFile(
    .clk(clk),
    .reset(reset),
    .stackptr(stackptr),
    .read_addr1(read_addr1),
    .read_addr2(read_addr2),
    .read_data1(read_data1),
    .read_data2(read_data2),
    .write_enable(reg_write_enable),
    .write_addr(reg_write_addr),
    .write_data(reg_write_data),
    .write_complete(write_complete),
    .register(register),
    // .register_busy(register_busy),
    .destination_reg(destination_reg),
    .raw_dependency(raw_dependency),
    .reset_write_addr(reg_reset_busy_addr)
);

// Assign initial PC value from entry point

  // Ready/valid handshakes for Fetch, Decode, and Execute stages
  logic fetcher_done, fetch_enable;

   //InstructionFetcher's pipeline register vars
   logic if_id_valid_reg;
   logic [31:0] if_id_instruction_reg, if_id_instruction_reg_next;
   logic [63:0] if_id_pc_plus_i_reg, if_id_pc_plus_i_reg_next;


   /*
   
   
       // AXI interface inputs for read transactions
    input logic m_axi_arready,                // Ready signal from AXI for read address
    input logic m_axi_rvalid,                 // Data valid signal from AXI read data channel
    input logic m_axi_rlast,                  // Last transfer of the read burst
    input logic [63:0] m_axi_rdata,           // Data returned from AXI read channel
    // AXI interface outputs for read transactions
    output logic m_axi_arvalid,               // Valid signal for read address
    output logic [63:0] m_axi_araddr,         // Read address output to AXI
    output logic [7:0] m_axi_arlen,           // Length of the burst (fetches full line)
    output logic [2:0] m_axi_arsize,          // Size of each data unit in the burst
    output logic m_axi_rready,                // Ready to accept data from AXI
   */

    //InstructionFetcher instantiation
    InstructionFetcher instructionFetcher (
        .clk(clk),
        .reset(reset),
        .fetch_enable(fetch_enable),
        .pc_current(initial_pc),
        .target_address(target_address),
        .select_target(mux_selector),
        .instruction_out(if_id_instruction_reg_next),
        .cache_request_address(if_id_pc_plus_i_reg_next),
        .m_axi_arready(m_axi_arready),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_rready(m_axi_rready),
        .m_axi_arburst(m_axi_arburst),
        .if_id_pipeline_valid(if_id_valid_reg),
        .fetcher_done(fetcher_done),
        .instruction_cache_reading(instruction_cache_reading),
        .data_cache_reading(data_cache_reading)
    );

    logic fetch_reset_done;

    // IF/ID Pipeline Register Logic (between Fetch and Decode stages)
    always_ff @(posedge clk) begin
        if (reset) begin
            if_id_instruction_reg <= 32'b0;
            if_id_pc_plus_i_reg <= 64'b0;
            initial_pc <= entry;
            target_address <= 0;
            mux_selector <= 0;
            fetch_enable <= 1;
            fetch_reset_done <= 0;
            upstream_disable <= 0;
            downstream_disable <= 0;
        end else begin
            if (!fetch_enable) begin
                if_id_instruction_reg <= 32'b0;
                if_id_pc_plus_i_reg <= 64'b0;
                if_id_valid_reg <= 0;
                fetch_reset_done <= 1'b1;       
                reg_reset_busy_addr <= destination_reg;
                if (fetch_reset_done) begin
                    fetch_enable <= 1;
                    decode_enable <= 1;
                    execute_enable <= 1;
                    memory_enable <= 1;
                    fetch_reset_done <= 1'b0;       // Clear the flag
                    upstream_disable <= 0;
                end
            end else begin
                if (fetcher_done) begin
                    // Load fetched instruction into IF/ID pipeline registers
                    if_id_instruction_reg <= if_id_instruction_reg_next;
                    if_id_pc_plus_i_reg <= if_id_pc_plus_i_reg_next;
                    if_id_valid_reg <= 1;
                end
            end
        end
    end


    // DECODER STARTS
    logic decode_done, decode_ready, decode_enable;

    //InstructionDecoder's pipeline register vars
    logic id_ex_valid_reg;
    logic [63:0] id_ex_reg_a_data, id_ex_reg_a_addr;
    logic [63:0] id_ex_reg_b_data, id_ex_reg_b_addr;
    logic [63:0] id_ex_pc_plus_I_reg;
    control_signals_struct id_ex_control_signal_struct, id_ex_control_signal_struct_next;
    logic register_values_ready;

    InstructionDecoder instructionDecoder (
        .clk(clk),
        .reset(reset),
        .instruction(if_id_instruction_reg),
        .pc_current(if_id_pc_plus_i_reg),
        .decode_enable(if_id_valid_reg),
        .rs1(id_ex_reg_a_addr),      // Example output: reg_a
        .rs2(id_ex_reg_b_addr),      // Example output: reg_b
        .register_values_ready(register_values_ready),
        .control_signals_out(id_ex_control_signal_struct_next), // Example output: control signals
        .decode_complete(decode_done),
        .rd(destination_reg)
    );

    // ID/EX Pipeline Register Logic (between Decode and Execute stages)
    always_ff @(posedge clk) begin
        if (reset) begin
            id_ex_pc_plus_I_reg <= 64'b0;
            id_ex_reg_a_data <= 64'b0;
            id_ex_reg_b_data <= 64'b0;
            id_ex_valid_reg <= 1'b0;
            id_ex_control_signal_struct <= '0;
            decode_enable <= 1;
        end else begin
            if (!decode_enable && upstream_disable) begin
                id_ex_pc_plus_I_reg <= 64'b0;
                id_ex_reg_a_data <= 64'b0;
                id_ex_reg_b_data <= 64'b0;
                id_ex_valid_reg <= 1'b0;
                id_ex_control_signal_struct <= '0;
            end else begin
                if (decode_done) begin
                // Load fetched instruction into ID/EX pipeline registers
                    id_ex_pc_plus_I_reg <= if_id_pc_plus_i_reg;
                    id_ex_control_signal_struct <= id_ex_control_signal_struct_next;
                    // pass to reg
                    read_addr1 <= id_ex_reg_a_addr;
                    read_addr2 <= id_ex_reg_b_addr;
                
                    if (!raw_dependency) begin
                        register_values_ready <= 1'b1;       // Signal next cycle to read data
                    end else begin
                        register_values_ready <= 1'b0;
                    end  

                    if (register_values_ready && !raw_dependency) begin
                        // Step 2: Latch register file output values to pipeline registers
                        id_ex_reg_a_data <= read_data1;
                        id_ex_reg_b_data <= read_data2;
                        register_values_ready <= 1'b0;       // Clear the flag
                        id_ex_valid_reg <= 1;
                        initial_pc <= initial_pc + 4;
                        if_id_valid_reg <= 0;
                    end 
                end 
            end
        end
    end

    // EXECUTOR STARTS
    logic execute_done, execute_ready, execute_enable;

    //InstructionExecutor's pipeline register vars
    logic ex_mem_valid_reg;
    logic [63:0] ex_mem_pc_plus_I_offset_reg, ex_mem_pc_plus_I_offset_reg_next;
    logic [63:0] ex_mem_alu_data, ex_mem_alu_data_next;
    logic [63:0] ex_mem_reg_b_data;
    control_signals_struct ex_mem_control_signal_struct_next, ex_mem_control_signal_struct;

    InstructionExecutor instructionExecutor (
        .clk(clk),
        .reset(reset),
        .execute_enable(id_ex_valid_reg),
        .pc_current(id_ex_pc_plus_I_reg),
        .reg_a_contents(id_ex_reg_a_data), 
        .reg_b_contents(id_ex_reg_b_data), 
        .control_signals(id_ex_control_signal_struct),
        .alu_data_out(ex_mem_alu_data_next),
        .pc_I_offset_out(ex_mem_pc_plus_I_offset_reg_next),
        .control_signals_out(ex_mem_control_signal_struct_next),
        .execute_done(execute_done)
    );

    // EX/MEM Pipeline Register Logic (between Execute and Memory stages)
    always_ff @(posedge clk) begin
        if (reset ) begin
            ex_mem_alu_data <= 64'b0;
            ex_mem_pc_plus_I_offset_reg <= 64'b0;
            ex_mem_reg_b_data <= 64'b0;
            ex_mem_control_signal_struct <= '0;
            execute_enable <= 1;
        end else begin
            if (!execute_enable && upstream_disable) begin
                ex_mem_alu_data <= 64'b0;
                ex_mem_pc_plus_I_offset_reg <= 64'b0;
                ex_mem_reg_b_data <= 64'b0;
                ex_mem_control_signal_struct <= '0;
            end else if (execute_done && execute_enable) begin
                // Load decoded instruction into EX/MEM pipeline registers
                ex_mem_pc_plus_I_offset_reg <= ex_mem_pc_plus_I_offset_reg_next;
                ex_mem_alu_data <= ex_mem_alu_data_next;

                ex_mem_reg_b_data <= id_ex_reg_b_data;
                ex_mem_control_signal_struct <= ex_mem_control_signal_struct_next;
                if (ex_mem_control_signal_struct_next.jump_signal) begin
                    upstream_disable <= 1;
                end
                ex_mem_valid_reg <= 1;
                execute_enable <= 0;
                downstream_disable <= 1;
                id_ex_valid_reg <= 0;
            end
            
        end 
            
    end
    

    // MEMORY STARTS
    logic memory_done, memory_ready, memory_enable;

    //InstructionMemory's pipeline register vars
    logic [63:0] mem_wb_loaded_data, mem_wb_loaded_data_next;
    control_signals_struct mem_wb_control_signals_reg;
    logic [63:0] mem_wb_alu_data;
    logic mem_wb_valid_reg;

    InstructionMemoryHandler instructionMemoryHandler (
        .clk(clk),                
        .reset(reset),            
        .pc_I_offset(ex_mem_pc_plus_I_offset_reg),        
        .reg_b_contents(ex_mem_reg_b_data),         
        .alu_data(ex_mem_alu_data),    
        .control_signals(ex_mem_control_signal_struct),    
        .memory_enable(ex_mem_valid_reg),
        .mem_wb_pipeline_valid(mem_wb_valid_reg),
        .instruction_cache_reading(instruction_cache_reading),
        .m_axi_arready(m_axi_arready),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_awready(m_axi_awready),
        .m_axi_wready(m_axi_wready),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bresp(m_axi_bresp),

        .loaded_data_out(mem_wb_loaded_data_next),
        .memory_done(memory_done),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_rready(m_axi_rready),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_bready(m_axi_bready),
        .data_cache_reading(data_cache_reading)
    );


    // assign memory_ready = ~ex_mem_imm_reg;
    

    always_ff @(posedge clk) begin
        if (reset) begin
            mem_wb_control_signals_reg <= '0;
            mem_wb_loaded_data <= 64'b0;
            mem_wb_alu_data <= 64'b0;
            memory_enable <= 1;
        end else begin
            if (downstream_disable) begin
                target_address <= ex_mem_pc_plus_I_offset_reg;
                mux_selector <= ex_mem_control_signal_struct.jump_signal;
            end
            if (downstream_disable && ex_mem_control_signal_struct.jump_signal) begin
                initial_pc <= ex_mem_pc_plus_I_offset_reg;
                execute_enable <= 0;
                decode_enable <= 0;
                fetch_enable <= 0;
                memory_enable <= 0;
                downstream_disable <= 0;
            end

            if (memory_done && memory_enable) begin
                mem_wb_control_signals_reg <= ex_mem_control_signal_struct;
                mem_wb_loaded_data <= mem_wb_loaded_data_next;
                mem_wb_alu_data <= ex_mem_alu_data;
                mem_wb_valid_reg <= 1;
                ex_mem_valid_reg <= 0;

                if (!upstream_disable) begin
                    execute_enable <= 1; //don't want to come in fetcher's way, let that restart things as it was doing
                    downstream_disable <= 0;
                end
            end
        end
    end

    // WRITE BACK STARTS
    logic write_back_ready;

    //InstructionWriteBacks's output vars
    logic [63:0] wb_dest_reg_out, wb_dest_reg_out_next;
    logic [63:0] wb_data_out, wb_data_out_next;

    InstructionWriteBack instructionWriteBack (
        .clk(clk),
        .reset(reset),
        .loaded_data(mem_wb_loaded_data),
        .alu_result(mem_wb_alu_data),
        .control_signals(mem_wb_control_signals_reg),
        .write_reg(wb_dest_reg_out_next),
        .write_data(wb_data_out_next),
        .write_enable(wb_write_enable),
        .wb_module_enable(mem_wb_valid_reg)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            wb_dest_reg_out <= 64'b0;
            wb_data_out <= 64'b0;
            reg_write_enable <= 0;
        end else begin
                // pass to reg
                // read_addr1 <= 0;
                // read_addr2 <= 0;
                reg_write_enable <= wb_write_enable;
                reg_write_addr <= wb_dest_reg_out_next;
                reg_write_data <= wb_data_out_next;
                if (write_complete) begin
                    mem_wb_valid_reg <= 0;
                end 
        end
    end

     /*   module InstructionFetcher (
    input  logic        clk,                // Clock signal
    input  logic        reset,            // Active-low reset
    input  logic        fetch_ack,       // Signal to acknowledge collection of outputs
    input  logic [63:0] pc_current,         // Current PC value (64 bits)
    input  logic [63:0] target_address,     // Target address for branches/jumps (64 bits)
    input  logic        select_target,      // Control signal for address selection
    output logic [63:0] instruction_out,    // Instruction bits fetched from cache (64 bits)
    output logic [63:0] address_out,        // Address used for fetching (64 bits)
    output logic        fetcher_done,               // Ready signal indicating fetch completion
); */

     /*   Fetcher ready logic
  assign fetch_ready = ~if_id_valid_reg;

    IF/ID Pipeline Register Logic (between Fetch and Decode stages)
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
            // When decode stage reads the data
            if (decode_ready) begin
                if_id_valid_reg <= 1'b0; // Clear valid once read by decode
            end 
        end
    end */

    /*
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
            //  if (execute_ready) begin
            //     id_ex_valid_reg <= 1'b0; // Clear valid once read by execute
            // end 
        end
    end
    
    
    // Execute logic ready
    assign execute_ready = ~id_ex_imm_reg;

    // EX/MEM Pipeline Register Logic (between Execute and Memory stages)
    always_ff @(posedge clk) begin
        if (reset) begin
            ex_mem_alu_data <= 64'b0;
            ex_mem_pc_plus_I_offset_reg <= 64'b0;
            ex_mem_control_signals_reg <= 64'b0;
        end else begin
            if (execute_done && execute_ready) begin
                // Load decoded instruction into EX/MEM pipeline registers
                ex_mem_pc_plus_I_offset_reg <= ex_mem_pc_plus_I_offset_reg_next;
                ex_mem_alu_data <= ex_mem_alu_data_next;
                ex_mem_reg_b_data <= ex_mem_reg_b_data_next;
                ex_mem_control_signals_reg <= id_ex_control_signal_struct;
            end
            // When execute stage reads the data
/*             if (execute_ready) begin
                id_ex_valid_reg <= 1'b0; // Clear valid once read by execute
            end
        end
    end
    
    */
  
endmodule

