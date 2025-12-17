module ksa(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,
    output logic        rdy,
    input  logic [23:0] key,
    output logic [7:0]  addr,
    input  logic [7:0]  rddata,
    output logic [7:0]  wrdata,
    output logic        wren
);

    typedef enum logic [3:0] {
        IDLE,
        READ_I,
        LATCH_I,
        CALC_J,
        READ_J,
        LATCH_J,
        WRITE_I,
        WRITE_J,
        INC_I,
        DONE
    } fsm_var;

    fsm_var state, next_state;

    // internal registers
    logic [7:0] i, j;
    logic [7:0] Si, Sj, temp;

    // Sequential Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;

            i     <= 0;
            j     <= 0;
            Si    <= 0;
            Sj    <= 0;
            temp  <= 0;
            rdy   <= 0;
        end else begin
            state <= next_state;

            case (state)

                IDLE: begin
                    rdy <= 0;
                    if (en) begin
                        i <= 0;
                        j <= 0;
                    end
                end

                LATCH_I: begin
                    Si <= rddata;
                end

                CALC_J: begin
                    case (i % 3)
                        0: j <= j + Si + key[23:16];
                        1: j <= j + Si + key[15:8];
                        2: j <= j + Si + key[7:0];
                    endcase
                end

                LATCH_J: begin
                    Sj   <= rddata;
                    temp <= Si;
                end

                INC_I: begin
                    if (i != 8'hFF)
                        i <= i + 1;
                end

                DONE: begin
                    rdy <= 1;
                end
            endcase
        end
    end

    // Next State logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE:    next_state = (en ? READ_I : IDLE);
            READ_I:  next_state = LATCH_I;
            LATCH_I: next_state = CALC_J;
            CALC_J:  next_state = READ_J;
            READ_J:  next_state = LATCH_J;
            LATCH_J: next_state = WRITE_I;
            WRITE_I: next_state = WRITE_J;
            WRITE_J: next_state = INC_I;
            INC_I:   next_state = (i == 8'hFF ? DONE : READ_I);
            DONE:    next_state = DONE;
        endcase
    end

    // Combinational Outputs
    always_comb begin
        addr   = 0;
        wrdata = 0;
        wren   = 0;

        case (state)
            READ_I,
            LATCH_I: addr = i;

            READ_J,
            LATCH_J: addr = j;

            WRITE_I: begin addr = i; wrdata = Sj;   wren = 1; end
            WRITE_J: begin addr = j; wrdata = temp; wren = 1; end
        endcase
    end

endmodule
