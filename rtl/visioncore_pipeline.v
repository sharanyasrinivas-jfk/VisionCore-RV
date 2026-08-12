// ============================================================
// visioncore_pipeline.v
// 5-stage pipelined VisionCore-RV: IF -> ID -> EX -> MEM -> WB
// Full operand forwarding (EX/MEM and MEM/WB into EX), a
// load-use stall, and branch/jump resolution in EX with a
// 2-cycle flush penalty (no prediction — simple resolve).
// ============================================================
module visioncore_pipeline #(
    parameter INIT_FILE = "instructions.mem"
) (
    input  wire clk,
    input  wire rst_n
);
    // =====================================================
    // IF stage
    // =====================================================
    reg  [31:0] pc;
    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] instr_if;

    instruction_memory #(.INIT_FILE(INIT_FILE)) u_imem (
        .addr(pc),
        .instr(instr_if)
    );

    wire        pc_stall;      // load-use: freeze PC + IF/ID
    wire        ex_take;       // branch/jump resolved in EX: flush + redirect
    wire [31:0] ex_target;

    wire [31:0] pc_next = ex_take ? ex_target : (pc_stall ? pc : pc_plus4);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 32'b0;
        else        pc <= pc_next;
    end

    wire [31:0] if_id_pc, if_id_pc_plus4, if_id_instr;

    if_id_reg u_if_id (
        .clk(clk), .rst_n(rst_n),
        .stall(pc_stall & ~ex_take),
        .flush(ex_take),
        .pc_in(pc), .pc_plus4_in(pc_plus4), .instr_in(instr_if),
        .pc_out(if_id_pc), .pc_plus4_out(if_id_pc_plus4), .instr_out(if_id_instr)
    );

    // =====================================================
    // ID stage
    // =====================================================
    wire [6:0]  id_opcode;
    wire [4:0]  id_rd, id_rs1, id_rs2;
    wire [2:0]  id_funct3;
    wire [6:0]  id_funct7;
    wire [31:0] id_imm;

    decoder u_dec (
        .instr(if_id_instr), .opcode(id_opcode), .rd(id_rd), .funct3(id_funct3),
        .rs1(id_rs1), .rs2(id_rs2), .funct7(id_funct7), .imm(id_imm)
    );

    wire id_reg_write, id_alu_src, id_mem_read, id_mem_write, id_mem_to_reg;
    wire id_branch, id_jump, id_jalr, id_lui, id_auipc, id_ai_op;
    wire [3:0] id_alu_ctrl;

    control_unit u_ctrl (
        .opcode(id_opcode), .funct3(id_funct3), .funct7(id_funct7),
        .reg_write(id_reg_write), .alu_src(id_alu_src), .alu_ctrl(id_alu_ctrl),
        .mem_read(id_mem_read), .mem_write(id_mem_write), .mem_to_reg(id_mem_to_reg),
        .branch(id_branch), .jump(id_jump), .jalr(id_jalr), .lui(id_lui),
        .auipc(id_auipc), .ai_op(id_ai_op)
    );

    wire [31:0] id_rs1_data_raw, id_rs2_data_raw;
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    register_file u_rf (
        .clk(clk), .rst_n(rst_n), .we(wb_reg_write),
        .rd_addr(wb_rd), .rd_data(wb_data),
        .rs1_addr(id_rs1), .rs2_addr(id_rs2),
        .rs1_data(id_rs1_data_raw), .rs2_data(id_rs2_data_raw)
    );

    // WB-to-ID bypass: the register file's own array read is one
    // cycle stale for a register WB is writing *this* cycle (see the
    // comment in register_file.v for why that bypass isn't built into
    // the module itself). This mux supplies the fresh value directly
    // from the WB stage instead - safe here because wb_data comes from
    // the MEM/WB pipeline register (a different, already-latched
    // instruction), not from the current ID-stage read, so it can't
    // form a combinational loop the way an in-module bypass would.
    wire [31:0] id_rs1_data = (wb_reg_write && wb_rd != 5'd0 && wb_rd == id_rs1) ? wb_data : id_rs1_data_raw;
    wire [31:0] id_rs2_data = (wb_reg_write && wb_rd != 5'd0 && wb_rd == id_rs2) ? wb_data : id_rs2_data_raw;

    // ---- Hazard detection (load-use) ----
    wire id_ex_mem_read_cur;
    wire [4:0] id_ex_rd_cur;

    hazard_unit u_hz (
        .id_ex_mem_read(id_ex_mem_read_cur),
        .id_ex_rd(id_ex_rd_cur),
        .if_id_rs1(id_rs1),
        .if_id_rs2(id_rs2),
        .stall(pc_stall)
    );

    // =====================================================
    // ID/EX pipeline register
    // =====================================================
    wire [31:0] ex_pc, ex_pc_plus4, ex_rs1_data, ex_rs2_data, ex_imm;
    wire [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd;
    wire [2:0]  ex_funct3;
    wire [6:0]  ex_funct7;
    wire        ex_reg_write, ex_alu_src, ex_mem_read, ex_mem_write, ex_mem_to_reg;
    wire        ex_branch, ex_jump, ex_jalr, ex_lui, ex_auipc, ex_ai_op;
    wire [3:0]  ex_alu_ctrl;

    id_ex_reg u_id_ex (
        .clk(clk), .rst_n(rst_n),
        .stall(pc_stall), .flush(ex_take),
        .pc_in(if_id_pc), .pc_plus4_in(if_id_pc_plus4),
        .rs1_data_in(id_rs1_data), .rs2_data_in(id_rs2_data), .imm_in(id_imm),
        .rs1_addr_in(id_rs1), .rs2_addr_in(id_rs2), .rd_in(id_rd),
        .funct3_in(id_funct3), .funct7_in(id_funct7),
        .reg_write_in(id_reg_write), .alu_src_in(id_alu_src),
        .mem_read_in(id_mem_read), .mem_write_in(id_mem_write),
        .mem_to_reg_in(id_mem_to_reg), .branch_in(id_branch), .jump_in(id_jump),
        .jalr_in(id_jalr), .lui_in(id_lui), .auipc_in(id_auipc), .ai_op_in(id_ai_op),
        .alu_ctrl_in(id_alu_ctrl),

        .pc_out(ex_pc), .pc_plus4_out(ex_pc_plus4),
        .rs1_data_out(ex_rs1_data), .rs2_data_out(ex_rs2_data), .imm_out(ex_imm),
        .rs1_addr_out(ex_rs1_addr), .rs2_addr_out(ex_rs2_addr), .rd_out(ex_rd),
        .funct3_out(ex_funct3), .funct7_out(ex_funct7),
        .reg_write_out(ex_reg_write), .alu_src_out(ex_alu_src),
        .mem_read_out(ex_mem_read), .mem_write_out(ex_mem_write),
        .mem_to_reg_out(ex_mem_to_reg), .branch_out(ex_branch), .jump_out(ex_jump),
        .jalr_out(ex_jalr), .lui_out(ex_lui), .auipc_out(ex_auipc), .ai_op_out(ex_ai_op),
        .alu_ctrl_out(ex_alu_ctrl)
    );

    assign id_ex_mem_read_cur = ex_mem_read;
    assign id_ex_rd_cur       = ex_rd;

    // =====================================================
    // EX stage
    // =====================================================
    wire [4:0] mem_rd_fwd;
    wire        mem_reg_write_fwd;
    wire [4:0] wb_rd_fwd;
    wire        wb_reg_write_fwd;
    wire [1:0] fwd_a_sel, fwd_b_sel;

    forwarding_unit u_fwd (
        .id_ex_rs1(ex_rs1_addr), .id_ex_rs2(ex_rs2_addr),
        .ex_mem_rd(mem_rd_fwd), .ex_mem_reg_write(mem_reg_write_fwd),
        .mem_wb_rd(wb_rd_fwd), .mem_wb_reg_write(wb_reg_write_fwd),
        .fwd_a_sel(fwd_a_sel), .fwd_b_sel(fwd_b_sel)
    );

    wire [31:0] ex_mem_wb_value;  // value produced by instruction currently in EX/MEM
    wire [31:0] mem_wb_wb_value;  // value produced by instruction currently in MEM/WB

    wire [31:0] fwd_rs1 = (fwd_a_sel == 2'b01) ? ex_mem_wb_value :
                          (fwd_a_sel == 2'b10) ? mem_wb_wb_value :
                                                  ex_rs1_data;
    wire [31:0] fwd_rs2 = (fwd_b_sel == 2'b01) ? ex_mem_wb_value :
                          (fwd_b_sel == 2'b10) ? mem_wb_wb_value :
                                                  ex_rs2_data;

    wire [31:0] alu_a = ex_lui   ? 32'b0  :
                        ex_auipc ? ex_pc  :
                                   fwd_rs1;
    wire [31:0] alu_b = (ex_lui || ex_auipc) ? ex_imm :
                        ex_alu_src            ? ex_imm :
                                                 fwd_rs2;

    wire [31:0] alu_result;
    wire        alu_zero;

    alu u_alu (
        .a(alu_a), .b(alu_b), .alu_ctrl(ex_alu_ctrl),
        .result(alu_result), .zero(alu_zero)
    );

    wire branch_taken;
    branch_unit u_bru (
        .funct3(ex_funct3), .rs1_data(fwd_rs1), .rs2_data(fwd_rs2),
        .taken(branch_taken)
    );

    wire [31:0] ai_result;
    ai_accelerator u_ai (
        .clk(clk), .rst_n(rst_n), .en(ex_ai_op), .funct3(ex_funct3),
        .rs1_data(fwd_rs1), .rs2_data(fwd_rs2), .result(ai_result)
    );

    wire [31:0] jalr_target  = (fwd_rs1 + ex_imm) & ~32'b1;
    wire [31:0] branch_jump_target = ex_pc + ex_imm;

    assign ex_take   = (ex_branch & branch_taken) | ex_jump;
    assign ex_target = ex_jalr ? jalr_target : branch_jump_target;

    // =====================================================
    // EX/MEM pipeline register
    // =====================================================
    wire [31:0] mem_pc_plus4, mem_alu_result, mem_store_data, mem_imm;
    wire [4:0]  mem_rd;
    wire        mem_reg_write, mem_read, mem_write, mem_mem_to_reg;
    wire        mem_jump, mem_lui, mem_auipc, mem_ai_op;
    wire [31:0] mem_ai_result;

    ex_mem_reg u_ex_mem (
        .clk(clk), .rst_n(rst_n), .flush(1'b0),
        .pc_plus4_in(ex_pc_plus4), .alu_result_in(alu_result), .store_data_in(fwd_rs2),
        .imm_in(ex_imm), .rd_in(ex_rd),
        .reg_write_in(ex_reg_write), .mem_read_in(ex_mem_read), .mem_write_in(ex_mem_write),
        .mem_to_reg_in(ex_mem_to_reg), .jump_in(ex_jump), .lui_in(ex_lui),
        .auipc_in(ex_auipc), .ai_op_in(ex_ai_op), .ai_result_in(ai_result),

        .pc_plus4_out(mem_pc_plus4), .alu_result_out(mem_alu_result),
        .store_data_out(mem_store_data), .imm_out(mem_imm), .rd_out(mem_rd),
        .reg_write_out(mem_reg_write), .mem_read_out(mem_read), .mem_write_out(mem_write),
        .mem_to_reg_out(mem_mem_to_reg), .jump_out(mem_jump), .lui_out(mem_lui),
        .auipc_out(mem_auipc), .ai_op_out(mem_ai_op), .ai_result_out(mem_ai_result)
    );

    assign mem_rd_fwd        = mem_rd;
    assign mem_reg_write_fwd = mem_reg_write;
    assign ex_mem_wb_value   = mem_ai_op ? mem_ai_result :
                                mem_jump  ? mem_pc_plus4  :
                                            mem_alu_result;

    // =====================================================
    // MEM stage
    // =====================================================
    wire [31:0] dmem_read_data;

    data_memory u_dmem (
        .clk(clk), .mem_read(mem_read), .mem_write(mem_write),
        .addr(mem_alu_result), .write_data(mem_store_data), .read_data(dmem_read_data)
    );

    // =====================================================
    // MEM/WB pipeline register
    // =====================================================
    wire [31:0] wbs_pc_plus4, wbs_alu_result, wbs_mem_data, wbs_imm;
    wire [4:0]  wbs_rd;
    wire        wbs_reg_write, wbs_mem_to_reg, wbs_jump, wbs_lui, wbs_auipc, wbs_ai_op;
    wire [31:0] wbs_ai_result;

    mem_wb_reg u_mem_wb (
        .clk(clk), .rst_n(rst_n),
        .pc_plus4_in(mem_pc_plus4), .alu_result_in(mem_alu_result), .mem_data_in(dmem_read_data),
        .imm_in(mem_imm), .rd_in(mem_rd),
        .reg_write_in(mem_reg_write), .mem_to_reg_in(mem_mem_to_reg), .jump_in(mem_jump),
        .lui_in(mem_lui), .auipc_in(mem_auipc), .ai_op_in(mem_ai_op), .ai_result_in(mem_ai_result),

        .pc_plus4_out(wbs_pc_plus4), .alu_result_out(wbs_alu_result), .mem_data_out(wbs_mem_data),
        .imm_out(wbs_imm), .rd_out(wbs_rd),
        .reg_write_out(wbs_reg_write), .mem_to_reg_out(wbs_mem_to_reg), .jump_out(wbs_jump),
        .lui_out(wbs_lui), .auipc_out(wbs_auipc), .ai_op_out(wbs_ai_op), .ai_result_out(wbs_ai_result)
    );

    assign wb_rd_fwd        = wbs_rd;
    assign wb_reg_write_fwd = wbs_reg_write;

    // =====================================================
    // WB stage
    // =====================================================
    assign mem_wb_wb_value = wbs_ai_op    ? wbs_ai_result :
                              wbs_jump     ? wbs_pc_plus4  :
                              wbs_mem_to_reg ? wbs_mem_data :
                                               wbs_alu_result;

    assign wb_data      = mem_wb_wb_value;
    assign wb_reg_write = wbs_reg_write;
    assign wb_rd        = wbs_rd;

endmodule
