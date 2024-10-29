module cache #(
    parameter cache_line_size = 64,
    parameter cache_lines = 256,
    parameter sets = 64,
    parameter ways = 4,
    parameter addr_width = 64,
    parameter data_width = 32
)(
    input logic clock,
    input logic reset,
    input logic read_enable,                  // Signal to trigger a cache read
    input logic [63:0] address,               // Address to read from
    input logic [2:0] data_size,              // Size of data requested (in bytes)
    input logic send_complete,

    // AXI interface inputs for read transactions
    input logic m_axi_arready,                // Ready signal from AXI for read address
    input logic m_axi_rvalid,                 // Data valid signal from AXI read data channel
    input logic m_axi_rlast,                  // Last transfer of the read burst
    input logic [63:0] m_axi_rdata,           // Data returned from AXI read channel
    
    // AXI interface outputs for read transactions
    input logic m_axi_arvalid,                // Valid signal for read address
    input logic [63:0] m_axi_araddr,          // Read address output to AXI
    input logic [7:0] m_axi_arlen,            // Length of the burst (set to fetch full line)
    input logic [2:0] m_axi_arsize,           // Size of each data unit in the burst
    input logic m_axi_rready,                 // Ready to accept data from AXI

    // Data output and control signals
    output logic [63:0] data,                  // Data output to CPU
    output logic send_enable,                  // Indicates data is ready to send
    output logic read_complete                 // Indicates the read operation is complete
);

enum logic [3:0] {
    IDLE          = 4'b0000,
    CHECK_READ    = 4'b0001,
    HIT_SEND      = 4'b0010,
    MISS_MEMORY   = 4'b0011,
    MEMORY_WAIT   = 4'b0100,
    MEMORY_ACCESS = 4'b0101,
    STORE_SEND    = 4'b0110
} current_state, next_state;

// Derived parameters
localparam block_offset_width = $clog2(cache_line_size / data_width);
localparam set_index_width = $clog2(sets);
localparam tag_width = addr_width - set_index_width - block_offset_width;

// Cache storage arrays
logic [tag_width-1:0] tags [sets-1:0][ways-1:0];            // Array for storing tags
logic [cache_line_size-1:0] cache_data [sets-1:0][ways-1:0];      // Array for storing cache line data
logic valid_bits [sets-1:0][ways-1:0];                       // Valid bits array
// logic [ways-1:0] lru_counters [sets-1:0];                   // LRU counters for each set

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

// State transition logic - always_comb block
// This always_comb block will handle the next_state calculations for us.
always_comb begin
  case (current_state)
    IDLE: begin
      // Define conditions for transitioning out of IDLE
      next_state = (read_enable) ? CHECK_READ : IDLE;
    end

    CHECK_READ: begin
      // Define conditions for transitioning from CHECK_READ
      next_state = (cache_hit && check_done) ? HIT_SEND : CHECK_READ;
      next_state = (!cache_hit && check_done) ? MISS_MEMORY : CHECK_READ;
    end

    HIT_SEND: begin
      // Define conditions for transitioning from HIT_SEND
      next_state = (send_complete && !send_enable) ? IDLE : HIT_SEND;
    end

    MISS_MEMORY: begin
      // Define conditions for transitioning from MISS_MEMORY
      next_state = (m_axi_arvalid && m_axi_arready) ? MEMORY_WAIT : MISS_MEMORY;
    end

    MEMORY_WAIT: begin
      // Define conditions for transitioning from MISS_MEMORY
      next_state = (m_axi_rready) ? MEMORY_ACCESS : MEMORY_WAIT;
    end

    MEMORY_ACCESS: begin
      // Define conditions for transitioning from MEMORY_ACCESS
      next_state = (data_retrieved) ? STORE_SEND : MEMORY_ACCESS;
    end

    STORE_SEND: begin
      // Define conditions for transitioning from STORE_SEND
      next_state = (send_complete && !send_enable) ? IDLE : STORE_SEND;
    end

    default: begin
      next_state = IDLE;
    end
  endcase
end

// State and control signal updates - always_ff block
// This always_ff block handles resetting and updating states, signals, and variables.
always_ff @(posedge clock) begin
    if (reset) begin
    // Initialize state and relevant variables
        current_state <= IDLE;
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
		IDLE: begin
			if (reset) begin
			// Reset signals, prepare for new operation
				for (int i = 0; i < 16; i = i + 1) begin
					buffer_array[i] <= 32'b0;
				end
			end
		end

		CHECK_READ: begin
			// Prepare signals/variables for checking cache
			check_done <= check_done_next;
			data_out <= data_out_next;
			cache_hit <= cache_hit_next;
			send_enable <= send_enable_next;
		end

		HIT_SEND: begin
			// Set signals/variables for sending data on a cache hit
			send_enable <= send_enable_next;
		end

		MISS_MEMORY: begin
			// Handle signals/variables for memory access on cache miss
		end

		MEMORY_WAIT: begin
			// Manage signals/variables during memory wait
		end

		MEMORY_ACCESS: begin
			// Manage signals/variables during memory access
			if (m_axi_rvalid) begin
				// Store received data in buffer_array
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
		end

		STORE_SEND: begin
			// Handle signals/variables for storing or sending data
			send_enable <= send_enable_next;
			data_out <= data_out_next;
		end
    endcase
  end
end

// Control signals and state-related updates - always_comb block
// This is the always_comb block that manages signal changes at each state transition
always_comb begin
  // Initialize default values for control signals
  send_enable = 0;
  cache_data = 0;

  case (current_state)
    IDLE: begin
      // Set control signals for the IDLE state
    end

    CHECK_READ: begin
      // Set control signals for the CHECK_READ state
        set_index = address[block_offset_width +: set_index_width];
        tag = address[addr_width-1:addr_width-tag_width];
        block_offset = address[block_offset_width-1:0];

        for (int i = 0; i < ways; i++) begin
            if (tags[set_index][i] == tag) begin  // Check for tag match
                cache_hit_next = 1;   // Cache hit
                data_out_next = cache_data[set_index][i][block_offset * data_size +: data_size];
                send_enable_next = 1;
            end
            check_done_next = 1;
        end
    end

    HIT_SEND: begin
      // Set control signals for the HIT_SEND state
        if (send_complete) begin
            send_enable_next = 0;
        end
    end

    MISS_MEMORY: begin
      // Set control signals for the MISS_MEMORY state
        modified_address = {address[addr_width-1:block_offset_width], {block_offset_width{1'b0}}};
        m_axi_arvalid = 1;
        m_axi_arlen = 7;
        m_axi_arsize = 3;
        m_axi_arburst = 2;
        m_axi_araddr = modified_address;

    end

    MEMORY_WAIT: begin
      // Set control signals for the MEMORY_WAIT state
        m_axi_rready = 1;
        m_axi_arvalid = 0;
    end    

    MEMORY_ACCESS: begin
      // Set control signals for the MEMORY_ACCESS state
        current_transfer_value = m_axi_rdata;
        if (m_axi_rlast && m_axi_rready) begin
            m_axi_rready = 0;
            data_retrieved_next = 1;
        end
    end

    STORE_DATA: begin
      // Set control signals for the STORE_SEND state
        set_index = modified_address[block_offset_width + set_index_width - 1 : block_offset_width];
        tag = modified_address[addr_width-1 : addr_width - tag_width];
        int empty_way = -1;
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
        data_out_next = cache_data[set_index][i][block_offset * data_size +: data_size];
        send_enable_next = 1;
        if (send_complete) begin
            send_enable_next = 0;
        end
    end
  endcase
end


endmodule