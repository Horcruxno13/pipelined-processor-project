module InstructionFetcher (
    input  logic        clk,                // Clock signal
    input  logic        reset,            // Active-low reset
    input 
    input  logic        fetch_ack,       // Signal to acknowledge collection of outputs
    input  logic        start_flag,
    input  logic [63:0] pc_current,         // Current PC value (64 bits)
    input  logic [63:0] target_address,     // Target address for branches/jumps (64 bits)
    input  logic        select_target,      // Control signal for address selection
    output logic [63:0] instruction_out,    // Instruction bits fetched from cache (64 bits)
    output logic [63:0] address_out,        // Address used for fetching (64 bits)
    output logic        fetcher_done,               // Ready signal indicating fetch completion
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
module cache (
    input logic clock,                           // Clock signal
    input logic reset,                           // Reset signal
    
    input logic [addr_width-1:0] address,        // Address for read/write
    input logic [data_width-1:0] write_data,     // Data to write to cache
    input logic read_enable,                     // Signal to enable read
    input logic write_enable,                    // Signal to enable write
    input logic [7:0] byte_enable,               // Byte enable (optional)
    
    output logic [data_width-1:0] read_data,     // Data read from cache
    output logic data_valid,                     // Signals that read_data is ready
    output logic write_complete                  // Signals write completion
);
 */


    cache instruction_cache (
        .clock(clk),
        .reset(reset),
        .address(cache_request_address), // input that fetcher sends
        .write_data(null),
        .read_enable(cache_request_ready), //input that fetcher send
        .write_enable(null),
        .byte_enable(null),
        .read_data(null),
        .cache_result(instruction_out)
        .data_valid(cache_result_ready), //output that fetcher gets
        .write_complete(null)
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
        cache_request_address = select_target? pc_current : target_address;
        cache_request_ready = 1;
        if (cache_result_ready) begin
            fetcher_done = 1;
        end else begin
            cache_request_ready = 0;
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