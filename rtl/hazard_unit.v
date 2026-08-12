// ============================================================
// hazard_unit.v
// Detects the one hazard forwarding cannot fix: load-use, where
// the instruction right after a load needs the loaded value
// before it has left memory stage. Stalls IF and ID for one
// cycle and bubbles ID/EX.
// ============================================================
module hazard_unit (
    input  wire        id_ex_mem_read,
    input  wire [4:0]  id_ex_rd,
    input  wire [4:0]  if_id_rs1,
    input  wire [4:0]  if_id_rs2,

    output wire         stall
);
    assign stall = id_ex_mem_read &&
                   (id_ex_rd != 5'd0) &&
                   ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));
endmodule
