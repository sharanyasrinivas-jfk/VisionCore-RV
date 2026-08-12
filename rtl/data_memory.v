// ============================================================
// data_memory.v
// Word-addressed data RAM for lw / sw.
// ============================================================
module data_memory #(
    parameter DEPTH = 256
) (
    input  wire        clk,
    input  wire         mem_read,
    input  wire         mem_write,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);
    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'b0;
    end

    assign read_data = mem_read ? mem[addr[31:2]] : 32'b0;

    always @(posedge clk) begin
        if (mem_write)
            mem[addr[31:2]] <= write_data;
    end
endmodule
