// ============================================================
// visioncore_single.v
// Single-cycle VisionCore-RV: every instruction completes in
// one clock. This is the simple reference implementation the
// pipelined version (visioncore_pipeline.v) is checked against.
// ============================================================
module visioncore_single #(
    parameter INIT_FILE = "instructions.mem"
) (
    input  wire clk,
    input  wire rst_n
);
    // ---------------- Program counter ----------------
    reg  [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] instr;

    instruction_memory #(.INIT_FILE(INIT_FILE)) u_imem (
        .addr(pc),
        .instr(instr)
    );

    // ---------------- Decode ----------------
    wire [6:0]  opcode;
    wire [4:0]  rd, rs1, rs2;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [31:0] imm;

    decoder u_dec (
        .instr(instr), .opcode(opcode), .rd(rd), .funct3(funct3),
        .rs1(rs1), .rs2(rs2), .funct7(funct7), .imm(imm)
    );

    // ---------------- Control ----------------
    wire reg_write, alu_src, mem_read, mem_write, mem_to_reg;
    wire branch, jump, jalr, lui, auipc, ai_op;
    wire [3:0] alu_ctrl;

    control_unit u_ctrl (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .alu_src(alu_src), .alu_ctrl(alu_ctrl),
        .mem_read(mem_read), .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jalr(jalr), .lui(lui), .auipc(auipc),
        .ai_op(ai_op)
    );

    // ---------------- Register file ----------------
    wire [31:0] rs1_data, rs2_data;
    reg  [31:0] rd_data;

    register_file u_rf (
        .clk(clk), .rst_n(rst_n), .we(reg_write),
        .rd_addr(rd), .rd_data(rd_data),
        .rs1_addr(rs1), .rs2_addr(rs2),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    // ---------------- ALU ----------------
    wire [31:0] alu_b = alu_src ? imm : rs2_data;
    wire [31:0] alu_result;
    wire        alu_zero;

    alu u_alu (
        .a(rs1_data), .b(alu_b), .alu_ctrl(alu_ctrl),
        .result(alu_result), .zero(alu_zero)
    );

    // ---------------- Branch resolution ----------------
    wire branch_taken;
    branch_unit u_bru (
        .funct3(funct3), .rs1_data(rs1_data), .rs2_data(rs2_data),
        .taken(branch_taken)
    );

    // ---------------- AI accelerator ----------------
    wire [31:0] ai_result;
    ai_accelerator u_ai (
        .clk(clk), .rst_n(rst_n), .en(ai_op), .funct3(funct3),
        .rs1_data(rs1_data), .rs2_data(rs2_data), .result(ai_result)
    );

    // ---------------- Data memory ----------------
    wire [31:0] mem_read_data;
    data_memory u_dmem (
        .clk(clk), .mem_read(mem_read), .mem_write(mem_write),
        .addr(alu_result), .write_data(rs2_data), .read_data(mem_read_data)
    );

    // ---------------- Writeback mux ----------------
    always @(*) begin
        if (ai_op)          rd_data = ai_result;
        else if (jump)      rd_data = pc + 32'd4;      // link address
        else if (lui)       rd_data = imm;
        else if (auipc)     rd_data = pc + imm;
        else if (mem_to_reg) rd_data = mem_read_data;
        else                 rd_data = alu_result;
    end

    // ---------------- Next PC ----------------
    wire take_branch = branch & branch_taken;
    wire [31:0] pc_plus4  = pc + 32'd4;
    wire [31:0] pc_branch = pc + imm;
    wire [31:0] pc_jalr   = (rs1_data + imm) & ~32'b1;

    assign pc_next = jalr             ? pc_jalr   :
                     jump              ? pc_branch :
                     take_branch       ? pc_branch :
                                         pc_plus4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 32'b0;
        else        pc <= pc_next;
    end
endmodule
