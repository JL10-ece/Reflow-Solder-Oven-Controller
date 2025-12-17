`timescale 1ns/1ps

module tb_rtl_prga();

    // DUT I/O
    logic clk, rst_n;
    logic en, rdy;

    logic [23:0] key = 24'h010203; // Example key

    logic [7:0] s_addr;
    logic [7:0] s_rddata;
    logic [7:0] s_wrdata;
    logic       s_wren;

    logic [7:0] ct_addr;
    logic [7:0] ct_rddata;

    logic [7:0] pt_addr;
    logic [7:0] pt_rddata;   // not used by PRGA
    logic [7:0] pt_wrdata;
    logic       pt_wren;

    // Memory models
    logic [7:0] S_mem [0:255];
    logic [7:0] CT_mem [0:255];
    logic [7:0] PT_mem [0:255];

    // Clock generation
    always #5 clk = ~clk;

    // Drive read ports
    assign s_rddata  = S_mem[s_addr];
    assign ct_rddata = CT_mem[ct_addr];
    assign pt_rddata = PT_mem[pt_addr];  // unused

    // Capture writes to S memory
    always_ff @(posedge clk) begin
        if (s_wren)
            S_mem[s_addr] <= s_wrdata;
    end

    // Capture writes to PT memory
    always @(posedge clk) begin
    if (pt_wren)
        PT_mem[pt_addr] <= pt_wrdata;
end

    // Instantiate DUT
    prga dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .rdy(rdy),
        .key(key),
        .s_addr(s_addr),
        .s_rddata(s_rddata),
        .s_wrdata(s_wrdata),
        .s_wren(s_wren),
        .ct_addr(ct_addr),
        .ct_rddata(ct_rddata),
        .pt_addr(pt_addr),
        .pt_rddata(pt_rddata),
        .pt_wrdata(pt_wrdata),
        .pt_wren(pt_wren)
    );

    // Initialize S after KSA (this TB assumes KSA already done)
    task init_sbox();
        begin
            S_mem[8'h00] = 8'h10; S_mem[8'h01] = 8'h01; S_mem[8'h02] = 8'h1B; S_mem[8'h03] = 8'h1E;
            S_mem[8'h04] = 8'hFF; S_mem[8'h05] = 8'h50; S_mem[8'h06] = 8'h7C; S_mem[8'h07] = 8'h5D;
            S_mem[8'h08] = 8'h77; S_mem[8'h09] = 8'h2D; S_mem[8'h0A] = 8'h2B; S_mem[8'h0B] = 8'h40;
            S_mem[8'h0C] = 8'hEA; S_mem[8'h0D] = 8'h74; S_mem[8'h0E] = 8'h72; S_mem[8'h0F] = 8'h14;

            S_mem[8'h10] = 8'h00; S_mem[8'h11] = 8'h07; S_mem[8'h12] = 8'h48; S_mem[8'h13] = 8'h3D;
            S_mem[8'h14] = 8'h7A; S_mem[8'h15] = 8'h69; S_mem[8'h16] = 8'h09; S_mem[8'h17] = 8'hD4;
            S_mem[8'h18] = 8'hEC; S_mem[8'h19] = 8'h3F; S_mem[8'h1A] = 8'hDE; S_mem[8'h1B] = 8'h49;
            S_mem[8'h1C] = 8'hBE; S_mem[8'h1D] = 8'h67; S_mem[8'h1E] = 8'hE6; S_mem[8'h1F] = 8'h0D;

            S_mem[8'h20] = 8'hD3; S_mem[8'h21] = 8'h19; S_mem[8'h22] = 8'h53; S_mem[8'h23] = 8'h44;
            S_mem[8'h24] = 8'h68; S_mem[8'h25] = 8'h03; S_mem[8'h26] = 8'hA1; S_mem[8'h27] = 8'h18;
            S_mem[8'h28] = 8'hCC; S_mem[8'h29] = 8'h32; S_mem[8'h2A] = 8'h6D; S_mem[8'h2B] = 8'h46;
            S_mem[8'h2C] = 8'h38; S_mem[8'h2D] = 8'h04; S_mem[8'h2E] = 8'h9E; S_mem[8'h2F] = 8'h61;

            S_mem[8'h30] = 8'h0C; S_mem[8'h31] = 8'h0B; S_mem[8'h32] = 8'h43; S_mem[8'h33] = 8'hFA;
            S_mem[8'h34] = 8'h4D; S_mem[8'h35] = 8'hDD; S_mem[8'h36] = 8'hB1; S_mem[8'h37] = 8'h88;
            S_mem[8'h38] = 8'hA6; S_mem[8'h39] = 8'hF9; S_mem[8'h3A] = 8'hCD; S_mem[8'h3B] = 8'h89;
            S_mem[8'h3C] = 8'h35; S_mem[8'h3D] = 8'h23; S_mem[8'h3E] = 8'hAB; S_mem[8'h3F] = 8'hCA;

            S_mem[8'h40] = 8'h94; S_mem[8'h41] = 8'h51; S_mem[8'h42] = 8'hFC; S_mem[8'h43] = 8'hA4;
            S_mem[8'h44] = 8'h31; S_mem[8'h45] = 8'hE5; S_mem[8'h46] = 8'hFB; S_mem[8'h47] = 8'h13;
            S_mem[8'h48] = 8'hA9; S_mem[8'h49] = 8'h73; S_mem[8'h4A] = 8'h7D; S_mem[8'h4B] = 8'hC8;
            S_mem[8'h4C] = 8'hCF; S_mem[8'h4D] = 8'h83; S_mem[8'h4E] = 8'h1D; S_mem[8'h4F] = 8'hE2;

            S_mem[8'h50] = 8'h5E; S_mem[8'h51] = 8'hDC; S_mem[8'h52] = 8'h64; S_mem[8'h53] = 8'hE9;
            S_mem[8'h54] = 8'h78; S_mem[8'h55] = 8'h59; S_mem[8'h56] = 8'hC7; S_mem[8'h57] = 8'hBF;
            S_mem[8'h58] = 8'h76; S_mem[8'h59] = 8'hF1; S_mem[8'h5A] = 8'h22; S_mem[8'h5B] = 8'h5F;
            S_mem[8'h5C] = 8'h05; S_mem[8'h5D] = 8'h1F; S_mem[8'h5E] = 8'h6B; S_mem[8'h5F] = 8'hD8;

            S_mem[8'h60] = 8'h91; S_mem[8'h61] = 8'h99; S_mem[8'h62] = 8'h36; S_mem[8'h63] = 8'h58;
            S_mem[8'h64] = 8'h8E; S_mem[8'h65] = 8'hFE; S_mem[8'h66] = 8'hB6; S_mem[8'h67] = 8'hB4;
            S_mem[8'h68] = 8'h0F; S_mem[8'h69] = 8'hC2; S_mem[8'h6A] = 8'h9B; S_mem[8'h6B] = 8'hAF;
            S_mem[8'h6C] = 8'hB7; S_mem[8'h6D] = 8'h8C; S_mem[8'h6E] = 8'h8A; S_mem[8'h6F] = 8'hD6;

            S_mem[8'h70] = 8'h62; S_mem[8'h71] = 8'h9C; S_mem[8'h72] = 8'hE1; S_mem[8'h73] = 8'h81;
            S_mem[8'h74] = 8'hBB; S_mem[8'h75] = 8'hD5; S_mem[8'h76] = 8'h79; S_mem[8'h77] = 8'h6C;
            S_mem[8'h78] = 8'h9D; S_mem[8'h79] = 8'hE3; S_mem[8'h7A] = 8'hF0; S_mem[8'h7B] = 8'h47;
            S_mem[8'h7C] = 8'h45; S_mem[8'h7D] = 8'hAA; S_mem[8'h7E] = 8'hBA; S_mem[8'h7F] = 8'hC4;

            S_mem[8'h80] = 8'h70; S_mem[8'h81] = 8'h56; S_mem[8'h82] = 8'h39; S_mem[8'h83] = 8'h20;
            S_mem[8'h84] = 8'h4A; S_mem[8'h85] = 8'hB0; S_mem[8'h86] = 8'h8B; S_mem[8'h87] = 8'h3B;
            S_mem[8'h88] = 8'h9A; S_mem[8'h89] = 8'hF7; S_mem[8'h8A] = 8'h66; S_mem[8'h8B] = 8'h97;
            S_mem[8'h8C] = 8'hE0; S_mem[8'h8D] = 8'h21; S_mem[8'h8E] = 8'h42; S_mem[8'h8F] = 8'hC0;

            S_mem[8'h90] = 8'hF4; S_mem[8'h91] = 8'h6A; S_mem[8'h92] = 8'h95; S_mem[8'h93] = 8'h33;
            S_mem[8'h94] = 8'hEB; S_mem[8'h95] = 8'h16; S_mem[8'h96] = 8'h34; S_mem[8'h97] = 8'h5C;
            S_mem[8'h98] = 8'h27; S_mem[8'h99] = 8'h7E; S_mem[8'h9A] = 8'h08; S_mem[8'h9B] = 8'h2E;
            S_mem[8'h9C] = 8'hDB; S_mem[8'h9D] = 8'h5B; S_mem[8'h9E] = 8'h1A; S_mem[8'h9F] = 8'hA8;

            S_mem[8'hA0] = 8'hA3; S_mem[8'hA1] = 8'hCB; S_mem[8'hA2] = 8'hD7; S_mem[8'hA3] = 8'h17;
            S_mem[8'hA4] = 8'hFD; S_mem[8'hA5] = 8'h6F; S_mem[8'hA6] = 8'h4F; S_mem[8'hA7] = 8'h12;
            S_mem[8'hA8] = 8'h3A; S_mem[8'hA9] = 8'hF6; S_mem[8'hAA] = 8'hDA; S_mem[8'hAB] = 8'hC6;
            S_mem[8'hAC] = 8'h85; S_mem[8'hAD] = 8'h75; S_mem[8'hAE] = 8'h2F; S_mem[8'hAF] = 8'h7B;

            S_mem[8'hB0] = 8'hED; S_mem[8'hB1] = 8'hC3; S_mem[8'hB2] = 8'hE8; S_mem[8'hB3] = 8'hF5;
            S_mem[8'hB4] = 8'h6E; S_mem[8'hB5] = 8'h55; S_mem[8'hB6] = 8'hBD; S_mem[8'hB7] = 8'hB2;
            S_mem[8'hB8] = 8'hEF; S_mem[8'hB9] = 8'h15; S_mem[8'hBA] = 8'h87; S_mem[8'hBB] = 8'h0A;
            S_mem[8'hBC] = 8'hF3; S_mem[8'hBD] = 8'h65; S_mem[8'hBE] = 8'hB5; S_mem[8'hBF] = 8'hBC;

            S_mem[8'hC0] = 8'h4C; S_mem[8'hC1] = 8'hA0; S_mem[8'hC2] = 8'hEE; S_mem[8'hC3] = 8'h71;
            S_mem[8'hC4] = 8'hAC; S_mem[8'hC5] = 8'hCE; S_mem[8'hC6] = 8'h92; S_mem[8'hC7] = 8'h9F;
            S_mem[8'hC8] = 8'hB9; S_mem[8'hC9] = 8'hA5; S_mem[8'hCA] = 8'h63; S_mem[8'hCB] = 8'h1C;
            S_mem[8'hCC] = 8'h37; S_mem[8'hCD] = 8'h82; S_mem[8'hCE] = 8'h7F; S_mem[8'hCF] = 8'h29;

            S_mem[8'hD0] = 8'h2A; S_mem[8'hD1] = 8'h26; S_mem[8'hD2] = 8'h52; S_mem[8'hD3] = 8'h06;
            S_mem[8'hD4] = 8'h0E; S_mem[8'hD5] = 8'hC9; S_mem[8'hD6] = 8'hD9; S_mem[8'hD7] = 8'hDF;
            S_mem[8'hD8] = 8'h11; S_mem[8'hD9] = 8'hB3; S_mem[8'hDA] = 8'h30; S_mem[8'hDB] = 8'h4E;
            S_mem[8'hDC] = 8'hB8; S_mem[8'hDD] = 8'h86; S_mem[8'hDE] = 8'h28; S_mem[8'hDF] = 8'h54;

            S_mem[8'hE0] = 8'hD0; S_mem[8'hE1] = 8'hC1; S_mem[8'hE2] = 8'h96; S_mem[8'hE3] = 8'hD1;
            S_mem[8'hE4] = 8'h90; S_mem[8'hE5] = 8'hE4; S_mem[8'hE6] = 8'h57; S_mem[8'hE7] = 8'h25;
            S_mem[8'hE8] = 8'h41; S_mem[8'hE9] = 8'hAD; S_mem[8'hEA] = 8'hAE; S_mem[8'hEB] = 8'hA7;
            S_mem[8'hEC] = 8'hF2; S_mem[8'hED] = 8'h4B; S_mem[8'hEE] = 8'h8F; S_mem[8'hEF] = 8'h24;

            S_mem[8'hF0] = 8'h84; S_mem[8'hF1] = 8'h2C; S_mem[8'hF2] = 8'hC5; S_mem[8'hF3] = 8'h8D;
            S_mem[8'hF4] = 8'h60; S_mem[8'hF5] = 8'h3E; S_mem[8'hF6] = 8'hD2; S_mem[8'hF7] = 8'hF8;
            S_mem[8'hF8] = 8'hA2; S_mem[8'hF9] = 8'h93; S_mem[8'hFA] = 8'h3C; S_mem[8'hFB] = 8'h98;
            S_mem[8'hFC] = 8'h02; S_mem[8'hFD] = 8'h80; S_mem[8'hFE] = 8'hE7; S_mem[8'hFF] = 8'h5A;
        end
    endtask


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

    initial begin
        clk = 0;
        rst_n = 0;
        en = 0;

        init_sbox();
        load_ciphertext();

        // Clear PT memory
        for (int i = 0; i < 256; i++)
            PT_mem[i] = 0;

        // Apply reset
        #20 rst_n = 1;

        // Start PRGA
        #10 en = 1;
        #10 en = 0;

        // Wait until done
        wait (dut.state == dut.DONE);

        #1000; // wait sufficiently long

        $display("=== PRGA FINISHED ===");
        $display("Message length = %0d", PT_mem[0]);

        for (int k = 1; k <= PT_mem[0]; k++) begin
            $display("PT[%0d] = %02x", k, PT_mem[k]);
        end


        $stop;
    end

endmodule: tb_rtl_prga
