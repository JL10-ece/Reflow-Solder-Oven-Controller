module arc4(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    // Logic/Registers for the S memory
    logic [7:0] s_addr;
    logic [7:0] s_wrdata;
    logic s_wren;
    logic [7:0] s_rddata;

    // Logic/Registers for the init module
    logic init_en, init_rdy;
    logic [7:0] init_addr;
    logic [7:0] init_wrdata;
    logic init_wren;

    // Logic for the ksa module
    logic ksa_en, ksa_rdy;
    logic [7:0] ksa_addr;
    logic [7:0] ksa_wrdata;
    logic ksa_wren;

    // Logic for the prga module
    logic prga_en, prga_rdy;
    logic [7:0] prga_s_addr;  // s   - read and write
    logic [7:0] prga_s_wrdata;
    logic prga_s_wren;
    logic [7:0] prga_ct_addr; // ct  - read only
    logic [7:0] prga_pt_addr; // pt  - read and write
    logic [7:0] prga_pt_wrdata;
    logic prga_pt_wren;


    s_mem s(
        .address(s_addr),
        .clock(clk),
        .data(s_wrdata),
        .wren(s_wren),
        .q(s_rddata)
    );

    init i(
        .clk(clk),
        .rst_n(rst_n),
        .en(init_en),
        .rdy(init_rdy),
        .addr(init_addr),
        .wrdata(init_wrdata),
        .wren(init_wren)
    );
    ksa k(
        .clk(clk),
        .rst_n(rst_n),
        .en(ksa_en),
        .rdy(ksa_rdy),
        .key(key),
        .addr(ksa_addr),
        .rddata(s_rddata),
        .wrdata(ksa_wrdata),
        .wren(ksa_wren)
    );
    prga p(
        .clk(clk),
        .rst_n(rst_n),
        .en(prga_en),
        .rdy(prga_rdy),
        .key(key),
        .s_addr(prga_s_addr),   // s
        .s_rddata(s_rddata),
        .s_wrdata(prga_s_wrdata),
        .s_wren(prga_s_wren),
        .ct_addr(prga_ct_addr),  // ct
        .ct_rddata(ct_rddata),
        .pt_addr  (prga_pt_addr),  // pt
        .pt_rddata(pt_rddata),
        .pt_wrdata(prga_pt_wrdata),
        .pt_wren  (prga_pt_wren)
    );
    
    // Input assigns
    assign ct_addr   = prga_ct_addr;
    assign pt_addr   = prga_pt_addr;
    assign pt_wrdata = prga_pt_wrdata;
    assign pt_wren   = prga_pt_wren;

    // Instantiating the FSM module
    // Added A to indicate that it inside the arc4.sv file
    typedef enum logic [2:0] {
        A_IDLE,
        A_INIT_START,
        A_INIT_WAIT,
        A_KSA_START,
        A_KSA_WAIT,
        A_PRGA_START,
        A_PRGA_WAIT,
        DONE
    } arc_state;

    arc_state state, next_state;

// State flip flop block
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= A_IDLE;
    else
        state <= next_state;
end

// State updating logic (combinational)
always_comb begin
    next_state = state;

    case (state)

        A_IDLE: begin
            if (en) next_state = A_INIT_START;
        end

        A_INIT_START: begin
            next_state = A_INIT_WAIT;
        end

        A_INIT_WAIT: begin
            if (init_rdy) next_state = A_KSA_START;
        end

        A_KSA_START: begin
            next_state = A_KSA_WAIT;
        end

        A_KSA_WAIT: begin
            if (ksa_rdy) next_state = A_PRGA_START;
        end

        A_PRGA_START: begin
            next_state = A_PRGA_WAIT;
        end

        A_PRGA_WAIT: begin
            if (prga_rdy) next_state = DONE;
        end

        DONE: begin
            next_state = DONE;
        end

        default: next_state = A_IDLE;
    endcase
end

// Combinational output block
always_comb begin
    // defaults
    init_en  = 1'b0;
    ksa_en   = 1'b0;
    prga_en  = 1'b0;
    rdy      = 1'b0;

    // S defaults
    s_addr   = '0;
    s_wrdata = '0;
    s_wren   = 1'b0;

    case (state)

        // init
        A_INIT_START: begin
            init_en  = 1'b1;          // *** clean 1-cycle pulse ***
            s_addr   = init_addr;
            s_wrdata = init_wrdata;
            s_wren   = init_wren;
        end

        A_INIT_WAIT: begin
            s_addr   = init_addr;
            s_wrdata = init_wrdata;
            s_wren   = init_wren;
        end

        // ksa
        A_KSA_START: begin
            ksa_en   = 1'b1;          // *** clean 1-cycle pulse ***
            s_addr   = ksa_addr;
            s_wrdata = ksa_wrdata;
            s_wren   = ksa_wren;
        end

        A_KSA_WAIT: begin
            s_addr   = ksa_addr;
            s_wrdata = ksa_wrdata;
            s_wren   = ksa_wren;
        end

        // prga
        A_PRGA_START: begin
            prga_en  = 1'b1;          // *** clean 1-cycle pulse ***
            s_addr   = prga_s_addr;
            s_wrdata = prga_s_wrdata;
            s_wren   = prga_s_wren;
        end

        A_PRGA_WAIT: begin
            s_addr   = prga_s_addr;
            s_wrdata = prga_s_wrdata;
            s_wren   = prga_s_wren;
        end

        // done
        DONE: begin
            rdy = 1'b1; // finished
        end
    endcase
end


endmodule: arc4
