module crack(input logic clk, input logic rst_n,
             input logic en, input logic[23:0] start_key, 
             input logic [23:0] step_key,
             input logic stop, 
             output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata);

    typedef enum logic [3:0] {
        S_WAIT_EN,
        S_START_ARC4,
        S_RESET_ARC4,
        S_WAIT_ARC4_DONE,
        S_REQ_LEN,
        S_GET_LEN,
        S_REQ_WORD,
        S_GET_WORD,
        S_CHECK_WORD,
        S_INC_KEY,
        S_DONE_VALID,
        S_DONE_FAIL
    } fsm_var;

    fsm_var state, next_state;

    logic [23:0] key_reg;
    logic [7:0] index;
    logic [7:0] message_length;
    logic [7:0] word_reg;

    logic rdy_reg;
    logic key_valid_reg;

    assign rdy = rdy_reg;
    assign key_valid = key_valid_reg;
    assign key = key_reg;

    logic [7:0] pt_addr_mem;
    logic [7:0] pt_rddata_mem;
    logic [7:0] pt_wrdata_mem;
    logic pt_wren_mem;

    pt_mem pt (
        .address(pt_addr_mem),
        .clock(clk),
        .data(pt_wrdata_mem),
        .wren(pt_wren_mem),
        .q(pt_rddata_mem)
    );

    logic en_arc4;
    logic rdy_arc4;
    logic rst_n_arc4;
    logic [7:0] ct_addr_arc4;
    logic [7:0] ct_rddata_arc4;
    logic [7:0] pt_addr_arc4;
    logic [7:0] pt_rddata_arc4;
    logic [7:0] pt_wrdata_arc4;
    logic pt_wren_arc4;

    arc4 a4 (
        .clk(clk),
        .rst_n(rst_n_arc4),
        .en(en_arc4),
        .rdy(rdy_arc4),
        .key(key_reg),
        .ct_addr(ct_addr_arc4),
        .ct_rddata(ct_rddata_arc4),
        .pt_addr(pt_addr_arc4),
        .pt_rddata(pt_rddata_arc4),
        .pt_wrdata(pt_wrdata_arc4),
        .pt_wren(pt_wren_arc4)
    );

    assign ct_rddata_arc4 = ct_rddata;
    assign pt_rddata_arc4 = pt_rddata_mem;

    // First always block
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state            <= S_WAIT_EN;
            key_reg          <= 24'h000000;
            index            <= 8'd0;
            message_length   <= 8'd0;
            word_reg         <= 8'd0;
            rdy_reg          <= 1'b0;
            key_valid_reg    <= 1'b0;
        end 
        
        else begin
            
            // Freeze logic
            if (!stop) begin
                // Allow FSM to advance
                state <= next_state;

                case (state)

                    S_WAIT_EN: begin
                        rdy_reg       <= 1'b0;
                        key_valid_reg <= 1'b0;
                        if (en) begin
                            key_reg        <= start_key;
                            index          <= 8'd0;
                            message_length <= 8'd0;
                            word_reg       <= 8'd0;
                        end
                    end

                    S_START_ARC4: begin
                        rdy_reg       <= 1'b0;
                        key_valid_reg <= 1'b0;
                    end

                    S_GET_LEN: begin
                        message_length <= ct_rddata;
                        index <= 8'd1;
                    end

                    S_GET_WORD: begin
                        word_reg <= pt_rddata_mem;
                    end

                    S_CHECK_WORD: begin
                        if ((word_reg >= 8'h20) && (word_reg <= 8'h7E))
                            index <= index + 1;
                    end

                    S_INC_KEY: begin
                        if (key_reg <= 24'hFFFFFF - step_key)
                            key_reg <= key_reg + step_key;
                        else
                            key_reg <= 24'hFFFFFF;
                    end

                    S_DONE_VALID: begin
                        rdy_reg       <= 1'b1;
                        key_valid_reg <= 1'b1;
                    end

                    S_DONE_FAIL: begin
                        rdy_reg       <= 1'b1;
                        key_valid_reg <= 1'b0;
                    end

                endcase

            end 

        end
    end


    // Second Combinational Logic Block
    always_comb begin
        next_state = state;

        unique case (state)

            S_WAIT_EN:
                next_state = en ? S_RESET_ARC4 : S_WAIT_EN;

            S_RESET_ARC4:
                next_state = S_START_ARC4;

            S_START_ARC4:
                next_state = S_WAIT_ARC4_DONE;

            S_WAIT_ARC4_DONE:
                next_state = rdy_arc4 ? S_REQ_LEN : S_WAIT_ARC4_DONE;

            S_REQ_LEN:
                next_state = S_GET_LEN;

            S_GET_LEN:
                next_state = (message_length == 0) ? S_INC_KEY : S_REQ_WORD;

            S_REQ_WORD:
                next_state = S_GET_WORD;

            S_GET_WORD:
                next_state = S_CHECK_WORD;

            S_CHECK_WORD: begin
                if (word_reg >= 8'h20 && word_reg <= 8'h7E) begin
                    if (index == message_length)
                        next_state = S_DONE_VALID;
                    else
                        next_state = S_REQ_WORD;
                end else begin
                    next_state = S_INC_KEY;
                end
            end

            S_INC_KEY:
                next_state = (key_reg == 24'hFFFFFF) ? S_DONE_FAIL : S_RESET_ARC4;

            S_DONE_VALID:
                next_state = S_DONE_VALID;

            S_DONE_FAIL:
                next_state = S_DONE_FAIL;

            default:
                next_state = S_WAIT_EN;

        endcase
    end

    // Third logic block (combinational) for the task outputs
    always_comb begin
        // defaults
        en_arc4     = 1'b0;
        rst_n_arc4  = 1'b1;     // *** CRITICAL DEFAULT ***
        ct_addr     = ct_addr_arc4;
        pt_addr_mem = pt_addr_arc4;
        pt_wrdata_mem = pt_wrdata_arc4;
        pt_wren_mem   = pt_wren_arc4;

        case (state)

            S_RESET_ARC4: begin
                rst_n_arc4 = 1'b0;   // assert reset for 1 cycle
            end

            S_START_ARC4: begin
                en_arc4 = 1'b1;      // start ARC4
                rst_n_arc4 = 1'b1;   // release reset
            end

            S_REQ_LEN,
            S_GET_LEN: begin
                ct_addr = 8'd0;
            end

            S_REQ_WORD,
            S_GET_WORD,
            S_CHECK_WORD: begin
                pt_addr_mem = index;
                pt_wren_mem = 1'b0;
                pt_wrdata_mem = 8'd0;
            end

            S_DONE_VALID,
            S_DONE_FAIL: begin
                pt_wren_mem = 1'b0;
            end

        endcase
    end

endmodule
