`timescale 1ns/1ps

module tb_pipeline;
    reg clk;
    reg rst_n;

    visioncore_pipeline #(.INIT_FILE("sim/instructions.mem")) dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/pipeline.vcd");
        $dumpvars(0, tb_pipeline);

        clk   = 0;
        rst_n = 0;
        #12 rst_n = 1;

        // Pipeline needs extra cycles vs single-cycle for the same
        // program (stalls + branch flush penalties).
        #1000;

        $display("---- Final register state (pipelined) ----");
        $display("x3  (10+20)        = %0d (expect 30)", dut.u_rf.regs[3]);
        $display("x4  (20-10)        = %0d (expect 10)", dut.u_rf.regs[4]);
        $display("x8  (lw from mem0) = %0d (expect 30)", dut.u_rf.regs[8]);
        $display("x11 (sum 0..4)     = %0d (expect 10)", dut.u_rf.regs[11]);
        $display("x24 (AI dot prod)  = %0d (expect 39)", dut.u_rf.regs[24]);

        if (dut.u_rf.regs[3]  == 32'd30 &&
            dut.u_rf.regs[4]  == 32'd10 &&
            dut.u_rf.regs[8]  == 32'd30 &&
            dut.u_rf.regs[11] == 32'd10 &&
            dut.u_rf.regs[24] == 32'd39) begin
            $display("PASS: pipeline matches single-cycle reference");
        end else begin
            $display("FAIL: mismatch above");
        end

        $finish;
    end
endmodule
