// UART Transmitter
// 8-N-1 format: 8 data bits, no parity, 1 stop bit
// Transmits LSB first
// baud_tick: 16x baud rate tick from baud_gen

module uart_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire       baud_tick,   // 16x baud tick
    input  wire [7:0] tx_data,     // byte to transmit
    input  wire       tx_start,    // pulse high to begin transmission
    output reg        tx,          // serial output line
    output reg        tx_busy      // high while transmitting
);
    // States
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0]  state;
    reg [3:0]  tick_cnt;   // counts 16 ticks per bit
    reg [2:0]  bit_idx;    // which data bit we're sending (0–7)
    reg [7:0]  shift_reg;  // holds the byte being transmitted

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            tx       <= 1'b1;   // idle line is HIGH
            tx_busy  <= 1'b0;
            tick_cnt <= 0;
            bit_idx  <= 0;
            shift_reg<= 0;
        end else begin
            case (state)

                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tick_cnt  <= 0;
                        tx_busy   <= 1'b1;
                        state     <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;  // start bit
                    if (baud_tick) begin
                        if (tick_cnt == 15) begin
                            tick_cnt <= 0;
                            bit_idx  <= 0;
                            state    <= DATA;
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                DATA: begin
                    tx <= shift_reg[bit_idx];  // LSB first
                    if (baud_tick) begin
                        if (tick_cnt == 15) begin
                            tick_cnt <= 0;
                            if (bit_idx == 7) begin
                                state <= STOP;
                            end else begin
                                bit_idx <= bit_idx + 1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                STOP: begin
                    tx <= 1'b1;  // stop bit
                    if (baud_tick) begin
                        if (tick_cnt == 15) begin
                            tick_cnt <= 0;
                            state    <= IDLE;
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
