`timescale 1ps/1ps

module tb_rtl_task1();

    // ---------- DUT signals ----------
    logic CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    // Instantiate DUT
    task1 dut(
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .LEDR(LEDR)
    );

    // This is the 50MHz Clock
    initial begin
        CLOCK_50 = 0;
        forever #10 CLOCK_50 = ~CLOCK_50;   // 20 ns = 20000 ps
    end

    // This is the start of the testbench
    initial begin
        
        KEY = 4'b1111;
        SW  = 10'd0;

        #100;            // wait 100 ns

        // ----- Press reset -----
        $display(">>> ASSERT RESET");
        KEY[3] = 0;
        #200;            // hold reset

        // ----- Release reset -----
        $display(">>> RELEASE RESET");
        KEY[3] = 1;

        // Waiting for init to finish
        wait(dut.pop.rdy == 1);

        #200;
        #200;
        #200;
        // Dump first few bytes of the M10K memory rather than showing all 256
        $display("RTL Memory Dump");
        for (int k = 0; k < 256; k++) begin
            $display("mem[%0d] = %02X",
                k, dut.s.altsyncram_component.m_default.altsyncram_inst.mem_data[k]);
        end

        $display(">>> RTL task1 test completed.");


        $stop;
    end

endmodule: tb_rtl_task1
