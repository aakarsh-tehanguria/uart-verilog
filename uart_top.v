// UART Top-Level
// Wires together baud_gen, uart_tx, and uart_rx
// TX output is connected internally to RX input for loopback testing

module uart_top #(
    parameter CLK_FREQ  = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output wire [7:0] rx_data,
    output wire       rx_done,
    output wire       tx_busy,
    output wire       rx_busy,
    output wire       tx_line    // expose TX line (useful for external connection / FPGA pin)
);
    wire baud_tick;
    wire tx_serial;

    // Baud rate generator — shared 16x tick for TX and RX
    baud_gen #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_baud (
        .clk (clk),
        .rst (rst),
        .tick(baud_tick)
    );

    // Transmitter
    uart_tx u_tx (
        .clk      (clk),
        .rst      (rst),
        .baud_tick(baud_tick),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .tx       (tx_serial),
        .tx_busy  (tx_busy)
    );

    // Receiver — loopback: RX input = TX output
    uart_rx u_rx (
        .clk      (clk),
        .rst      (rst),
        .baud_tick(baud_tick),
        .rx       (tx_serial),
        .rx_data  (rx_data),
        .rx_done  (rx_done),
        .rx_busy  (rx_busy)
    );

    assign tx_line = tx_serial;

endmodule
