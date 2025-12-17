`timescale 1ns/1ps

module tb_rtl_doublecrack;

    // ------------------------------------------------------------
    // Clock + reset
    // ------------------------------------------------------------
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

    // Instantiating CT logic
    logic [7:0] ct_addr;
    logic [7:0] ct_rddata;

    logic [23:0] key;
    logic key_valid;
    logic rdy;

    doublecrack dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .rdy(rdy),
        .key(key),
        .key_valid(key_valid),
        .ct_addr(ct_addr),
        .ct_rddata(ct_rddata)
    );

    logic [7:0] CT_mem [0:255];

    task load_ciphertext();
        integer i;
        CT_mem[0] = 8'h49; // length = 73

        CT_mem[1]  = 8'hA7; CT_mem[2]  = 8'hFD; CT_mem[3]  = 8'h08; CT_mem[4]  = 8'h01;
        CT_mem[5]  = 8'h84; CT_mem[6]  = 8'h45; CT_mem[7]  = 8'h68; CT_mem[8]  = 8'h85;
        CT_mem[9]  = 8'h82; CT_mem[10] = 8'h5C; CT_mem[11] = 8'h85; CT_mem[12] = 8'h97;
        CT_mem[13] = 8'h43; CT_mem[14] = 8'h4D; CT_mem[15] = 8'hE7; CT_mem[16] = 8'h07;
        CT_mem[17] = 8'h25; CT_mem[18] = 8'h0F; CT_mem[19] = 8'h9A; CT_mem[20] = 8'hEC;
        CT_mem[21] = 8'hC2; CT_mem[22] = 8'h6A; CT_mem[23] = 8'h4E; CT_mem[24] = 8'hA7;
        CT_mem[25] = 8'h49; CT_mem[26] = 8'hE0; CT_mem[27] = 8'hEB; CT_mem[28] = 8'h71;
        CT_mem[29] = 8'hBC; CT_mem[30] = 8'hAC; CT_mem[31] = 8'hC7; CT_mem[32] = 8'hD7;
        CT_mem[33] = 8'h57; CT_mem[34] = 8'hE9; CT_mem[35] = 8'hE2; CT_mem[36] = 8'hB1;
        CT_mem[37] = 8'h1B; CT_mem[38] = 8'h09; CT_mem[39] = 8'h52; CT_mem[40] = 8'h33;
        CT_mem[41] = 8'h92; CT_mem[42] = 8'hC1; CT_mem[43] = 8'hB7; CT_mem[44] = 8'hE8;
        CT_mem[45] = 8'h4C; CT_mem[46] = 8'hA1; CT_mem[47] = 8'hD8; CT_mem[48] = 8'h57;
        CT_mem[49] = 8'h2F; CT_mem[50] = 8'hFA; CT_mem[51] = 8'hB8; CT_mem[52] = 8'h72;
        CT_mem[53] = 8'hB9; CT_mem[54] = 8'h3A; CT_mem[55] = 8'hFC; CT_mem[56] = 8'h01;
        CT_mem[57] = 8'hC3; CT_mem[58] = 8'hE5; CT_mem[59] = 8'h18; CT_mem[60] = 8'h32;
        CT_mem[61] = 8'hDF; CT_mem[62] = 8'hBB; CT_mem[63] = 8'h06; CT_mem[64] = 8'h32;
        CT_mem[65] = 8'h2E; CT_mem[66] = 8'h4A; CT_mem[67] = 8'h01; CT_mem[68] = 8'h63;
        CT_mem[69] = 8'h10; CT_mem[70] = 8'h10; CT_mem[71] = 8'h16; CT_mem[72] = 8'hB5;
        CT_mem[73] = 8'hD8; // Last byte of the 73-byte message
        
        // Rest of memory is zero
        for (i = 74; i < 256; i++)
            CT_mem[i] = 8'h00;
    endtask

    assign ct_rddata = CT_mem[ct_addr];

    // Key printing logic
    logic [23:0] last_key_c1, last_key_c2;

    initial begin
        load_ciphertext();
        last_key_c1 = 24'hFFFFFF; // force print first key
        last_key_c2 = 24'hFFFFFF;

        $display("=== BEGIN PARALLEL BRUTE FORCE ===");
        $display("c1 testing: EVEN keys (0, 2, 4, ...)");
        $display("c2 testing: ODD keys  (1, 3, 5, ...)");
        $display("-----------------------------------");

        forever begin
            @(posedge clk);

            // Monitor c1's key changes
            if (dut.c1.key_reg !== last_key_c1) begin
                last_key_c1 = dut.c1.key_reg;
                if (!dut.c1.rdy) begin
                    $display("c1: key = %06h (even)   NOT THE KEY", last_key_c1);
                end
            end

            // Monitor c2's key changes  
            if (dut.c2.key_reg !== last_key_c2) begin
                last_key_c2 = dut.c2.key_reg;
                if (!dut.c2.rdy) begin
                    $display("c2: key = %06h (odd)    NOT THE KEY", last_key_c2);
                end
            end

            // Key found by either instance
            if (rdy && key_valid) begin
                $display("\n==========================================");
                $display(">>>>>>> PARALLEL CRACK SUCCESS! <<<<<<");
                $display("VALID KEY FOUND: %06h", key);
                
                // Show which instance found it
                if (dut.c1.key_valid) begin
                    $display("Found by: c1 (even keys instance)");
                end else if (dut.c2.key_valid) begin
                    $display("Found by: c2 (odd keys instance)");
                end
                $display("==========================================\n");
                
                // Print some stats
                $display("c1 last tested: %06h", dut.c1.key_reg);
                $display("c2 last tested: %06h", dut.c2.key_reg);
                
                $stop;
            end

            // Exhausted keyspace
            if (rdy && !key_valid) begin
                $display("\n==========================================");
                $display("DONE: No valid key found in entire keyspace.");
                $display("c1 tested up to: %06h", dut.c1.key_reg);
                $display("c2 tested up to: %06h", dut.c2.key_reg);
                $display("==========================================\n");
                $stop;
            end
        end
    end

    // Monitoring Performace
    logic [31:0] cycle_count;
    logic [31:0] keys_tested;

    initial begin
        cycle_count = 0;
        keys_tested = 0;
        forever begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            
            // Count when either crack module increments key
            if ((dut.c1.key_reg !== last_key_c1) || (dut.c2.key_reg !== last_key_c2)) begin
                keys_tested = keys_tested + 1;
            end
        end
    end

    // Print performance stats at the end
    final begin
        $display("\n=== PERFORMANCE STATISTICS ===");
        $display("Total clock cycles: %0d", cycle_count);
        $display("Total keys tested:  %0d", keys_tested);
        $display("Keys/sec @ 50MHz:   %0f", (keys_tested * 50_000_000.0) / cycle_count);
        $display("Speedup vs single:  ~2.0x (theoretical)");
    end

endmodule