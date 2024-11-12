`include "recache.sv"

module InstructionFetcher (
    input  logic        clk,                // Clock signal
    input  logic        reset,            // Active-low reset 
    input  logic        fetch_enable,
    input  logic [63:0] pc_current,         // Current PC value (64 bits)
    input  logic [63:0] target_address,     // Target address for branches/jumps (64 bits)
    input  logic        select_target,      // Control signal for address selection
    input  logic if_id_pipeline_valid,



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
    output logic [1:0] m_axi_arburst,

    output logic m_axi_rready                // Ready to accept data from AXI
);

// Internal wires and registers (if needed)
logic [63:0] cache_request_address;
logic cache_request_ready;
logic [63:0] cache_result;
logic cache_miss_occurred;


    recache instruction_cache (
        .clock(clk),
        .reset(reset),
        .read_enable(cache_request_ready), //input that fetcher send
        .write_enable(0),
        .address(cache_request_address), // input that fetcher sends
        .data_size(64'b0000000000000000000000000000000000000000000000000000000001000000),
        .send_complete(0),

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
        .data(instruction_out),
        .send_enable(cache_result_ready)
    );  


     

// No states
always_comb begin
    if (reset) begin
        fetcher_done = 0;
        cache_request_address  = 64'b0;
        cache_request_ready = 0;
    end else begin
        if (fetch_enable) begin // clk 1
            if (
                !(fetcher_done && !if_id_pipeline_valid)  
                // case where we are waiting for a latch - HL
                
                && 
                
                !(fetcher_done && if_id_pipeline_valid)  
                // case where latch is done -HH

                &&

                !(!fetcher_done && if_id_pipeline_valid)  
                // case where latch is done, but next stage (decoder) is yet to use the values - LH
                
                
                
                ) begin
                cache_request_address = select_target ? target_address : pc_current;  // todo: relative vs absolute
                cache_request_ready = 1;
            end

            //WAITING MISS GAP - 1 - WAITING FOR CACHE TO BE DONE 

            if (cache_result_ready) begin // CLK 2
                cache_request_ready = 0;
                fetcher_done = 1;
            end
            
            //WAITING GAP - 2 - WAITING FOR VALUES TO BE LATCHED 
            
            if (if_id_pipeline_valid) begin  // clk 3 //TODO - MAKE SURE THIS ALSO DOESN'T KEEP RUNNING
                fetcher_done = 0;
                //pc_current = pc_current + 4; //TODO - MOVE THIS OUT
            //WAITING GAP - 3 starts because of this  - WAITING FOR THE PV TO BECOME ZERO ALSO 
            end
            //set next pc by incrementing it
        end else begin // in next clk
            cache_request_ready = 0;
            fetcher_done = 0;
        end
    end
end


endmodule