module decache #(
    parameter cache_line_size = 512,           // Size of each cache line in bytes
    parameter cache_lines = 4,                 // Total number of cache lines
    parameter sets = 2,                        // Number of sets in the cache
    parameter ways = 2,                        // Number of ways (associativity) in the cache
    parameter addr_width = 64,                 // Width of the address bus
    parameter data_width = 64                  // Width of the data bus TODO: CONFIRM THE MATH
)(
    input logic clock,
    input logic reset,
    input logic read_enable,                   // Signal to trigger a cache read
    input logic write_enable,                  // Signal to trigger a cache write
    input logic [63:0] address,                // Address to read/write from/to cache
    input logic [2:0] data_size,               // Size of data requested (in bytes)
    input logic [63:0] data_input,

    // AXI interface inputs for read transactions
    input logic m_axi_arready,                 // Ready signal from AXI for read address
    input logic m_axi_rvalid,                  // Data valid signal from AXI read data channel
    input logic m_axi_rlast,                   // Last transfer of the read burst
    input logic [63:0] m_axi_rdata,            // Data returned from AXI read channel

    // AXI interface outputs for read transactions
    output logic m_axi_arvalid,                // Valid signal for read address
    output logic [63:0] m_axi_araddr,          // Read address output to AXI
    output logic [7:0] m_axi_arlen,            // Length of the burst (fetches full line)
    output logic [2:0] m_axi_arsize,           // Size of each data unit in the burst
    output logic [1:0] m_axi_arburst,          // Burst type for read transaction
    output logic m_axi_rready,                 // Ready to accept data from AXI

    // AXI interface inputs for write transactions
    input logic m_axi_awready,                 // Ready signal from AXI for write address
    input logic m_axi_wready,                  // Ready signal from AXI for write data
    input logic m_axi_bvalid,                  // Write response valid from AXI
    input logic [1:0] m_axi_bresp,             // Write response from AXI

    // AXI interface outputs for write transactions
    output logic m_axi_awvalid,                // Valid signal for write address
    output logic [63:0] m_axi_awaddr,          // Write address output to AXI
    output logic [7:0] m_axi_awlen,            // Length of the burst for write
    output logic [2:0] m_axi_awsize,           // Size of each data unit in the burst for write
    output logic [1:0] m_axi_awburst,          // Burst type for write transaction
    output logic [63:0] m_axi_wdata,           // Data to be written to AXI
    output logic [7:0] m_axi_wstrb,            // Write strobe for data masking
    output logic m_axi_wvalid,                 // Valid signal for write data
    output logic m_axi_wlast,                  // Last transfer in the write burst
    output logic m_axi_bready,                 // Ready to accept write response

    // Data output and control signals
    output logic [63:0] data,                  // Data output to CPU
    output logic send_enable,                   // Indicates data is ready to send

    // AXI Control
    input logic instruction_cache_reading,
    output logic data_cache_reading
);


enum logic [3:0] {
    // Existing read operation states
    IDLE_HIT            = 4'b0000, // Idle and cache hit handling for reads
    MISS_REQUEST        = 4'b0001, // Handling read cache miss, initiating memory request
    MEMORY_WAIT         = 4'b0010, // Waiting for memory response after a miss
    MEMORY_ACCESS       = 4'b0011, // Accessing data as it's received from memory
    STORE_DATA          = 4'b0100, // Storing data into cache after a read miss
    SEND_DATA           = 4'b0101, // Sending data to the fetcher
    WRITE_MISS          = 4'b0110, // 
    WRITE_REQUEST       = 4'b0111, // Initiating memory request due to write miss
    WRITE_MEMORY_WAIT   = 4'b1000, // Waiting for acknowledgment from memory for write
    WRITE_MEMORY_ACCESS = 4'b1001, // Accessing or preparing data for the write operation
    WRITE_COMPLETE      = 4'b1010,  // Completing the write and updating cache state
    REPLACE_DATA        = 4'b1011
} current_state, next_state;

// Derived parameters
localparam block_offset_width = $clog2(cache_line_size / data_width) + 2;
localparam set_index_width = $clog2(sets);
localparam tag_width = addr_width - set_index_width - block_offset_width;

// Cache storage arrays
logic [tag_width-1:0] tags [sets-1:0][ways-1:0];            // Array for storing tags
logic [cache_line_size-1:0] cache_data [sets-1:0][ways-1:0];      // Array for storing cache line data
logic valid_bits [sets-1:0][ways-1:0];                       // Valid bits array
// DIRTY BITS
logic dirty_bits [sets-1:0][ways-1:0];

// internal logic bits
logic cache_hit;
logic check_done;
logic [set_index_width-1:0] set_index;
logic [set_index_width-1:0] set_index_next;

logic [tag_width-1:0] tag;
logic [tag_width-1:0] tag_next;

logic [block_offset_width-1:0] block_offset;
logic [data_width-1:0] data_out; 
logic [31:0] buffer_array [15:0];    // 16 instructions, each 32 bits
logic [3:0] buffer_pointer;          // Points to the next location in buffer_array
logic [3:0] burst_counter;           // Counts each burst (0-7)
logic [63:0] current_transfer_value;
logic data_retrieved;

// internal logic next bits
logic cache_hit_next;
logic check_done_next;
logic [data_width-1:0] data_out_next;
logic send_enable_next;
logic data_retrieved_next;
logic data_received_mem;
// Control signals and variables
// logic cache_hit;
// logic [31:0] data_out;
// logic [cache_line_size-1:0] cache_memory [sets-1:0][ways-1:0]; 
logic [7:0]  m_axi_arlen;          // Number of transfers in burst
logic        m_axi_arvalid;        // Memory request signal
logic        m_axi_rready;         // Memory ready to receive data
logic        m_axi_rvalid;         // Memory response valid signal
logic [31:0] memory_data;          // Data from memory

logic [63:0] modified_address;
integer empty_way;
integer empty_way_next;
integer replace_line_number;

logic write_data_done;
logic write_data_to_mem;
logic way_cleaned;
logic data_stored;
logic replace_line;
logic [$clog2(ways)-1:0] way_to_replace;
logic [$clog2(ways)-1:0] counter;
// logic [:0] data_size_temp = 32;
integer data_size_temp = 32; 
integer block_number;
integer i;
// State register update (sequential block)

always_ff @(posedge clock) begin
    if (reset)
        counter <= 0;              // Reset counter
    else if (replace_line)
        counter <= (counter + 1) % ways; // Increment counter cyclically
end

assign way_to_replace = counter;

always_ff @(posedge clock) begin
    if (reset) begin
        // Initialize state and relevant variables
        current_state <= IDLE_HIT;
        buffer_pointer <= 0;
        burst_counter <= 0;
        send_enable <= 0;
        data_received_mem <= 0;

    end else begin
        // Update current state and other variables as per state transitions
        current_state <= next_state;
        send_enable <= send_enable_next;
        data_retrieved <= data_retrieved_next;
        // set_index <= set_index_next;
        // empty_way <= empty_way_next;
        case (current_state)
            IDLE_HIT: begin
                // Idle state for cache hits (no actions yet)
                for (i = 0; i < 16; i = i + 1) begin
                    buffer_array[i] <= 32'b0;
                end
                data_received_mem <= 0;
                way_cleaned <= 0;
            end

            MISS_REQUEST: begin
                // Issue memory read request on a cache miss
            end

            MEMORY_WAIT: begin
                // Wait for memory response
            end

            MEMORY_ACCESS: begin
                if (m_axi_rvalid && m_axi_rready) begin
                    buffer_array[buffer_pointer] <= m_axi_rdata[31:0];
                    buffer_array[buffer_pointer + 1] <= m_axi_rdata[63:32];
                    buffer_pointer <= buffer_pointer + 2;
                    burst_counter <= burst_counter + 1;
                end
                    
                    // Check if last burst transfer is reached
                if (m_axi_rlast && (burst_counter == 8)) begin
                    buffer_pointer <= 0;
                    burst_counter <= 0;
                    data_received_mem <= 1;
                end
                data_retrieved <= data_retrieved_next;
            end

            STORE_DATA: begin
                // Store fetched data in cache
                if (empty_way_next != -1) begin
                    // Write tag and data into cache
                    tags[set_index_next][empty_way_next] <= tag;
                    cache_data[set_index_next][empty_way_next] <= {buffer_array[15], buffer_array[14], buffer_array[13], buffer_array[12],
                                                    buffer_array[11], buffer_array[10], buffer_array[9], buffer_array[8],
                                                    buffer_array[7], buffer_array[6], buffer_array[5], buffer_array[4],
                                                    buffer_array[3], buffer_array[2], buffer_array[1], buffer_array[0]};

                    valid_bits[set_index_next][empty_way_next] <= 1;
                    data_stored <= 1;
                end
            end

            SEND_DATA: begin
                // Send data to the fetcher or CPU
            end
            
            WRITE_MISS: begin
                // Issue memory write request on a cache miss (to be implemented)
            end
            // New states for write operations
            WRITE_REQUEST: begin
                // Issue memory write request on a cache miss (to be implemented)
            end

            WRITE_MEMORY_WAIT: begin
                // Wait for memory acknowledgment after issuing a write request (to be implemented)
            end

            WRITE_MEMORY_ACCESS: begin
                if (m_axi_wvalid && m_axi_wready) begin
                    m_axi_wdata <= cache_data[set_index][empty_way][(burst_counter * 64) +: 64];
                    m_axi_wstrb <= 8'hFF;
                    burst_counter <= burst_counter + 1;
                    
                    // Check if last burst transfer is reached
                    if (burst_counter == 7) begin
                        m_axi_wlast <= 1;
                    end
                end
            end

            WRITE_COMPLETE: begin
                if (m_axi_bvalid && !m_axi_bready) begin
                    m_axi_bready <= 1;
                    m_axi_wlast <= 0;
                    burst_counter <= 0; 
                end
                if (m_axi_bready && m_axi_bvalid) begin
                    m_axi_bready <= 0;  
                end 
            end
            
            REPLACE_DATA: begin
                if (dirty_bits[set_index][way_to_replace] == 1) begin
                    valid_bits[set_index][way_to_replace] <= 0;
                    write_data_to_mem <= 1;
                    way_cleaned <= 1;
                end

                else begin
                    valid_bits[set_index][way_to_replace] <= 0;
                    way_cleaned <= 1;
                end  
            end
        endcase
    end
end


// Next State Logic (combinational block)
always_comb begin
    case (current_state)
        IDLE_HIT: begin
            // Transition to MISS_REQUEST if cache miss
            next_state = (!cache_hit && check_done && !instruction_cache_reading) ? MISS_REQUEST : IDLE_HIT;
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
            next_state = (replace_line) ? REPLACE_DATA : STORE_DATA;
            next_state = (read_enable && data_stored) ? SEND_DATA : STORE_DATA;
            next_state = (write_enable && data_stored) ? WRITE_MISS : STORE_DATA;
        end

        SEND_DATA: begin
            next_state = (!read_enable && !send_enable) ? IDLE_HIT : SEND_DATA;
        end 

        WRITE_MISS: begin
            next_state = (!write_enable && !send_enable) ? IDLE_HIT : WRITE_MISS;
        end 
        // New states for write operations
        WRITE_REQUEST: begin
            // Transition to WRITE_MEMORY_WAIT after initiating write request
            next_state = (m_axi_awvalid && m_axi_awready) ? WRITE_MEMORY_WAIT : WRITE_REQUEST;
        end

        WRITE_MEMORY_WAIT: begin
            // Transition to WRITE_MEMORY_ACCESS when memory is ready for data
            next_state = (m_axi_wready) ? WRITE_MEMORY_ACCESS : WRITE_MEMORY_WAIT;
        end

        WRITE_MEMORY_ACCESS: begin
            // Transition to WRITE_DATA after staging data for memory
            next_state = (m_axi_wlast && !m_axi_wvalid) ? WRITE_COMPLETE : WRITE_MEMORY_ACCESS;
        end

        WRITE_COMPLETE: begin
            // Return to IDLE_HIT after completing write operation
            next_state = (write_data_done && !way_cleaned) ? IDLE_HIT : WRITE_COMPLETE;
            next_state = (write_data_done && way_cleaned) ? IDLE_HIT : STORE_DATA;
        end

        REPLACE_DATA: begin
            next_state = (!write_data_to_mem && way_cleaned) ? STORE_DATA : REPLACE_DATA;
            next_state = (write_data_to_mem && way_cleaned) ? WRITE_REQUEST : REPLACE_DATA;
        end
        default: next_state = IDLE_HIT;
    endcase
end

// Output Logic (combinational block)
always_comb begin
    // Initialize default values for control signals
    if (reset) begin
        data_out = 0;
        check_done = 0;
        cache_hit = 0;
        m_axi_arvalid = 0;
        m_axi_rready = 0;
        send_enable_next = 0;
        next_state = 0;
        replace_line = 0;
        data_cache_reading = 0;
        set_index = 0;
        tag = 0;
        block_offset = 0;
        empty_way_next = 0;
    end 
    else begin
        case (current_state)
            IDLE_HIT: begin
                m_axi_arvalid = 0;
                m_axi_rready = 0;
                data_retrieved_next = 0;
                replace_line = 0;
                data_cache_reading = 0;
                if (read_enable && !check_done) begin
                    set_index = address[block_offset_width +: set_index_width];
                    tag = address[addr_width-1:addr_width-tag_width];
                    block_offset = address[block_offset_width-1:2];
                    for (int i = 0; i < ways; i++) begin
                        if (tags[set_index][i] == tag && valid_bits[set_index][i] == 1) begin  // Check for tag match
                            cache_hit = 1;   // Cache hit
                            data_out = cache_data[set_index][i][(block_offset) * 64 +: 64]; //TODO: data size
                        end
                    end
                    check_done = 1;
                end

                if (check_done && cache_hit && read_enable) begin
                    send_enable_next = 1;
                end 

                if (!read_enable && !write_enable) begin
                    check_done = 0;
                    cache_hit = 0;
                    data_out = 0;
                    send_enable_next = 0;
                end

                if (write_enable) begin
                    set_index = address[block_offset_width +: set_index_width];
                    tag = address[addr_width-1:addr_width-tag_width];
                    block_offset = address[block_offset_width-1:2];

                    for (int i = 0; i < ways; i++) begin
                        if (tags[set_index][i] == tag && valid_bits[set_index][i] == 1) begin  // Check for tag match
                            cache_hit = 1;   // Cache hit
                            cache_data[set_index][i][(block_offset) * 64 +: 64] = data_input; //TODO: FIX THE INPUT LENGTH
                            dirty_bits[set_index][i] = 1;
                        end
                    end
                    check_done = 1;
                end 

                if (write_enable && check_done && cache_hit) begin
                    send_enable_next = 1;
                end 
                
            end 

            MISS_REQUEST: begin
                modified_address = {address[addr_width-1:block_offset_width], {block_offset_width{1'b0}}};
                m_axi_arvalid = 1;
                m_axi_arlen = 7;
                m_axi_arsize = 3;
                m_axi_arburst = 2;
                m_axi_araddr = modified_address;
                data_cache_reading = 1;
            end

            MEMORY_WAIT: begin
                m_axi_rready = 1;
                m_axi_arvalid = 0;
            end

            MEMORY_ACCESS: begin
                current_transfer_value = m_axi_rdata;
                if (data_received_mem) begin
                    // m_axi_rready = 0;
                    data_retrieved_next = 1;
                end
                empty_way_next = -1;
            end

            STORE_DATA: begin
                data_cache_reading = 0;
                set_index_next = modified_address[block_offset_width + set_index_width - 1 : block_offset_width];
                tag_next = modified_address[addr_width-1 : addr_width - tag_width];
                
                if (empty_way_next == -1) begin
                    for (int w = 0; w < ways; w++) begin
                        if (!valid_bits[set_index_next][w]) begin
                            empty_way_next = w;
                            break;
                        end
                    end
                end

                if (empty_way_next == -1) begin
                    replace_line = 1;
                end 
            end

            SEND_DATA: begin
                // TODO: TEMPORARY FIX
                data_out = cache_data[set_index][empty_way][(block_offset) * 64 +: 64]; 
                send_enable_next = 1;
                if (!read_enable) begin
                    send_enable_next = 0;
                    data_out = 0;
                    check_done = 0;
                end
            end 

            WRITE_MISS: begin
                cache_data[set_index][empty_way][(block_offset) * 64 +: 64] = data_input; // TODO: TEMPORARY FIX
                send_enable_next = 1;
                dirty_bits[set_index][empty_way] = 1;
                if (!write_enable) begin
                    send_enable_next = 0;
                    check_done = 0;
                end                 
            end 
            // New states for write operations
            WRITE_REQUEST: begin
                // Add actions for WRITE_REQUEST state if needed
                modified_address = {address[addr_width-1:block_offset_width], {block_offset_width{1'b0}}};
                m_axi_awvalid = 1;
                m_axi_awlen = 7;
                m_axi_awsize = 3;
                m_axi_awburst = 2;
                m_axi_awaddr = modified_address;
            end

            WRITE_MEMORY_WAIT: begin
                m_axi_awvalid = 0;            
            end

            WRITE_MEMORY_ACCESS: begin
                m_axi_wvalid = 1;
                if (burst_counter == 7 && m_axi_wlast) begin
                    m_axi_wvalid = 0;
                end 
            end

            WRITE_COMPLETE: begin
                if (!m_axi_wlast && !m_axi_bready) begin
                    write_data_done = 1;
                end 
            end

            REPLACE_DATA: begin
                replace_line = 0;
            end
            
            default: begin
                data_out = 0;
                check_done = 0;
                cache_hit = 0;
                m_axi_arvalid = 0;
                m_axi_rready = 0;
                send_enable_next = 0;
                next_state = 0;
            end
        endcase
    end 
end

endmodule