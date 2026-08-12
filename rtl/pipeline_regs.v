// ============================================================
// pipeline_regs.v
// The four pipeline registers of VisionCore-RV's 5-stage
// pipeline. Each supports stall (hold) and flush (bubble).
// ============================================================

module if_id_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        flush,
    input  wire [31:0] pc_in,
    input  wire [31:0] pc_plus4_in,
    input  wire [31:0] instr_in,
    output reg  [31:0] pc_out,
    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] instr_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            pc_out       <= 32'b0;
            pc_plus4_out <= 32'b0;
            instr_out    <= 32'h00000013; // NOP (addi x0,x0,0)
        end else if (!stall) begin
            pc_out       <= pc_in;
            pc_plus4_out <= pc_plus4_in;
            instr_out    <= instr_in;
        end
        // else: hold current values (stall)
    end
endmodule


module id_ex_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,   // bubble in: hold-and-clear controls
    input  wire        flush,

    input  wire [31:0] pc_in, pc_plus4_in,
    input  wire [31:0] rs1_data_in, rs2_data_in, imm_in,
    input  wire [4:0]  rs1_addr_in, rs2_addr_in, rd_in,
    input  wire [2:0]  funct3_in,
    input  wire [6:0]  funct7_in,
    input  wire        reg_write_in, alu_src_in, mem_read_in, mem_write_in,
    input  wire        mem_to_reg_in, branch_in, jump_in, jalr_in, lui_in,
    input  wire        auipc_in, ai_op_in,
    input  wire [3:0]  alu_ctrl_in,

    output reg  [31:0] pc_out, pc_plus4_out,
    output reg  [31:0] rs1_data_out, rs2_data_out, imm_out,
    output reg  [4:0]  rs1_addr_out, rs2_addr_out, rd_out,
    output reg  [2:0]  funct3_out,
    output reg  [6:0]  funct7_out,
    output reg          reg_write_out, alu_src_out, mem_read_out, mem_write_out,
    output reg          mem_to_reg_out, branch_out, jump_out, jalr_out, lui_out,
    output reg          auipc_out, ai_op_out,
    output reg  [3:0]  alu_ctrl_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush || stall) begin
            // Bubble: zero every control signal, everything else don't-care-zero
            pc_out <= 32'b0; pc_plus4_out <= 32'b0;
            rs1_data_out <= 32'b0; rs2_data_out <= 32'b0; imm_out <= 32'b0;
            rs1_addr_out <= 5'b0; rs2_addr_out <= 5'b0; rd_out <= 5'b0;
            funct3_out <= 3'b0; funct7_out <= 7'b0;
            reg_write_out <= 1'b0; alu_src_out <= 1'b0; mem_read_out <= 1'b0;
            mem_write_out <= 1'b0; mem_to_reg_out <= 1'b0; branch_out <= 1'b0;
            jump_out <= 1'b0; jalr_out <= 1'b0; lui_out <= 1'b0; auipc_out <= 1'b0;
            ai_op_out <= 1'b0; alu_ctrl_out <= 4'b0;
        end else begin
            pc_out <= pc_in; pc_plus4_out <= pc_plus4_in;
            rs1_data_out <= rs1_data_in; rs2_data_out <= rs2_data_in; imm_out <= imm_in;
            rs1_addr_out <= rs1_addr_in; rs2_addr_out <= rs2_addr_in; rd_out <= rd_in;
            funct3_out <= funct3_in; funct7_out <= funct7_in;
            reg_write_out <= reg_write_in; alu_src_out <= alu_src_in; mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in; mem_to_reg_out <= mem_to_reg_in; branch_out <= branch_in;
            jump_out <= jump_in; jalr_out <= jalr_in; lui_out <= lui_in; auipc_out <= auipc_in;
            ai_op_out <= ai_op_in; alu_ctrl_out <= alu_ctrl_in;
        end
    end
endmodule


module ex_mem_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flush,

    input  wire [31:0] pc_plus4_in,
    input  wire [31:0] alu_result_in,
    input  wire [31:0] store_data_in,
    input  wire [31:0] imm_in,
    input  wire [4:0]  rd_in,
    input  wire         reg_write_in, mem_read_in, mem_write_in, mem_to_reg_in,
    input  wire         jump_in, lui_in, auipc_in, ai_op_in,
    input  wire [31:0] ai_result_in,

    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] alu_result_out,
    output reg  [31:0] store_data_out,
    output reg  [31:0] imm_out,
    output reg  [4:0]  rd_out,
    output reg          reg_write_out, mem_read_out, mem_write_out, mem_to_reg_out,
    output reg          jump_out, lui_out, auipc_out, ai_op_out,
    output reg  [31:0] ai_result_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            pc_plus4_out <= 32'b0; alu_result_out <= 32'b0; store_data_out <= 32'b0;
            imm_out <= 32'b0; rd_out <= 5'b0;
            reg_write_out <= 1'b0; mem_read_out <= 1'b0; mem_write_out <= 1'b0;
            mem_to_reg_out <= 1'b0; jump_out <= 1'b0; lui_out <= 1'b0; auipc_out <= 1'b0;
            ai_op_out <= 1'b0; ai_result_out <= 32'b0;
        end else begin
            pc_plus4_out <= pc_plus4_in; alu_result_out <= alu_result_in;
            store_data_out <= store_data_in; imm_out <= imm_in; rd_out <= rd_in;
            reg_write_out <= reg_write_in; mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in; mem_to_reg_out <= mem_to_reg_in;
            jump_out <= jump_in; lui_out <= lui_in; auipc_out <= auipc_in;
            ai_op_out <= ai_op_in; ai_result_out <= ai_result_in;
        end
    end
endmodule


module mem_wb_reg (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [31:0] pc_plus4_in,
    input  wire [31:0] alu_result_in,
    input  wire [31:0] mem_data_in,
    input  wire [31:0] imm_in,
    input  wire [4:0]  rd_in,
    input  wire         reg_write_in, mem_to_reg_in, jump_in, lui_in, auipc_in, ai_op_in,
    input  wire [31:0] ai_result_in,

    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] alu_result_out,
    output reg  [31:0] mem_data_out,
    output reg  [31:0] imm_out,
    output reg  [4:0]  rd_out,
    output reg          reg_write_out, mem_to_reg_out, jump_out, lui_out, auipc_out, ai_op_out,
    output reg  [31:0] ai_result_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_out <= 32'b0; alu_result_out <= 32'b0; mem_data_out <= 32'b0;
            imm_out <= 32'b0; rd_out <= 5'b0;
            reg_write_out <= 1'b0; mem_to_reg_out <= 1'b0; jump_out <= 1'b0;
            lui_out <= 1'b0; auipc_out <= 1'b0; ai_op_out <= 1'b0; ai_result_out <= 32'b0;
        end else begin
            pc_plus4_out <= pc_plus4_in; alu_result_out <= alu_result_in;
            mem_data_out <= mem_data_in; imm_out <= imm_in; rd_out <= rd_in;
            reg_write_out <= reg_write_in; mem_to_reg_out <= mem_to_reg_in;
            jump_out <= jump_in; lui_out <= lui_in; auipc_out <= auipc_in;
            ai_op_out <= ai_op_in; ai_result_out <= ai_result_in;
        end
    end
endmodule
