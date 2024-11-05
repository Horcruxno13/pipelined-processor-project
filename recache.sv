module recache #(
    parameter cache_line_size = 64,           // Size of each cache line in bytes
    parameter cache_lines = 4,              // Total number of cache lines
    parameter sets = 64,                      // Number of sets in the cache
    parameter ways = 1,                       // Number of ways (associativity) in the cache
    parameter addr_width = 64,                // Width of the address bus
    parameter data_width = 32                 // Width of the data bus
)(
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
    output logic [1:0] m_axi_arburst,
    output logic m_axi_rready,                // Ready to accept data from AXI

    // Data output and control signals
    output logic [63:0] data,                 // Data output to CPU
    output logic send_enable                 // Indicates data is ready to send
    //output logic read_complete                // Indicates the read operation is complete
);

enum logic [3:0] {
    IDLE_HIT      = 4'b0000, // Idle and cache hit handling for reads
    MISS_REQUEST  = 4'b0001, // Handling read cache miss, initiating memory request
    MEMORY_WAIT   = 4'b0010, // Waiting for memory response after a miss
    MEMORY_ACCESS = 4'b0011, // Accessing data as it's received from memory
    STORE_DATA    = 4'b0100  // Storing data into cache after a read miss
} current_state, next_state;

// Derived parameters
localparam block_offset_width = $clog2(cache_line_size / data_width);
localparam set_index_width = $clog2(sets);
localparam tag_width = addr_width - set_index_width - block_offset_width;

// Cache storage arrays
logic [tag_width-1:0] tags [sets-1:0][ways-1:0];            // Array for storing tags
logic [cache_line_size-1:0] cache_data [sets-1:0][ways-1:0];      // Array for storing cache line data
logic valid_bits [sets-1:0][ways-1:0];                       // Valid bits array

// internal logic bits
logic cache_hit;
logic check_done;
logic [set_index_width-1:0] set_index;
logic [tag_width-1:0] tag;
logic [block_offset_width-1:0] block_offset;
logic [data_width-1:0] data_out; 
logic [31:0] buffer_array[0:15];    // 16 instructions, each 32 bits
logic [3:0] buffer_pointer;          // Points to the next location in buffer_array
logic [2:0] burst_counter;           // Counts each burst (0-7)
logic [63:0] current_transfer_value;
logic data_retrieved;

// internal logic next bits
logic cache_hit_next;
logic check_done_next;
logic [data_width-1:0] data_out_next;
logic send_enable_next;
logic data_retrieved_next;

// Control signals and variables
// logic cache_hit;
// logic [31:0] data_out;
logic [31:0] cache_memory [0:15];  // Simplified cache array for demonstration
logic [7:0]  m_axi_arlen;          // Number of transfers in burst
logic        m_axi_arvalid;        // Memory request signal
logic        m_axi_rready;         // Memory ready to receive data
logic        m_axi_rvalid;         // Memory response valid signal
logic [31:0] memory_data;          // Data from memory

logic [63:0] modified_address;
integer empty_way;

logic [2:0] data_size_temp = 4; 

// State register update (sequential block)
always_ff @(posedge clock) begin
    if (reset) begin
        // Initialize state and relevant variables
        current_state <= IDLE_HIT;
        data_out <= 0;
        check_done <= 0;
        cache_hit <= 0;
        send_enable <= 0;
        m_axi_arvalid <= 0;
        m_axi_rready <= 0;
        buffer_pointer <= 0;
        burst_counter <= 0;

  	end else begin
        // Update current state and other variables as per state transitions
        current_state <= next_state;
        
    case (current_state)
        IDLE_HIT: begin

        end

        MISS_REQUEST: begin
            // Issue memory read request on a cache miss

        end

        MEMORY_WAIT: begin
            // Wait for memory response

        end

        MEMORY_ACCESS: begin
            if (m_axi_rvalid) begin
                buffer_array[buffer_pointer] <= m_axi_rdata[31:0];
                buffer_array[buffer_pointer + 1] <= m_axi_rdata[63:32];
                buffer_pointer <= buffer_pointer + 2;
                burst_counter <= burst_counter + 1;

                // Check if last burst transfer is reached
                if (m_axi_rlast && (burst_counter == 7)) begin
                    buffer_pointer <= 0;
                    burst_counter <= 0;
                end
            end
            data_retrieved <= data_retrieved_next;
        end

        STORE_DATA: begin
            // Store fetched data in cache

        end
    endcase
    end 
end

// Next State Logic (combinational block)
always_comb begin
    case (current_state)
        IDLE_HIT: begin
            // Transition to MISS_REQUEST if cache miss
            next_state = (!cache_hit && check_done) ? IDLE_HIT : MISS_REQUEST;
        end

        MISS_REQUEST: begin
            // Move to MEMORY_WAIT after initiating request
            next_state = (m_axi_arvalid && m_axi_arready) ? MEMORY_WAIT : MISS_REQUEST;
        end

        MEMORY_WAIT: begin
            // Transition to MEMORY_ACCESS when memory data is valid
            next_state = (m_axi_rready) ? MEMORY_ACCESS : MEMORY_WAIT;
        end

        MEMORY_ACCESS: begin
            // Transition to STORE_DATA after receiving memory data
            next_state = (data_retrieved) ? STORE_DATA : MEMORY_ACCESS;
        end

        STORE_DATA: begin
            // Return to IDLE_HIT after storing data
            next_state = (send_complete && !send_enable) ? IDLE_HIT : STORE_DATA;
        end

        default: next_state = IDLE_HIT;
    endcase
end

// Output Logic (combinational block)
always_comb begin
    // Initialize default values for control signals
    case (current_state)
        IDLE_HIT: begin
            if (read_enable && !check_done) begin
                set_index = address[block_offset_width +: set_index_width];
                tag = address[addr_width-1:addr_width-tag_width];
                block_offset = address[block_offset_width-1:0];

                for (int i = 0; i < ways; i++) begin
                    if (tags[set_index][i] == tag) begin  // Check for tag match
                        cache_hit = 1;   // Cache hit
                        // data_out = cache_data[set_index][i][block_offset * data_size_temp +: data_size_temp];
                    end
                end
                check_done = 1;
            end
            if (check_done && cache_hit) begin
                send_enable = 1;
            end 
            if (send_complete) begin
                check_done = 0;
                cache_hit = 0;
                data_out = 0;
                send_enable = 0;
            end

            if (write_enable && !check_done) begin
                set_index = address[block_offset_width +: set_index_width];
                tag = address[addr_width-1:addr_width-tag_width];
                block_offset = address[block_offset_width-1:0];

                for (int i = 0; i < ways; i++) begin
                    if (tags[set_index][i] == tag) begin  // Check for tag match
                        cache_hit = 1;   // Cache hit
                        // data_out = cache_data[set_index][i][block_offset * data_size_temp +: data_size_temp];
                    end
                end
                check_done = 1;
            end
            if (check_done && cache_hit) begin
                
            end 
            if (send_complete) begin
                check_done = 0;
                cache_hit = 0;
                send_enable = 0;
            end
            
        end

        MISS_REQUEST: begin
            modified_address = {address[addr_width-1:block_offset_width], {block_offset_width{1'b0}}};
            m_axi_arvalid = 1;
            m_axi_arlen = 7;
            m_axi_arsize = 3;
            m_axi_arburst = 2;
            m_axi_araddr = modified_address;
        end

        MEMORY_WAIT: begin
            m_axi_rready = 1;
            m_axi_arvalid = 0;
        end

        MEMORY_ACCESS: begin
            current_transfer_value = m_axi_rdata;
            if (m_axi_rlast && m_axi_rready) begin
                m_axi_rready = 0;
                data_retrieved_next = 1;
            end
        end

        STORE_DATA: begin
            set_index = modified_address[block_offset_width + set_index_width - 1 : block_offset_width];
            tag = modified_address[addr_width-1 : addr_width - tag_width];
            
            empty_way = -1;
            for (int w = 0; w < ways; w++) begin
                if (!valid_bits[set_index][w]) begin
                empty_way = w;
                break;
                end
            end

            if (empty_way != -1) begin
                // Write tag and data into cache
                tags[set_index][empty_way] = tag;
                cache_data[set_index][empty_way] = {buffer_array[15], buffer_array[14], buffer_array[13], buffer_array[12],
                                                    buffer_array[11], buffer_array[10], buffer_array[9], buffer_array[8],
                                                    buffer_array[7], buffer_array[6], buffer_array[5], buffer_array[4],
                                                    buffer_array[3], buffer_array[2], buffer_array[1], buffer_array[0]};
                valid_bits[set_index][empty_way] = 1;
            end
            // TODO: TEMPORARY FIX
            // data_out = cache_data[set_index][empty_way][block_offset * data_size_temp +: data_size_temp]; 
            send_enable = 1;
            if (send_complete) begin
                send_enable = 0;
                data_out = 0;
                check_done = 0;
            end
        end
    endcase
end

    // Internal signals and logic go here

endmodule
