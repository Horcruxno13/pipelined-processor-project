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

  logic [63:0] pc;

  


   // Instantiate InstructionFetcher with FD_ prefixed signal names
   
   logic F_fetch_enable;
   logic F_fetch_ack;
   logic F_program_counter;
   logic F_target_address;
   logic F_select_target;
   logic F_instruction_out;
   logic F_address_out;
   logic F_fetcher_done;


   logic F_instruction_out_next;
   logic F_address_out_next;
   
    InstructionFetcher instructionFetcher (
        .clk(clk),
        .reset(reset),
        .fetch_enable(F_fetch_enable),
        .fetch_ack(F_fetch_ack),
        .pc_current(F_program_counter),
        .target_address(F_target_address),
        .select_target(F_select_target),
        .instruction_out(F_instruction_out),
        .address_out(F_address_out),
        .fetcher_done(F_fetcher_done),
    );

    /*todo - write the FSM here @angad*/
     //STATE DEFINITION SIGNALS
   enum {
    MAIN_IDLE_STATE = 3'b000,
    MAIN_FETCH_STATE = 3'b001,
    MAIN_DECODE_STATE = 3'b010,
    MAIN_EXECUTE_STATE = 3'b011,
    MAIN_MEMORY_STATE = 3'b100,
    MAIN_WRITE_BACK_STATE = 3'b101
   } main_current_state, main_next_state;


  //next state selection logic
  always_comb begin
      case (current_state)
          MAIN_IDLE_STATE: begin
              // next_state = fetch_enable? FETCHER_REQUEST_STATE: FETCHER_IDLE_STATE;
          end

          MAIN_FETCH_STATE: begin
              // next_state = cache_request_ready? FETCHER_WAIT_STATE: FETCHER_REQUEST_STATE;
              next_state = F_fetcher_done? MAIN_DECODE_STATE: MAIN_FETCH_STATE;
          end

          MAIN_DECODE_STATE: begin
              // next_state = cache_result_ready? FETCHER_DONE_STATE: FETCHER_WAIT_STATE;
          end

          MAIN_EXECUTE_STATE: begin
              // next_state = fetch_ack? FETCHER_IDLE_STATE: FETCHER_DONE_STATE;
          end

          MAIN_MEMORY_STATE: begin
              // next_state = fetch_ack? FETCHER_IDLE_STATE: FETCHER_DONE_STATE;
          end

          MAIN_WRITE_BACK_STATE: begin
              // next_state = fetch_ack? FETCHER_IDLE_STATE: FETCHER_DONE_STATE;
          end
      endcase
  end

    //output variable update logic
  always_comb begin
      case (current_state)
          MAIN_IDLE_STATE: begin
              // next_state = fetch_enable? FETCHER_REQUEST_STATE: FETCHER_IDLE_STATE;
          end

          MAIN_FETCH_STATE: begin
              // next_state = cache_request_ready? FETCHER_WAIT_STATE: FETCHER_REQUEST_STATE;
          end

          MAIN_DECODE_STATE: begin
              // next_state = cache_result_ready? FETCHER_DONE_STATE: FETCHER_WAIT_STATE;
          end

          MAIN_EXECUTE_STATE: begin
              // next_state = fetch_ack? FETCHER_IDLE_STATE: FETCHER_DONE_STATE;
          end

          MAIN_MEMORY_STATE: begin
              // next_state = fetch_ack? FETCHER_IDLE_STATE: FETCHER_DONE_STATE;
          end

          MAIN_WRITE_BACK_STATE: begin
              // next_state = fetch_ack? FETCHER_IDLE_STATE: FETCHER_DONE_STATE;
          end
      endcase
  end



  always_ff @ (posedge clk)
    if (reset) begin
      pc <= entry;
      current_state <= MAIN_IDLE_STATE;
    end else if (current_state == MAIN_IDLE_STATE)

  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end
endmodule
