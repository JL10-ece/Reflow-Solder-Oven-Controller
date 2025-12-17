module task3(
    input  logic CLOCK_50, 
    input  logic [3:0] KEY, 
    input  logic [9:0] SW,
    output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    output logic [9:0] LEDR
);

    // Logic/wire instantiation
    logic [7:0] ct_addr, ct_rddata;
    logic [7:0] pt_addr, pt_rddata, pt_wrdata;
    logic       pt_wren;

    logic arc4_rdy;
    logic en;

    // Button handling (active-low)
    logic key_now, key_prev;
    assign key_now = ~KEY[3];   // 1 = pressed


    // FSM
    typedef enum logic [1:0] {
        IDLE,
        PULSE_EN,
        WAIT_DONE
    } fsm_t;

    fsm_t state, next_state;

    // State register
    always_ff @(posedge CLOCK_50 or negedge KEY[3]) begin
        if (!KEY[3])
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                // button release edge: pressed last cycle & now released
                if (key_prev && !key_now)
                    next_state = PULSE_EN;
            end

            // 1-cycle EN pulse
            PULSE_EN: begin
                next_state = WAIT_DONE;
            end

            // Wait until arc4 finishes
            WAIT_DONE: begin
                if (arc4_rdy)
                    next_state = IDLE;
            end

        endcase
    end

    // Register button state for edge detection
    always_ff @(posedge CLOCK_50) begin
        key_prev <= key_now;
    end

    // pulse checking off enables
    assign en = (state == PULSE_EN);


    // memory instantiation
    ct_mem ct(
        .address(ct_addr),
        .clock  (CLOCK_50),
        .data   (8'd0),
        .wren   (1'b0),
        .q      (ct_rddata)
    );

    pt_mem pt(
        .address(pt_addr),
        .clock  (CLOCK_50),
        .data   (pt_wrdata),
        .wren   (pt_wren),
        .q      (pt_rddata)
    );

    // arc4 instantiation
    arc4 a4(
        .clk      (CLOCK_50),
        .rst_n    (KEY[3]),
        .en       (en),            // 1-cycle pulse
        .rdy      (arc4_rdy),
        .key      ({14'd0, SW[9:0]}),

        .ct_addr  (ct_addr),
        .ct_rddata(ct_rddata),

        .pt_addr  (pt_addr),
        .pt_rddata(pt_rddata),
        .pt_wrdata(pt_wrdata),
        .pt_wren  (pt_wren)
    );

    // LED assigns
    assign LEDR[0]   = arc4_rdy;
    assign LEDR[9:1] = '0;

    assign HEX0 = 7'b111_1111;
    assign HEX1 = 7'b111_1111;
    assign HEX2 = 7'b111_1111;
    assign HEX3 = 7'b111_1111;
    assign HEX4 = 7'b111_1111;
    assign HEX5 = 7'b111_1111;

endmodule
