
module init (input logic clk, input logic rst_n, input logic en, output logic rdy, output logic [7:0] addr, output logic [7:0] wrdata, output logic wren);

    typedef enum logic [1:0] {IDLE, START, WRITE, DONE} fsm_var;
    fsm_var state, next_state;    

    always_ff @(posedge clk) begin

        if(!rst_n) begin
            state  <= IDLE;
            //rdy    <= 1;
            rdy    <= 0;
            wren   <= 0;
            addr   <= 8'd0;
            wrdata <= 8'd0;
        end

        else begin 

            state <= next_state;

            case(state)

            IDLE: begin
               //rdy    <= 1;
                rdy    <= 0; 
                wren   <= 0;
                addr   <= 8'd0;
                wrdata <= 8'd0;
            end

            START: begin
                rdy    <= 0;
                wren   <= 1;
                addr   <= 7'd0;
                wrdata <= 8'd0;
            end

            WRITE: begin
                rdy    <= 0;
                wren   <= 1;
                wrdata <= addr+1;

                if(addr == 8'd255) wren <= 0;
                else addr <= (addr == 8'd255) ? addr : addr + 1; // This prevents overflow
            end

            DONE: begin
                rdy <=1; wren <=0; addr <= 8'd0;
            end
    
            endcase

        end
    end

    always_comb begin

        case (state)

            IDLE: next_state = (en) ? START : IDLE;

            START: next_state = WRITE;

            WRITE: next_state = (addr == 8'd255) ? DONE: WRITE;

            DONE: next_state = DONE;
      
        endcase
    end

endmodule: init