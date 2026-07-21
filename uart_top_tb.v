// UART Self-Checking Testbench — Fixed timeout version
`timescale 1ns/1ps

module uart_top_tb;

    parameter CLK_FREQ   = 50000000;
    parameter BAUD_RATE  = 115200;
    parameter CLK_PERIOD = 20; // 50MHz = 20ns period

    // One full UART byte = 10 bit periods (start + 8 data + stop)
    // At 115200 baud, 1 bit = ~8680ns, 10 bits = ~86800ns
    // In clock cycles: 86800ns / 20ns = 4340 cycles per byte
    // Timeout = 6000 cycles (generous margin)
    parameter TIMEOUT_CYCLES = 6000;

    reg        clk;
    reg        rst;
    reg  [7:0] tx_data;
    reg        tx_start;
    wire [7:0] rx_data;
    wire       rx_done;
    wire       tx_busy;
    wire       rx_busy;
    wire       tx_line;

    uart_top #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .tx_data (tx_data),
        .tx_start(tx_start),
        .rx_data (rx_data),
        .rx_done (rx_done),
        .tx_busy (tx_busy),
        .rx_busy (rx_busy),
        .tx_line (tx_line)
    );

    // 50MHz clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;
    integer i;
    reg [7:0] sent_byte;

    // Task: send one byte and wait for RX confirmation
    task send_and_check;
        input [7:0] byte_in;
        integer t;
        begin
            sent_byte = byte_in;

            // Wait until TX is free
            t = 0;
            while (tx_busy && t < TIMEOUT_CYCLES) begin
                @(posedge clk); t = t + 1;
            end

            // Send the byte
            @(posedge clk);
            tx_data  = byte_in;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;

            // Wait for rx_done with tight timeout
            t = 0;
            while (!rx_done && t < TIMEOUT_CYCLES * 2) begin
                @(posedge clk); t = t + 1;
            end

            if (rx_done) begin
                if (rx_data === sent_byte) begin
                    $display("PASS: sent 0x%02X, received 0x%02X", sent_byte, rx_data);
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL: sent 0x%02X, received 0x%02X", sent_byte, rx_data);
                    fail_count = fail_count + 1;
                end
            end else begin
                $display("TIMEOUT: sent 0x%02X — rx_done never came", sent_byte);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== UART Self-Checking Testbench ===");

        // Reset
        rst      = 1;
        tx_start = 0;
        tx_data  = 0;
        repeat(20) @(posedge clk);
        rst = 0;
        repeat(10) @(posedge clk);

        // --- Test 1: 10 random bytes ---
        $display("\n--- Test 1: 10 random bytes ---");
        for (i = 0; i < 10; i = i + 1) begin
            send_and_check($random % 256);
        end

        // --- Test 2: Known values ---
        $display("\n--- Test 2: known values ---");
        send_and_check(8'hAA);
        send_and_check(8'h55);
        send_and_check(8'hFF);
        send_and_check(8'h00);

        // --- Test 3: Reset mid-transmission ---
        $display("\n--- Test 3: reset mid-transmission ---");
        tx_data  = 8'hAB;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;
        repeat(50) @(posedge clk);
        rst = 1;
        repeat(10) @(posedge clk);
        rst = 0;
        repeat(10) @(posedge clk);
        if (!tx_busy && tx_line === 1'b1) begin
            $display("PASS: reset mid-transmission — TX recovered cleanly");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: TX did not recover after reset");
            fail_count = fail_count + 1;
        end

        // --- Summary ---
        $display("\n=== RESULTS ===");
        $display("PASSED: %0d", pass_count);
        $display("FAILED: %0d", fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED — check waveforms");

        $finish;
    end

endmodule
