module task5(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    // Reset assign (KEY[3] is active-low reset)
    logic rst_n;
    assign rst_n = KEY[3];

    // crack enable assign - always enabled
    logic crack_en;
    assign crack_en = 1'b1;

    // CT wires
    logic [7:0] ct_addr;
    logic [7:0] ct_rddata;

    // doublecrack wires
    logic dcrack_rdy;
    logic [23:0] dcrack_key;
    logic dcrack_key_valid;

    // Instantiating CT mem
    ct_mem ct(
        .address(ct_addr),
        .clock(CLOCK_50),
        .data(8'b0),       // read-only
        .wren(1'b0),       // never written
        .q(ct_rddata)
    );

    // Doublecrack instantiation
    doublecrack dc(
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .en(crack_en),
        .rdy(dcrack_rdy),
        .key(dcrack_key),
        .key_valid(dcrack_key_valid),
        .ct_addr(ct_addr),
        .ct_rddata(ct_rddata)
    );

    // HEX function
    function automatic [6:0] hex7(input logic [3:0] nibble);
        case (nibble)
            4'h0: hex7 = 7'b1000000; // 0
            4'h1: hex7 = 7'b1111001; // 1
            4'h2: hex7 = 7'b0100100; // 2
            4'h3: hex7 = 7'b0110000; // 3
            4'h4: hex7 = 7'b0011001; // 4
            4'h5: hex7 = 7'b0010010; // 5
            4'h6: hex7 = 7'b0000010; // 6
            4'h7: hex7 = 7'b1111000; // 7
            4'h8: hex7 = 7'b0000000; // 8
            4'h9: hex7 = 7'b0010000; // 9
            4'hA: hex7 = 7'b0001000; // A
            4'hB: hex7 = 7'b0000011; // b / B
            4'hC: hex7 = 7'b1000110; // C
            4'hD: hex7 = 7'b0100001; // d / D
            4'hE: hex7 = 7'b0000110; // E
            4'hF: hex7 = 7'b0001110; // F
            default: hex7 = 7'b1111111; // blank
        endcase
    endfunction

    localparam [6:0] SEG_BLANK = 7'b1111111;
    localparam [6:0] SEG_DASH  = 7'b0111111;

    // HEX logic
    always_comb begin
        // default: all blank
        HEX0 = SEG_BLANK;
        HEX1 = SEG_BLANK;
        HEX2 = SEG_BLANK;
        HEX3 = SEG_BLANK;
        HEX4 = SEG_BLANK;
        HEX5 = SEG_BLANK;

        if (dcrack_rdy) begin
            if (dcrack_key_valid) begin
                // Show hex key dcrack_key[23:0]
                HEX5 = hex7(dcrack_key[23:20]);
                HEX4 = hex7(dcrack_key[19:16]);
                HEX3 = hex7(dcrack_key[15:12]);
                HEX2 = hex7(dcrack_key[11:8]);
                HEX1 = hex7(dcrack_key[7:4]);
                HEX0 = hex7(dcrack_key[3:0]);
            end else begin
                // Searched full key space but no valid key: show "------"
                HEX5 = SEG_DASH;
                HEX4 = SEG_DASH;
                HEX3 = SEG_DASH;
                HEX2 = SEG_DASH;
                HEX1 = SEG_DASH;
                HEX0 = SEG_DASH;
            end
        end
        // else (dcrack_rdy == 0): leave all blank while computing
    end

    // Assigning LED
    assign LEDR[0]   = dcrack_rdy;
    assign LEDR[1]   = dcrack_key_valid;
    
    // Use SW[0] to select display mode (optional)
    // If SW[0] is ON, show which instance found the key
    // LEDR[2] = 1 if c1 (even keys) found it, 0 if c2 (odd keys) found it
    // (This requires accessing internal signals - see alternative below)
    assign LEDR[9:2] = 8'b0;  // Turn off remaining LEDs

endmodule : task5