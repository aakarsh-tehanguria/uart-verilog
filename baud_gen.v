// Baud Rate Generator
// Generates a tick at 16x the baud rate for oversampling in RX
// Parameters: CLK_FREQ = system clock frequency in Hz
//             BAUD_RATE = desired baud rate
// Default: 50MHz clock, 115200 baud

module baud_gen #(
    parameter CLK_FREQ  = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire rst,
    output reg  tick
);
    // Divider for 16x oversampling
    localparam DIVIDER = (CLK_FREQ / (BAUD_RATE * 16)) - 1;

    integer counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            tick    <= 0;
        end else begin
            if (counter == DIVIDER) begin
                counter <= 0;
                tick    <= 1;
            end else begin
                counter <= counter + 1;
                tick    <= 0;
            end
        end
    end
endmodule
