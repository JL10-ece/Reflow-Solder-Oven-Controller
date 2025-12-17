
`timescale 1ps/1ps

module tb_rtl_task2();

    logic CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    task2 dut (
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .LEDR(LEDR)
    );

    // Clock generation
    initial begin
        CLOCK_50 = 0;
        forever #10 CLOCK_50 = ~CLOCK_50;
    end

    // Stimulus
    initial begin : tb_main

        integer i;

        SW = 10'b0000011000; //0x18 key
        //SW = 10'b1100111100; //0x3C key
        KEY = 4'b1111;

        #50;

        $display("[%0t] Assert reset", $time);
        KEY[3] = 0;
        #50;

        $display("[%0t] Release reset", $time);
        KEY[3] = 1;

        $display("[%0t] Waiting for KSA FSM to reach DONE...", $time);

        fork
            // Timeout protection
            begin : timeout_block
                #5_000_000;
                $display("ERROR: TIMEOUT waiting for KSA DONE!");
                $display("=== S memory dump ===");
                for (i = 0; i < 256; i++) begin
                    $display("S[%0d] = %02h", i,
                    dut.S.altsyncram_component.m_default.altsyncram_inst.mem_data[i]);  
                end
                $stop;
            end

            begin : wait_done_block
                wait (dut.k.state == dut.k.DONE);
                disable timeout_block;
            end
        join

        $display("[%0t] KSA REACHED DONE STATE!", $time);

        // Print RAM
        $display("=== S memory dump ===");
        for (i = 0; i < 256; i++) begin
            $display("S[%0d] = %02h",
                i,
                dut.S.altsyncram_component.m_default.altsyncram_inst.mem_data[i]
            );
        end

        $display("Simulation complete.");
        $stop;
    end

endmodule: tb_rtl_task2
