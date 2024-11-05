module InstructionMemoryHandler (
    input  logic        clk,                // Clock signal
    input  logic        reset,            // Active-low reset
    input  logic [63:0] pc_I_offset,         // Current PC value (64 bits)
    input  logic [63:0] reg_b_contents,         // Reg B contents
    input  logic [63:0] alu_data,         // ALU result data
    input  control_signals_struct control_signals, //todo = change the type      // Control Signals
    input logic memory_enable,
    output logic [63:0] loaded_data_out,
    output logic        memory_done               // Ready signal indicating fetch completion
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

/*     cache data_cache (
        .clock(clk),
        .reset(reset),
        .address(alu_result),                  // if alu then this
        .write_data(reg_b_contents),
        .read_enable(null), //input that fetcher send
        .write_enable(1),
        .byte_enable(null),  // data size
        .read_data(loaded_data_out),
        .cache_result(null),
        .data_valid(null), //output that fetcher gets
        .write_complete(cache_write_complete)
    );  */


    cache instruction_cache (
        .clock(clk),
        .reset(reset),
        .read_enable(0), //input that fetcher send
        .write_enable(1),
        .address(alu_result), // input that fetcher sends
        .data_size(64'b0000000000000000000000000000000000000000000000000000000001000000)
        .send_complete(0)//todo - fix this

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

    always_comb begin
        if (reset) begin
            loaded_data_out = 0;
            memory_done = 0;
        end
        else if (control_signals.memory_access) begin
            // some code
            cache_request_ready = 1;
            if (cache_result_ready) begin
                memory_done = 1;
            end else begin
                memory_done = 0;
            end
        end else begin
            loaded_data_out = 0;
            memory_done = 1;
        end
    end

endmodule