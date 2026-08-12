// ============================================================
// branch_unit.v
// Evaluates the branch condition from funct3 + operand compare.
// Kept separate from the ALU so the ALU's SUB result (used for
// beq/bne/blt/bge) and the raw operands (used for unsigned
// compares) are both available without extra ALU passes.
// ============================================================
module branch_unit (
    input  wire [2:0]  funct3,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    output reg          taken
);
    always @(*) begin
        case (funct3)
            3'b000: taken = (rs1_data == rs2_data);                     // beq
            3'b001: taken = (rs1_data != rs2_data);                     // bne
            3'b100: taken = ($signed(rs1_data) <  $signed(rs2_data));   // blt
            3'b101: taken = ($signed(rs1_data) >= $signed(rs2_data));   // bge
            3'b110: taken = (rs1_data <  rs2_data);                     // bltu
            3'b111: taken = (rs1_data >= rs2_data);                     // bgeu
            default: taken = 1'b0;
        endcase
    end
endmodule
