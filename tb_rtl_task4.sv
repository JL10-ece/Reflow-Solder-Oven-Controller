`timescale 1ns/1ps

module tb_rtl_task4;

    // Instantiating the logic/wires
    logic CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;

    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    // Instantiating task4
    task4 dut (
        .CLOCK_50 (CLOCK_50),
        .KEY      (KEY),
        .SW       (SW),
        .HEX0     (HEX0),
        .HEX1     (HEX1),
        .HEX2     (HEX2),
        .HEX3     (HEX3),
        .HEX4     (HEX4),
        .HEX5     (HEX5),
        .LEDR     (LEDR)
    );

    // Clock generation
    initial CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50;

    // Memory Initialization

    initial begin
        // Plain defaults
        SW = '0;

        // Active-high reset in your RTL:
        // rst_n = KEY[3]
        KEY = 4'b1111;   // reset deasserted
        #5;
        KEY[3] = 1'b0;   // assert reset (rst_n = 0)
        #100;
        KEY[3] = 1'b1;   // release reset (rst_n = 1)
    end

    // Monitoring Signals
    initial begin
        $display("Starting simulation...");
        $display("Time    ct_addr   ct_rddata   crack_rdy   crack_key       key_valid");
        $monitor("%0t     0x%02h      0x%02h        %0d        %06h         %0d",
                 $time,
                 dut.ct_addr,
                 dut.ct_rddata,
                 dut.crack_rdy,
                 dut.crack_key,
                 dut.crack_key_valid);
    end

    // Stopping after simulation
    initial begin
        wait(dut.crack_key_valid == 1);
        #100;
        $display("Simulation complete.");
        $stop;
    end

endmodule
