
`timescale 1ps/1ps

module tb_rtl_init();

    // Input and output signals for the testbench
    logic clk;
    logic rst_n;
    logic en;
    logic rdy;
    logic [7:0] addr;
    logic [7:0] wrdata;
    logic wren;

    // Instantiating DUT
    init dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .rdy(rdy),
        .addr(addr),
        .wrdata(wrdata),
        .wren(wren)
    );

    // This is the 50 MHz clock (20 ns = 20000 ps)
    initial begin
        clk = 0;
        forever #10000 clk = ~clk; //10 ns - 10000ps
    end

    // Starting the testbench:
    initial begin

        // Start in reset
        rst_n = 0;
        en    = 0;
        #50000; //50 ns

        // Release reset → enable init
        $display(">>> RELEASE RESET");
        rst_n = 1;
        en = 1;

        // Let init run until rdy becomes 1
        wait (rdy == 1);

        $display(">>> INIT DONE!");

        // Print final values
        $display("Final addr = %0d", addr);
        $display("wren = %0d", wren);
        $display("wrdata = %02X", wrdata);

        wait (dut.state == dut.DONE); // wait till the state changes to finished
        #100;
        $display(">>> TEST completed");
        $stop;
    end

    // Debug printout
    always @(posedge clk) begin
        #1;
        if (wren)
            $display("WRITE: addr=%0d wrdata=%02X time=%0t",
                    addr, wrdata, $time);
    end

endmodule: tb_rtl_init
