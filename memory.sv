module InstructionMemoryHandler (
    input  logic        clk,                // Clock signal
    input  logic        reset,            // Active-low reset
    input logic memory_enable,
    input  logic [63:0] pc_I_offset,         // Current PC value (64 bits)
    input  logic [63:0] reg_b_contents,         // Reg B contents
    input  logic [63:0] alu_data,         // ALU result data
    input  control_signals_struct control_signals, //todo = change the type      // Control Signals
    input logic mem_wb_pipeline_valid,


    output logic [63:0] loaded_data_out,
    output logic        memory_done,            // Ready signal indicating fetch completion


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

logic cache_request_ready;
logic cache_result_ready;



    /* decache instruction_cache (
        .clock(clk),
        .reset(reset),
        .read_enable(0), //input that fetcher send
        .write_enable(1),
        .address(alu_result), // input that fetcher sends
        .data_size(64'b0000000000000000000000000000000000000000000000000000000001000000),
        // .send_complete(0),//todo - fix this

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
        .data_out(instruction_out),
        .send_enable(cache_result_ready)
    ); */  

    always_comb begin
        if (reset) begin
            loaded_data_out = 0;
            memory_done = 0;
            cache_request_address = 64'b0;
            cache_request_ready = 0;
        end else begin
            if (memory_enable) begin
                if (control_signals.memory_access) begin
                    if (
                    !(memory_done && !mem_wb_pipeline_valid)  
                    // case where we are waiting for a latch - HL
                    
                    && 
                    
                    !(memory_done && mem_wb_pipeline_valid)  
                    // case where latch is done -HH

                    &&

                    !(!memory_done && mem_wb_pipeline_valid)  
                    // case where latch is done, but next stage (decoder)
                    // is yet to use the values - LH
                    
                    ) begin
                        cache_request_address = alu_data;
                        cache_request_ready = 1;
                    end


                    //WAITING MISS GAP - 1 - WAITING FOR CACHE TO BE DONE 

                    if (cache_result_ready) begin // CLK 2
                        cache_request_ready = 0;
                        memory_done = 1;
                    end
                    
                    //WAITING GAP - 2 - WAITING FOR VALUES TO BE LATCHED 
                    
                    if (mem_wb_pipeline_valid) begin  // clk 3
                        memory_done = 0;
                    //WAITING GAP - 3 starts because of this  - WAITING FOR THE PV TO BECOME ZERO ALSO 
                    end

                end else begin
                    loaded_data_out = 0;
                    memory_done = 1;
                end
        
            end else begin
                loaded_data_out = 0;
                memory_done = 0;
            end


            
        end
    end

endmodule