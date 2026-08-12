// ============================================================
// alu.v
// Arithmetic Logic Unit for VisionCore-RV.
// ALU control codes are decoded by control_unit.v
// ============================================================
`define ALU_ADD  4'b0000
`define ALU_SUB  4'b0001
`define ALU_AND  4'b0010
`define ALU_OR   4'b0011
`define ALU_XOR  4'b0100
`define ALU_SLL  4'b0101
`define ALU_SRL  4'b0110
`define ALU_SRA  4'b0111
`define ALU_SLT  4'b1000
`define ALU_SLTU 4'b1001

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire         zero
);
    wire [31:0] add_sub_result;
    wire        cout, overflow;

    cla_adder_32bit u_adder (
        .a(a),
        .b(b),
        .sub(alu_ctrl == `ALU_SUB || alu_ctrl == `ALU_SLT || alu_ctrl == `ALU_SLTU),
        .sum(add_sub_result),
        .cout(cout),
        .overflow(overflow)
    );

    wire signed_lt  = overflow ^ add_sub_result[31]; // a < b signed
    wire unsigned_lt = ~cout;                        // a < b unsigned (sub via CLA)

    always @(*) begin
        case (alu_ctrl)
            `ALU_ADD:  result = add_sub_result;
            `ALU_SUB:  result = add_sub_result;
            `ALU_AND:  result = a & b;
            `ALU_OR:   result = a | b;
            `ALU_XOR:  result = a ^ b;
            `ALU_SLL:  result = a << b[4:0];
            `ALU_SRL:  result = a >> b[4:0];
            `ALU_SRA:  result = $signed(a) >>> b[4:0];
            `ALU_SLT:  result = {31'b0, signed_lt};
            `ALU_SLTU: result = {31'b0, unsigned_lt};
            default:   result = 32'b0;
        endcase
    end

    assign zero = (result == 32'b0);
endmodule
