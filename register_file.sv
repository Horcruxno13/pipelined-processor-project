module register_file 
#(
  ADDR_WIDTH = 5,
  DATA_WIDTH = 64
)
(
    // Global Signals
    input clk,
    input reset,
    input [63:0] stackptr,

    // For Read
    input [ADDR_WIDTH-1:0] read_addr1,                       // Address of the first register to read
    input [ADDR_WIDTH-1:0] read_addr2,                       // Address of the second register to read
    //input rs2_valid,
    output signed [DATA_WIDTH-1:0] read_data1,                  // 64-bit data from the first read register
    output signed [DATA_WIDTH-1:0] read_data2,                   // 64-bit data from the second read register

    // For Write
    input write_enable,                                      // Write enable signal
    input [ADDR_WIDTH-1:0] write_addr,                 // Address of the register to write
    input signed [DATA_WIDTH-1:0] write_data,                       // 64-bit data to write into the register
    output write_complete,                             // Write Completed
    output [DATA_WIDTH-1:0] register [31:0]
);

    // Declare a register array of size 32. Each register 64 bit.

    // Sync write
    always_ff @(posedge clk) begin
        if (reset) begin
            // If reset, register is initiated as 0
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                if (i==2) begin
                    register[i] <= stackptr;
                end else begin
                    register[i] <= 64'b0;
                end
            end
            
        end 
        else if (write_enable) begin
            if (write_addr != 0) begin
                register[write_addr] <= write_data;
            end
            write_complete <= 1;
        end else begin
            write_complete <= 0;
        end
    end

    // Async Read
    always_comb begin
        read_data1 = register[read_addr1];
        //if (rs2_valid) begin
        read_data2 = register[read_addr2];
        //end else
            //read_data2 = 64'b0;
    end
endmodule