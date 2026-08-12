// ============================================================
// control_unit.v
// Decodes opcode/funct3/funct7 into control signals for the
// datapath: register write, ALU source/op, memory access,
// branch/jump behaviour, and AI-accelerator dispatch.
// ============================================================
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg        reg_write,
    output reg        alu_src,      // 0 = rs2, 1 = immediate
    output reg  [3:0] alu_ctrl,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,   // 0 = ALU result, 1 = memory data
    output reg        branch,
    output reg        jump,         // jal
    output reg        jalr,
    output reg        lui,
    output reg        auipc,
    output reg        ai_op         // 1 = dispatch to AI accelerator
);
    localparam OPC_RTYPE  = 7'b0110011;
    localparam OPC_ITYPE  = 7'b0010011;
    localparam OPC_LOAD   = 7'b0000011;
    localparam OPC_STORE  = 7'b0100011;
    localparam OPC_BRANCH = 7'b1100011;
    localparam OPC_JAL    = 7'b1101111;
    localparam OPC_JALR   = 7'b1100111;
    localparam OPC_LUI    = 7'b0110111;
    localparam OPC_AUIPC  = 7'b0010111;
    localparam OPC_CUSTOM = 7'b0001011;

    // ALU op codes (mirrors alu.v)
    localparam ALU_ADD  = 4'b0000, ALU_SUB  = 4'b0001, ALU_AND = 4'b0010,
               ALU_OR   = 4'b0011, ALU_XOR  = 4'b0100, ALU_SLL = 4'b0101,
               ALU_SRL  = 4'b0110, ALU_SRA  = 4'b0111, ALU_SLT = 4'b1000,
               ALU_SLTU = 4'b1001;

    always @(*) begin
        // Safe defaults
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        alu_ctrl   = ALU_ADD;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        lui        = 1'b0;
        auipc      = 1'b0;
        ai_op      = 1'b0;

        case (opcode)
            OPC_RTYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: alu_ctrl = ALU_ADD;
                    {7'b0100000, 3'b000}: alu_ctrl = ALU_SUB;
                    {7'b0000000, 3'b111}: alu_ctrl = ALU_AND;
                    {7'b0000000, 3'b110}: alu_ctrl = ALU_OR;
                    {7'b0000000, 3'b100}: alu_ctrl = ALU_XOR;
                    {7'b0000000, 3'b001}: alu_ctrl = ALU_SLL;
                    {7'b0000000, 3'b101}: alu_ctrl = ALU_SRL;
                    {7'b0100000, 3'b101}: alu_ctrl = ALU_SRA;
                    {7'b0000000, 3'b010}: alu_ctrl = ALU_SLT;
                    {7'b0000000, 3'b011}: alu_ctrl = ALU_SLTU;
                    default:              alu_ctrl = ALU_ADD;
                endcase
            end

            OPC_ITYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                case (funct3)
                    3'b000: alu_ctrl = ALU_ADD;               // addi
                    3'b111: alu_ctrl = ALU_AND;               // andi
                    3'b110: alu_ctrl = ALU_OR;                // ori
                    3'b100: alu_ctrl = ALU_XOR;               // xori
                    3'b010: alu_ctrl = ALU_SLT;               // slti
                    3'b011: alu_ctrl = ALU_SLTU;              // sltiu
                    3'b001: alu_ctrl = ALU_SLL;               // slli
                    3'b101: alu_ctrl = funct7[5] ? ALU_SRA : ALU_SRL; // srli/srai
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            OPC_LOAD: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_ctrl   = ALU_ADD;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
            end

            OPC_STORE: begin
                alu_src   = 1'b1;
                alu_ctrl  = ALU_ADD;
                mem_write = 1'b1;
            end

            OPC_BRANCH: begin
                alu_src  = 1'b0;
                alu_ctrl = ALU_SUB; // compare via subtraction, funct3 picks the condition
                branch   = 1'b1;
            end

            OPC_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
            end

            OPC_JALR: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = ALU_ADD;
                jump      = 1'b1;
                jalr      = 1'b1;
            end

            OPC_LUI: begin
                reg_write = 1'b1;
                lui       = 1'b1;
            end

            OPC_AUIPC: begin
                reg_write = 1'b1;
                auipc     = 1'b1;
            end

            OPC_CUSTOM: begin
                // custom-0 opcode space: AI accelerator instructions
                // funct3 selects the accelerator operation (see ai_accelerator.v)
                reg_write = 1'b1;
                ai_op     = 1'b1;
            end

            default: ; // NOP / unimplemented - all defaults already safe
        endcase
    end
endmodule
