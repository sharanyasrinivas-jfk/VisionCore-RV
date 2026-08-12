// ============================================================
// forwarding_unit.v
// Selects, per ALU operand, whether to use the value straight
// out of the register file (ID/EX) or a result still in flight
// in EX/MEM or MEM/WB. EX/MEM (one instruction ahead) always
// wins over MEM/WB (two instructions ahead) when both match.
//
// fwd_sel encoding: 2'b00 = ID/EX value, 2'b01 = forward from
// EX/MEM, 2'b10 = forward from MEM/WB.
// ============================================================
module forwarding_unit (
    input  wire [4:0] id_ex_rs1,
    input  wire [4:0] id_ex_rs2,

    input  wire [4:0] ex_mem_rd,
    input  wire        ex_mem_reg_write,

    input  wire [4:0] mem_wb_rd,
    input  wire        mem_wb_reg_write,

    output reg  [1:0] fwd_a_sel,
    output reg  [1:0] fwd_b_sel
);
    always @(*) begin
        // Operand A (rs1)
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            fwd_a_sel = 2'b01;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            fwd_a_sel = 2'b10;
        else
            fwd_a_sel = 2'b00;

        // Operand B (rs2)
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            fwd_b_sel = 2'b01;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            fwd_b_sel = 2'b10;
        else
            fwd_b_sel = 2'b00;
    end
endmodule
