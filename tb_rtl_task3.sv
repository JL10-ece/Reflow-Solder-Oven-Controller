`timescale 1ns/1ps

module tb_rtl_task3;
    logic CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    // Instantiate DUT
    task3 dut(
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .LEDR(LEDR)
    );

    // Clock generation
    initial CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50; // 50 MHz -> 20ns period

    // Test sequence
    initial begin
        // Initialize inputs
        KEY = 4'b1111;  // reset inactive
        SW  = 10'b0000011000;

        // Apply reset
        KEY[3] = 0;
        #50;
        KEY[3] = 1;
        #50;

        // Wait for ARC4 to finish
        wait(dut.arc4_rdy == 1); 

        #1000;
        $display("ARC4 Finished at time %t", $time);

        // Inspect memory / outputs if needed
        $stop;
    end
endmodule: tb_rtl_task3
