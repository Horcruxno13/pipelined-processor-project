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
);

    cache data_cache (
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