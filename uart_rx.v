// UART Receiver
// 8-N-1 format: 8 data bits, no parity, 1 stop bit
// 16x oversampling — samples bit center to avoid edge glitches
// baud_tick: same 16x baud tick from baud_gen (shared with TX)

module uart_rx (
    input  wire       clk,
    input  wire       rst,
    input  wire       baud_tick,    // 16x baud tick
    input  wire       rx,           // serial input line
    output reg  [7:0] rx_data,      // received byte
    output reg        rx_done,      // pulses high for 1 clk when byte received
    output reg        rx_busy       // high while receiving
);
    // States
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [3:0] tick_cnt;   // counts 16 ticks per bit
    reg [2:0] bit_idx;    // which data bit we're receiving (0–7)
    reg [7:0] shift_reg;  // assembles the incoming byte

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            rx_data  <= 0;
            rx_done  <= 0;
            rx_busy  <= 0;
            tick_cnt <= 0;
            bit_idx  <= 0;
            shift_reg<= 0;
        end else begin
            rx_done <= 0;  // default: only high for 1 clock

            case (state)

                IDLE: begin
                    rx_busy <= 0;
                    if (!rx) begin
                        // Detected falling edge = start bit beginning
                        tick_cnt <= 0;
                        rx_busy  <= 1;
                        state    <= START;
                    end
                end

                START: begin
                    // Wait until middle of start bit (tick 7) to confirm it's real
                    if (baud_tick) begin
                        if (tick_cnt == 7) begin
                            if (!rx) begin
                                // Valid start bit confirmed
                                tick_cnt <= 0;
                                bit_idx  <= 0;
                                state    <= DATA;
                            end else begin
                                // Glitch — go back to idle
                                state <= IDLE;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1;
                        end
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        if (tick_cnt == 15) begin
                            // Sample at tick 15 = center of each data bit
                            tick_cnt             <= 0;
                            shift_reg[bit_idx]   <= rx;  // LSB first
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
                    if (baud_tick) begin
                        if (tick_cnt == 15) begin
                            tick_cnt <= 0;
                            if (rx) begin
                                // Valid stop bit — latch output
                                rx_data <= shift_reg;
                                rx_done <= 1;
                            end
                            // Whether valid or framing error, go back to IDLE
                            state <= IDLE;
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
