// ============================================================
// ai_accelerator.v
// A small MAC-based accelerator reachable through the custom-0
// opcode (0001011). It exposes three operations selected by
// funct3, matching the "single custom instruction replaces a
// multiply-add loop" idea from the project brief:
//
//   funct3 = 000  AI_LOAD   rd = 0, stage rs1 into operand A queue
//   funct3 = 001  AI_MAC    acc += rs1 * rs2          (no writeback)
//   funct3 = 010  AI_READ   rd  = acc, then acc clears
//
// This keeps the accelerator's register-level interface identical
// to a normal R-type instruction (rs1, rs2, rd) so it slots into
// the existing decode/writeback hardware with only a mux added
// at the writeback stage (see visioncore_top.v).
// ============================================================
module ai_accelerator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire         en,        // ai_op from control unit
    input  wire [2:0]  funct3,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    output reg  [31:0] result
);
    localparam AI_LOAD = 3'b000;
    localparam AI_MAC  = 3'b001;
    localparam AI_READ = 3'b010;

    reg signed [63:0] accumulator;

    // Combinational result presented to the writeback mux.
    always @(*) begin
        case (funct3)
            AI_READ: result = accumulator[31:0];
            default: result = 32'b0;
        endcase
    end

    // Accumulator update: MAC is the only op that changes state,
    // READ clears the accumulator after it has been captured.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 64'sd0;
        end else if (en) begin
            case (funct3)
                AI_MAC:  accumulator <= accumulator +
                                        ($signed(rs1_data) * $signed(rs2_data));
                AI_READ: accumulator <= 64'sd0;
                default: accumulator <= accumulator;
            endcase
        end
    end
endmodule
