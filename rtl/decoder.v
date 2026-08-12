// ============================================================
// decoder.v
// Splits a 32-bit instruction into its fields and generates
// the sign-extended immediate for every instruction format.
// ============================================================
module decoder (
    input  wire [31:0] instr,
    output wire [6:0]  opcode,
    output wire [4:0]  rd,
    output wire [2:0]  funct3,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [6:0]  funct7,
    output reg  [31:0] imm
);
    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // Opcode map (RV32I subset implemented by VisionCore-RV)
    localparam OPC_RTYPE  = 7'b0110011; // add sub and or xor sll srl sra slt sltu
    localparam OPC_ITYPE  = 7'b0010011; // addi andi ori xori slli srli srai slti sltiu
    localparam OPC_LOAD   = 7'b0000011; // lw
    localparam OPC_STORE  = 7'b0100011; // sw
    localparam OPC_BRANCH = 7'b1100011; // beq bne blt bge bltu bgeu
    localparam OPC_JAL    = 7'b1101111;
    localparam OPC_JALR   = 7'b1100111;
    localparam OPC_LUI    = 7'b0110111;
    localparam OPC_AUIPC  = 7'b0010111;
    localparam OPC_CUSTOM = 7'b0001011; // custom-0: AI accelerator ops

    always @(*) begin
        case (opcode)
            OPC_ITYPE, OPC_LOAD, OPC_JALR, OPC_CUSTOM:
                imm = {{20{instr[31]}}, instr[31:20]};
            OPC_STORE:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            OPC_BRANCH:
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            OPC_JAL:
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            OPC_LUI, OPC_AUIPC:
                imm = {instr[31:12], 12'b0};
            default:
                imm = 32'b0;
        endcase
    end
endmodule
