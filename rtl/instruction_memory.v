// ============================================================
// instruction_memory.v
// Word-addressed instruction ROM, initialized from a hex file.
// ============================================================
module instruction_memory #(
    parameter DEPTH = 256,
    parameter INIT_FILE = "instructions.mem"
) (
    input  wire [31:0] addr,   // byte address, word-aligned
    output wire [31:0] instr
);
    reg [31:0] mem [0:DEPTH-1];
    integer k;

    initial begin
        for (k = 0; k < DEPTH; k = k + 1)
            mem[k] = 32'h00000013; // NOP past end of program
        $readmemh(INIT_FILE, mem);
    end

    assign instr = mem[addr[31:2]];
endmodule
