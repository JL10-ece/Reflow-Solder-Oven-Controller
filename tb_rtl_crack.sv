`timescale 1ns/1ps

module tb_rtl_crack;

    // Clock and reset logic
    logic clk;
    logic rst_n;
    logic en;

    initial begin
        clk = 0;
        forever #10 clk = ~clk;   // 50MHz clock
    end

    initial begin
        rst_n = 0;
        en    = 0;
        #100;
        rst_n = 1;
        #50;
        en = 1;  // start cracking
    end

    // Input and output instantiation
    logic [7:0] ct_addr;
    logic [7:0] ct_rddata;

    logic [23:0] key;
    logic key_valid;
    logic rdy;

    crack dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .rdy(rdy),
        .key(key),
        .key_valid(key_valid),
        .ct_addr(ct_addr),
        .ct_rddata(ct_rddata),

        //New additons for parallel cracking
        .start_key(24'd0),
        .step_key(24'd1)
    );

    // Other CT memory instantiation
    logic [7:0] CT_mem [0:255];

    task load_ciphertext();
        integer i;
        CT_mem[0] = 8'h35; // length = 53

        CT_mem[1]  = 8'h56; CT_mem[2]  = 8'hC1; CT_mem[3]  = 8'hD4; CT_mem[4]  = 8'h8C;
        CT_mem[5]  = 8'h33; CT_mem[6]  = 8'hC5; CT_mem[7]  = 8'h52; CT_mem[8]  = 8'h01;
        CT_mem[9]  = 8'h04; CT_mem[10] = 8'hDE; CT_mem[11] = 8'hCF; CT_mem[12] = 8'h12;
        CT_mem[13] = 8'h22; CT_mem[14] = 8'h51; CT_mem[15] = 8'hFF; CT_mem[16] = 8'h1B;
        CT_mem[17] = 8'h36; CT_mem[18] = 8'h81; CT_mem[19] = 8'hC7; CT_mem[20] = 8'hFD;
        CT_mem[21] = 8'hC4; CT_mem[22] = 8'hF2; CT_mem[23] = 8'h88; CT_mem[24] = 8'h5E;
        CT_mem[25] = 8'h16; CT_mem[26] = 8'h9A; CT_mem[27] = 8'hB5; CT_mem[28] = 8'hD3;
        CT_mem[29] = 8'h15; CT_mem[30] = 8'hF3; CT_mem[31] = 8'h24; CT_mem[32] = 8'h7E;
        CT_mem[33] = 8'h4A; CT_mem[34] = 8'h8A; CT_mem[35] = 8'h2C; CT_mem[36] = 8'hB9;
        CT_mem[37] = 8'h43; CT_mem[38] = 8'h18; CT_mem[39] = 8'h2C; CT_mem[40] = 8'hB5;
        CT_mem[41] = 8'h91; CT_mem[42] = 8'h7A; CT_mem[43] = 8'hE7; CT_mem[44] = 8'h43;
        CT_mem[45] = 8'h0D; CT_mem[46] = 8'h27; CT_mem[47] = 8'hF6; CT_mem[48] = 8'h8E;
        CT_mem[49] = 8'hF9; CT_mem[50] = 8'h18; CT_mem[51] = 8'h79; CT_mem[52] = 8'h70;
        CT_mem[53] = 8'h91;

        for (i = 54; i < 256; i++)
            CT_mem[i] = 8'h00;
    endtask

    assign ct_rddata = CT_mem[ct_addr];

    // Key printing logic
    logic [23:0] last_key;

    initial begin
        load_ciphertext();
        last_key = 24'hFFFFFF; // force print first key

        $display("=== BEGIN BRUTE FORCE ===");

        forever begin
            @(posedge clk);

            // Key changed → crack engine tested a new key
            if (dut.key_reg !== last_key) begin
                last_key = dut.key_reg;

                if (!rdy) begin
                    $display("key = %06h   NOT THE KEY", last_key);
                end
            end

            // Key found
            if (rdy && key_valid) begin
                $display("\n>>>>>>> VALID KEY FOUND: %06h <<<<<<\n", key);
                $stop;
            end

            // Exhausted keyspace
            if (rdy && !key_valid) begin
                $display("\nDONE: No valid key found.\n");
                $stop;
            end
        end
    end

endmodule
