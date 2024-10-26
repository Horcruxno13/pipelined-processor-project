module cache #(
    parameter cache_line_size = 64,
    parameter cache_lines = 256,
    parameter sets = 64,
    parameter ways = 4,
    parameter addr_width = 64,
    parameter data_width = 32
) (
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


//     typedef enum logic [2:0] {
//     IDLE,
//     CHECK_HIT,
//     HIT,
//     MISS,
//     WAIT_FOR_MEMORY,
//     ALLOCATE
// } cache_state_t;

// cache_state_t state, next_state;

// // State transition
// always_ff @(posedge clock or posedge reset) begin
//     if (reset)
//         state <= IDLE;
//     else
//         state <= next_state;
// end

// Next state logic
// always_comb begin
//     case (state)
//         IDLE: begin
//             if (read_enable || write_enable)
//                 next_state = CHECK_HIT;
//             else
//                 next_state = IDLE;
//         end
//         CHECK_HIT: begin
//             if (/* hit condition */)
//                 next_state = HIT;
//             else
//                 next_state = MISS;
//         end
//         HIT: begin
//             next_state = IDLE;
//         end
//         MISS: begin
//             next_state = WAIT_FOR_MEMORY;
//         end
//         WAIT_FOR_MEMORY: begin
//             if (/* memory response ready */)
//                 next_state = ALLOCATE;
//             else
//                 next_state = WAIT_FOR_MEMORY;
//         end
//         ALLOCATE: begin
//             next_state = HIT;
//         end
//         default: next_state = IDLE;
//     endcase
// end

    // // Cache line structure
    // typedef struct packed {
    //     logic valid;
    //     logic [INSTRUCTION_WIDTH-1:0] tag;
    //     logic [CACHE_LINE_SIZE*8-1:0] data;
    // } cache_line_t;

    // // Cache memory
    // cache_line_t cache_mem[SETS-1:0][WAYS-1:0];

    // // Index and tag extraction
    // logic [clog2(SETS)-1:0] index;
    // logic [INSTRUCTION_WIDTH-clog2(SETS)-1:0] tag;

    // assign index = instruction_address[clog2(SETS)-1:0];
    // assign tag = instruction_address[INSTRUCTION_WIDTH-1:clog2(SETS)];

    // // Cache read and write logic
    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         // Reset cache
    //         for (int i = 0; i < SETS; i++) begin
    //             for (int j = 0; j < WAYS; j++) begin
    //                 cache_mem[i][j].valid <= 0;
    //             end
    //         end
    //     end else if (read_enable) begin
    //         hit = 0;
    //         for (int i = 0; i < WAYS; i++) begin
    //             if (cache_mem[index][i].valid && cache_mem[index][i].tag == tag) begin
    //                 read_data = cache_mem[index][i].data;
    //                 hit = 1;
    //                 break;
    //             end
    //         end
    //     end else if (write_enable) begin
    //         // Write data to cache (simple write-through policy)
    //         for (int i = 0; i < WAYS; i++) begin
    //             if (!cache_mem[index][i].valid || cache_mem[index][i].tag == tag) begin
    //                 cache_mem[index][i].valid <= 1;
    //                 cache_mem[index][i].tag <= tag;
    //                 cache_mem[index][i].data <= write_data;
    //                 break;
    //             end
    //         end
    //     end
    // end

endmodule