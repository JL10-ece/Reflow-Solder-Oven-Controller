module task2(
    input  logic CLOCK_50,
    input  logic [3:0] KEY,
    input  logic [9:0] SW,
    output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    output logic [9:0] LEDR
);

    typedef enum logic [3:0] {
        S_IDLE,
        S_INIT,
        S_WAIT,
        S_KSA_START,
        S_KSA_RUN,
        S_DONE
    } top_state_t;

    top_state_t state, next_state;

    // INIT module wires
    logic [7:0] addr_i, wrdata_i;
    logic       wren_i, rdy_init;

    // KSA module wires
    logic [7:0] addr_k, wrdata_k, rddata_k;
    logic       wren_k, rdy_ksa;

    // Shared memory bus
    logic [7:0] addr_w, wrdata_w, rddata_w;
    logic       wren_w;

    // Enables
    logic en_init, en_ksa;

    // Memory
    s_mem S(
        .address(addr_w),
        .clock(CLOCK_50),
        .data(wrdata_w),
        .wren(wren_w),
        .q(rddata_w)
    );

    // Instantiating init
    init pop(
        .clk(CLOCK_50),
        .rst_n(KEY[3]),
        .en(en_init),
        .rdy(rdy_init),
        .addr(addr_i),
        .wrdata(wrdata_i),
        .wren(wren_i)
    );

    // Instantiating KSA
    ksa k(
        .clk(CLOCK_50),
        .rst_n(KEY[3]),
        .en(en_ksa), //change for debugging
        .rdy(rdy_ksa),
        .key({14'd0, SW[9:0]}),
        .addr(addr_k),
        .rddata(rddata_k),
        .wrdata(wrdata_k),
        .wren(wren_k)
    );

    assign rddata_k = rddata_w;

    // Flip flip block for state changing
    always_ff @(posedge CLOCK_50 or negedge KEY[3]) begin
        if (!KEY[3])
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // FSM combinational logic
    always_comb begin
        next_state = state;

        case (state)
            S_IDLE:       next_state = S_INIT;

            S_INIT: begin
                if (rdy_init)       // init finished
                    next_state = S_WAIT;
            end

            S_WAIT:
                next_state = S_KSA_START;

            S_KSA_START:
                next_state = S_KSA_RUN;

            S_KSA_RUN: begin
                if (rdy_ksa)  // ksa finished
                    next_state = S_DONE;
            end

            S_DONE:
                next_state = S_DONE;

        endcase
    end

    // Enables
    assign en_init = (state == S_INIT);
    assign en_ksa  = (state == S_KSA_START) || (state == S_KSA_RUN);

    // Memory Bus
    always_comb begin
        addr_w   = 8'h00;
        wrdata_w = 8'h00;
        wren_w   = 1'b0;

        case (state)
            S_INIT: begin
                addr_w   = addr_i;
                wrdata_w = wrdata_i;
                wren_w   = wren_i;
            end

            S_KSA_START,
            S_KSA_RUN: begin
                addr_w   = addr_k;
                wrdata_w = wrdata_k;
                wren_w   = wren_k;
            end

            default: ; // no writes
        endcase
    end

    // LED display
    always_comb begin
        if (state == S_DONE) begin
            HEX5 = 7'b0100001; // d
            HEX4 = 7'b0100011; // o
            HEX3 = 7'b0101011; // n
            HEX2 = 7'b0000110; // E
            HEX1 = 7'b1111111;
            HEX0 = 7'b1111111;
        end else begin
            HEX0 = 7'b1111111;
            HEX1 = 7'b1111111;
            HEX2 = 7'b1111111;
            HEX3 = 7'b1111111;
            HEX4 = 7'b1111111;
            HEX5 = 7'b1111111;
        end
    end

    assign LEDR = SW;

endmodule
