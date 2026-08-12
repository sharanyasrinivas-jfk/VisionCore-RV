// ============================================================
// cla_adder.v
// 32-bit Carry Look-Ahead Adder, built from cascaded 4-bit CLA
// blocks. Used by the ALU for ADD/SUB and by branch/PC logic.
// ============================================================

module cla_block_4bit (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire       cout
);
    wire [3:0] g, p;      // generate, propagate
    wire [3:0] c;         // internal carries c[0] = carry into bit0

    assign g = a & b;
    assign p = a ^ b;

    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c[0]);

    assign sum  = p ^ c;
    assign cout = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) |
                  (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & c[0]);
endmodule

module cla_adder_32bit (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        sub,        // 1 = perform a - b
    output wire [31:0] sum,
    output wire        cout,
    output wire        overflow
);
    // For subtraction, invert b and set carry-in of the first block to 1
    // (two's complement: a - b = a + ~b + 1)
    wire [31:0] b_mux = sub ? ~b : b;
    wire [7:0]  c;  // carries out of each nibble; c[0] is carry into bit 4

    cla_block_4bit blk0 (.a(a[3:0]),   .b(b_mux[3:0]),   .cin(sub),  .sum(sum[3:0]),   .cout(c[0]));
    cla_block_4bit blk1 (.a(a[7:4]),   .b(b_mux[7:4]),   .cin(c[0]), .sum(sum[7:4]),   .cout(c[1]));
    cla_block_4bit blk2 (.a(a[11:8]),  .b(b_mux[11:8]),  .cin(c[1]), .sum(sum[11:8]),  .cout(c[2]));
    cla_block_4bit blk3 (.a(a[15:12]), .b(b_mux[15:12]), .cin(c[2]), .sum(sum[15:12]), .cout(c[3]));
    cla_block_4bit blk4 (.a(a[19:16]), .b(b_mux[19:16]), .cin(c[3]), .sum(sum[19:16]), .cout(c[4]));
    cla_block_4bit blk5 (.a(a[23:20]), .b(b_mux[23:20]), .cin(c[4]), .sum(sum[23:20]), .cout(c[5]));
    cla_block_4bit blk6 (.a(a[27:24]), .b(b_mux[27:24]), .cin(c[5]), .sum(sum[27:24]), .cout(c[6]));
    cla_block_4bit blk7 (.a(a[31:28]), .b(b_mux[31:28]), .cin(c[6]), .sum(sum[31:28]), .cout(c[7]));

    assign cout     = c[7];
    // Signed overflow: carry into MSB differs from carry out of MSB
    assign overflow = c[6] ^ c[7];
endmodule
