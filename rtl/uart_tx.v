// ============================================================
// uart_tx.v
// Minimal UART transmitter (8N1). Not wired into the CPU
// datapath by default -- intended as the starting point for
// streaming register/result values out to a host PC for the
// "communicate with a PC through UART" goal in the project
// brief. Drive `send` for one cycle with `data` held stable;
// `busy` stays high until the byte is fully shifted out.
// ============================================================
module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       send,
    input  wire [7:0] data,
    output reg        tx,
    output reg        busy
);
    localparam integer CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam S_IDLE  = 2'd0,
               S_START = 2'd1,
               S_DATA  = 2'd2,
               S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            tx        <= 1'b1;   // idle line is high
            busy      <= 1'b0;
            clk_count <= 16'd0;
            bit_index <= 3'd0;
            shift_reg <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx <= 1'b1;
                    if (send) begin
                        shift_reg <= data;
                        busy      <= 1'b1;
                        clk_count <= 16'd0;
                        state     <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0; // start bit
                    if (clk_count == CYCLES_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        bit_index <= 3'd0;
                        state     <= S_DATA;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_DATA: begin
                    tx <= shift_reg[bit_index];
                    if (clk_count == CYCLES_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        if (bit_index == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                        end
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1; // stop bit
                    if (clk_count == CYCLES_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        busy      <= 1'b0;
                        state     <= S_IDLE;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
