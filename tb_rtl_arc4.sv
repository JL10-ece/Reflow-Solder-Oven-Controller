`timescale 1ns/1ps

module tb_rtl_arc4;

    // DUT signals
    logic clk, rst_n;
    logic en, rdy;

    logic [23:0] key = 24'h000018;   // example key

    logic [7:0] ct_addr;
    logic [7:0] ct_rddata;

    logic [7:0] pt_addr;
    logic [7:0] pt_rddata;
    logic [7:0] pt_wrdata;
    logic       pt_wren;

    int j;
    int key_len;
    logic [7:0] key_bytes [0:2];

    // Instantiating CT and PT
    logic [7:0] CT_mem [0:255];
    logic [7:0] PT_mem [0:255];

    // Clock
    always #10 clk = ~clk;

    // Connect CT/PT reads
    assign ct_rddata = CT_mem[ct_addr];
    assign pt_rddata = PT_mem[pt_addr];

    // Simple TB memory write behavior
    always @(posedge clk) begin
        if (pt_wren)
            PT_mem[pt_addr] <= pt_wrdata;
    end

    // Instantiating ARC4
    arc4 dut(
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .rdy(rdy),
        .key(key),
        .ct_addr(ct_addr),
        .ct_rddata(ct_rddata),
        .pt_addr(pt_addr),
        .pt_rddata(pt_rddata),
        .pt_wrdata(pt_wrdata),
        .pt_wren(pt_wren)
    );

    // Testbench starts

    
    task load_ciphertext();
        integer i;

        CT_mem[0] = 8'h35;  // message length = 55 bytes

        CT_mem[1]  = 8'h56;
        CT_mem[2]  = 8'hC1;
        CT_mem[3]  = 8'hD4;
        CT_mem[4]  = 8'h8C;
        CT_mem[5]  = 8'h33;
        CT_mem[6]  = 8'hC5;
        CT_mem[7]  = 8'h52;
        CT_mem[8]  = 8'h01;
        CT_mem[9]  = 8'h04;
        CT_mem[10] = 8'hDE;
        CT_mem[11] = 8'hCF;
        CT_mem[12] = 8'h12;
        CT_mem[13] = 8'h22;
        CT_mem[14] = 8'h51;
        CT_mem[15] = 8'hFF;
        CT_mem[16] = 8'h1B;
        CT_mem[17] = 8'h36;
        CT_mem[18] = 8'h81;
        CT_mem[19] = 8'hC7;
        CT_mem[20] = 8'hFD;
        CT_mem[21] = 8'hC4;
        CT_mem[22] = 8'hF2;
        CT_mem[23] = 8'h88;
        CT_mem[24] = 8'h5E;
        CT_mem[25] = 8'h16;
        CT_mem[26] = 8'h9A;
        CT_mem[27] = 8'hB5;
        CT_mem[28] = 8'hD3;
        CT_mem[29] = 8'h15;
        CT_mem[30] = 8'hF3;
        CT_mem[31] = 8'h24;
        CT_mem[32] = 8'h7E;
        CT_mem[33] = 8'h4A;
        CT_mem[34] = 8'h8A;
        CT_mem[35] = 8'h2C;
        CT_mem[36] = 8'hB9;
        CT_mem[37] = 8'h43;
        CT_mem[38] = 8'h18;
        CT_mem[39] = 8'h2C;
        CT_mem[40] = 8'hB5;
        CT_mem[41] = 8'h91;
        CT_mem[42] = 8'h7A;
        CT_mem[43] = 8'hE7;
        CT_mem[44] = 8'h43;
        CT_mem[45] = 8'h0D;
        CT_mem[46] = 8'h27;
        CT_mem[47] = 8'hF6;
        CT_mem[48] = 8'h8E;
        CT_mem[49] = 8'hF9;
        CT_mem[50] = 8'h18;
        CT_mem[51] = 8'h79;
        CT_mem[52] = 8'h70;
        CT_mem[53] = 8'h91;

        // Fill remaining with zeroes
        for (i = 54; i < 256; i = i + 1)
            CT_mem[i] = 8'h00;

    endtask


    task clear_pt;
        for (int i=0; i<256; i++)
            PT_mem[i] = 8'h00;
    endtask

    // Main testbench
    initial begin

        clk = 0;
        rst_n = 0;
        en = 0;

        clear_pt();
        load_ciphertext();

        // REMOVE THESE — ARC4 handles INIT + KSA internally
        // init_s();
        // key_schedule(key);

        // Reset
        #20 rst_n = 1;

        // Start ARC4
        #20 en = 1;

        // Wait for completion
        wait (dut.state == dut.DONE);

        // Print output plaintext
        $display("\n=== Plaintext Output ===");
        for (int i = 0; i < 256; i++)
            $display("PT[%0d] = %02x", i, PT_mem[i]);

        $stop;
    end

endmodule: tb_rtl_arc4
