`timescale 1ps/1ps

module tb_rtl_ksa();

    // DUT I/O signals
    logic clk;
    logic rst_n;
    logic en;
    logic rdy;

    logic [23:0] key;
    logic [7:0]  addr;
    logic [7:0]  rddata;
    logic [7:0]  wrdata;
    logic        wren;

    // Local memory representing S
    logic [7:0] S [0:255];

    // Instantiate DUT
    ksa dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .rdy(rdy),
        .key(key),
        .addr(addr),
        .rddata(rddata),
        .wrdata(wrdata),
        .wren(wren)
    );

    // clock gen
    initial begin
        clk = 0;
        forever #10000 clk = ~clk;   // 20 ns period
    end

    // To read memory
    assign rddata = S[addr];

    // Memory write port
    always @(posedge clk) begin
        if (wren) begin
            S[addr] <= wrdata;
            $display("WRITE: S[%0d] <= %02X   time=%0t",
                      addr, wrdata, $time);
        end
    end

    initial begin
        integer i;

        // Init S as identity permutation
        for (i = 0; i < 256; i++) 
            S[i] = i;

        // 3-byte key
        key = 24'h00033C;

        // Reset pulse
        rst_n = 1; #10000;
        rst_n = 0; #20000;
        rst_n = 1;

        // Enable KSA shortly after reset
        en = 0; #35000;
        en = 1;

        // Wait until KSA done
        wait(dut.state == dut.DONE);
        #100000;

        $display(">>> KSA COMPLETE");

        for (i = 0; i < 16; i++)
            $display("S[%0d] = %02X", i, S[i]);
        $stop;
    end

endmodule
