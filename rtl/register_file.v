// ============================================================
// register_file.v
// 32 x 32-bit register file. x0 is hardwired to 0.
// Two combinational read ports, one synchronous write port.
// ============================================================
module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);
    reg [31:0] regs [0:31];
    integer i;

    // Plain synchronous read: a write committed this same clock edge
    // is only visible on the *next* read, matching real register-file
    // hardware. In the pipeline, the same-cycle WB-write / ID-read
    // race this creates is resolved explicitly by a bypass mux in the
    // ID stage (see visioncore_pipeline.v) rather than here, because
    // building the bypass into this module creates a real combinational
    // loop for any single-cycle instruction whose source and
    // destination register are the same (e.g. "addi x9, x9, 1"): the
    // read would depend on rd_data, which depends on the ALU result,
    // which depends on the read.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'b0 : regs[rs2_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (we && rd_addr != 5'd0) begin
            regs[rd_addr] <= rd_data;
        end
    end
endmodule
