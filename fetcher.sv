module InstructionFetcher (
    input  logic        clk,                // Clock signal
    input  logic        reset,            // Active-low reset 
    input  logic [63:0] pc_current,         // Current PC value (64 bits)
    input  logic [63:0] target_address,     // Target address for branches/jumps (64 bits)
    input  logic        select_target,      // Control signal for address selection
    output logic [63:0] instruction_out,    // Instruction bits fetched from cache (64 bits)
    output logic [63:0] address_out,        // Address used for fetching (64 bits)
    output logic        fetcher_done,               // Ready signal indicating fetch completion
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
    output logic m_axi_rready                // Ready to accept data from AXI
);

// Internal wires and registers (if needed)
logic [63:0] selected_address;
logic cache_request_ready;
logic [63:0] cache_result;
logic cache_miss_occurred;

/*  STATE DEFINITION SIGNALS
   enum {
    FETCHER_IDLE_STATE = 2'b00,
    FETCHER_REQUEST_STATE = 2'b01,
    FETCHER_WAIT_STATE = 2'b10,
    FETCHER_DONE_STATE = 2'b11
  } current_state, next_state; */


/*   // Cache instantiation
module recache (
    (
    input logic clock,
    input logic reset,
    input logic read_enable,                  // Signal to trigger a cache read
    input logic write_enable,                 // Signal to trigger a cache write
    input logic [63:0] address,               // Address to read/write from/to cache
    input logic [2:0] data_size,              // Size of data requested (in bytes)
    input logic send_complete,                // Indicates data transfer is complete

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

    // Data output and control signals
    output logic [63:0] data,                 // Data output to CPU
    output logic send_enable,                 // Indicates data is ready to send
    output logic read_complete                // Indicates the read operation is complete
);
);
 */


    cache instruction_cache (
        .clock(clk),
        .reset(reset),
        .read_enable(cache_request_ready), //input that fetcher send
        .write_enable(0),
        .address(cache_request_address), // input that fetcher sends
        .data_size(64'b0000000000000000000000000000000000000000000000000000000001000000)
        .send_complete(1)

        .m_axi_arready(m_axi_arready),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_rready(m_axi_rready),

        .data(instruction_out),
        .send_enable(cache_result_ready),
    );  




/* next state selection logic
always_comb begin
    case (current_state)
        FETCHER_IDLE_STATE: begin
            next_state = fetch_enable? FETCHER_REQUEST_STATE: FETCHER_IDLE_STATE;
        end

        FETCHER_REQUEST_STATE: begin
            next_state = cache_request_ready? FETCHER_WAIT_STATE: FETCHER_REQUEST_STATE;
        end

        FETCHER_WAIT_STATE: begin
            next_state = cache_result_ready? FETCHER_DONE_STATE: FETCHER_WAIT_STATE;
        end

        FETCHER_DONE_STATE: begin
            next_state = fetch_ack? FETCHER_IDLE_STATE: FETCHER_DONE_STATE;
        end
    endcase
end

Output assignment logic
always_comb begin
    if (current_state == FETCHER_IDLE_STATE) begin
        fetcher_done_next = 0
        cache_request_address_next  = 64'b0;
        cache_request_ready_next = 0;
    end
    else if (current_state == FETCHER_REQUEST_STATE) begin
        cache_request_address_next = select_target? pc_current : target_address;
        cache_request_ready_next = 1;
    end
    // else if (current_state == FETCHER_WAIT_STATE) begin end
    else if (current_state == FETCHER_DONE_STATE) begin
        fetcher_done_next = 1;
    end
end */

// No states
always_comb begin
    if (reset) begin
        fetcher_done = 0
        cache_request_address  = 64'b0;
        cache_request_ready = 0;
    end else begin
        cache_request_address = select_target ? target_address : pc_current + 4;  // todo: relative vs absolute
        cache_request_ready = 1;
        if (cache_result_ready) begin
            fetcher_done = 1;
        end else begin
            // cache_request_ready = 0;
            fetcher_done = 0;
        end
    end
end

// Sequential logic (state updates, if any)
// always_ff @(posedge clk) begin
//     if (reset) begin
//         current_state <= FETCHER_IDLE_STATE;
//     end else if (current_state == FETCHER_IDLE_STATE) begin
//         fetcher_done <= fetcher_done_next;        
//         cache_request_address <= cache_request_address_next;
//         cache_request_ready <= cache_request_ready_next;
//     end else if (current_state == FETCHER_REQUEST_STATE) begin
//         cache_request_address <= cache_request_address_next;
//         cache_request_ready <= cache_request_ready_next;
//     // end else if (current_state == FETCHER_WAIT_STATE) begin
//     end else if (current_state == FETCHER_DONE_STATE) begin
//         fetcher_done <= fetcher_done_next;
//     end  
// end

endmodule