module prga(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,
    output logic        rdy,
    input  logic [23:0] key,
    output logic [7:0]  s_addr,
    input  logic [7:0]  s_rddata,
    output logic [7:0]  s_wrdata,
    output logic        s_wren,
    output logic [7:0]  ct_addr,
    input  logic [7:0]  ct_rddata,
    output logic [7:0]  pt_addr,
    input  logic [7:0]  pt_rddata,
    output logic [7:0]  pt_wrdata,
    output logic        pt_wren
);

    typedef enum logic [4:0] {
        IDLE,
        // Read message length
        CT_READ_LEN,
        CT_LATCH_LEN,
        // Write length to PT[0]
        PT_WRITE_LEN,
        // Start of loop for each k
        START_K,
        // Read S[i] where i = i+1
        READ_I_ADDR,
        LATCH_I,
        // Calculate j and read S[j]
        CALC_J,
        READ_J_ADDR,
        LATCH_J,
        // Swap S[i] and S[j]
        WRITE_I_TO_J,
        WRITE_J_TO_I,
        // Read S[t] after swap
        READ_T_ADDR,
        LATCH_T,
        // Write plaintext byte
        WRITE_PT,
        // Next k or done
        NEXT_K_OR_DONE,
        DONE
    } fsm_var;

    fsm_var state, next_state;

    // internal registers
    logic [7:0] i_reg, j_reg;
    logic [7:0] msg_len;
    logic [7:0] k_reg;
    logic [7:0] Si_reg, Sj_reg, St_reg;
    logic [7:0] t_idx;
    logic [7:0] current_i;  // i for this iteration (i+1)
    logic [7:0] ct_data_buf;  // Buffer for ciphertext byte

    // Sequential logic block (State register updates)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            rdy         <= 1'b0;
            i_reg       <= 8'd0;
            j_reg       <= 8'd0;
            msg_len     <= 8'd0;
            k_reg       <= 8'd1;
            Si_reg      <= 8'd0;
            Sj_reg      <= 8'd0;
            St_reg      <= 8'd0;
            t_idx       <= 8'd0;
            current_i   <= 8'd0;
            ct_data_buf <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    rdy <= 1'b0;
                    if (en) begin
                        rdy   <= 1'b0;
                        i_reg <= 8'd0;
                        j_reg <= 8'd0;
                        k_reg <= 8'd1;
                    end
                end

                CT_LATCH_LEN: begin
                    msg_len <= ct_rddata;
                end

                START_K: begin
                    // i = i + 1 for this iteration
                    current_i <= i_reg + 8'd1;
                    i_reg     <= i_reg + 8'd1;  // Store for next iteration
                end

                LATCH_I: begin
                    Si_reg      <= s_rddata;        // Capture S[i]
                    ct_data_buf <= ct_rddata;      // Capture ciphertext[k]
                end

                CALC_J: begin
                    j_reg <= j_reg + Si_reg;       // j = j + S[i]
                end

                LATCH_J: begin
                    Sj_reg <= s_rddata;            // Capture S[j]
                    t_idx  <= Si_reg + s_rddata;   // t = S[i] + S[j]
                end

                LATCH_T: begin
                    St_reg <= s_rddata;            // Capture S[t]
                end

                NEXT_K_OR_DONE: begin
                    if (k_reg != msg_len) begin
                        k_reg <= k_reg + 8'd1;     // Increment k for next byte
                    end
                end

                DONE: begin
                    rdy <= 1'b1;
                end
            endcase
        end
    end

    // 2nd logic block (state updating)
    always_comb begin
        next_state = state;

        case (state)
            IDLE:               next_state = (en ? CT_READ_LEN : IDLE);
            CT_READ_LEN:        next_state = CT_LATCH_LEN;
            CT_LATCH_LEN:       next_state = PT_WRITE_LEN;
            PT_WRITE_LEN:       next_state = START_K;
            START_K:            next_state = READ_I_ADDR;
            READ_I_ADDR:        next_state = LATCH_I;
            LATCH_I:            next_state = CALC_J;
            CALC_J:             next_state = READ_J_ADDR;
            READ_J_ADDR:        next_state = LATCH_J;
            LATCH_J:            next_state = WRITE_I_TO_J;
            WRITE_I_TO_J:       next_state = WRITE_J_TO_I;
            WRITE_J_TO_I:       next_state = READ_T_ADDR;
            READ_T_ADDR:        next_state = LATCH_T;
            LATCH_T:            next_state = WRITE_PT;
            WRITE_PT:           next_state = NEXT_K_OR_DONE;
            NEXT_K_OR_DONE:     next_state = (k_reg == msg_len ? DONE : START_K);
            DONE:               next_state = DONE;
            default:            next_state = IDLE;
        endcase
    end

    // Combinational logic block (outputs)
    always_comb begin
        // Default outputs
        s_addr    = 0;
        s_wrdata  = 0;
        s_wren    = 0;
        ct_addr   = 0;
        pt_addr   = 0;
        pt_wrdata = 0;
        pt_wren   = 0;

        case (state)
            CT_READ_LEN: begin
                ct_addr = 8'd0;  // Read message length from CT[0]
            end

            PT_WRITE_LEN: begin
                pt_addr   = 8'd0;        // Write length to PT[0]
                pt_wrdata = ct_rddata;   // Message length
                pt_wren   = 1;
            end

            READ_I_ADDR: begin
                s_addr  = current_i;     // Read S[i] where i = i+1
                ct_addr = k_reg;         // Read ciphertext[k]
            end

            LATCH_I: begin
                ct_addr = k_reg;         // Keep reading ciphertext[k]
            end

            CALC_J: begin
                // Keep reading ciphertext[k] - needed for registered memory
                ct_addr = k_reg;
            end

            READ_J_ADDR: begin
                s_addr  = j_reg;         // Read S[j]
                ct_addr = k_reg;         // Keep reading ciphertext[k]
            end

            LATCH_J: begin
                ct_addr = k_reg;         // Keep reading ciphertext[k]
            end

            WRITE_I_TO_J: begin
                s_addr   = current_i;    // Write S[j] to S[i] location
                s_wrdata = Sj_reg;
                s_wren   = 1;
                ct_addr  = k_reg;        // Keep reading ciphertext[k]
            end

            WRITE_J_TO_I: begin
                s_addr   = j_reg;        // Write S[i] to S[j] location
                s_wrdata = Si_reg;
                s_wren   = 1;
                ct_addr  = k_reg;        // Keep reading ciphertext[k]
            end

            READ_T_ADDR: begin
                s_addr  = t_idx;         // Read S[t] where t = S[i] + S[j]
                ct_addr = k_reg;         // Keep reading ciphertext[k]
            end

            WRITE_PT: begin
                pt_addr   = k_reg;       // Write plaintext to position k
                pt_wrdata = St_reg ^ ct_data_buf;  // PT = S[t] ^ CT[k]
                pt_wren   = 1;
            end

            default: begin
                // Default case
            end
        endcase
    end

endmodule