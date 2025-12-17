module doublecrack(input logic clk, input logic rst_n,
             input logic en, output logic rdy,
             output logic [23:0] key, output logic key_valid,
             output logic [7:0] ct_addr, input logic [7:0] ct_rddata);

    // Internal signals
    logic rdy1, rdy2;
    logic key_valid1, key_valid2;
    logic [23:0] key1, key2;
    
    logic [7:0] ct_addr1, ct_addr2;
    
    // Control signals - SIMPLE SOLUTION
    logic found_key;
    
    logic global_stop;

    assign global_stop = found_key;  // stop everyone

    // crack enable = en AND not global_stop
    logic crack_en;
    assign crack_en = en && !global_stop;

    // Instantiating both crack modules
    crack c1(
        .clk(clk),
        .rst_n(rst_n),
        .en(crack_en),     // Stop when key found
        .start_key(24'h000000),    // Even keys
        .step_key(24'd2),
        .stop(global_stop),
        .rdy(rdy1),
        .key(key1),
        .key_valid(key_valid1),
        .ct_addr(ct_addr1),
        .ct_rddata(ct_rddata)
    );
    
    crack c2(
        .clk(clk),
        .rst_n(rst_n),
        .en(crack_en),     // Stop when key found
        .start_key(24'h000001),    // Odd keys
        .step_key(24'd2),
        .stop(global_stop),
        .rdy(rdy2),
        .key(key2),
        .key_valid(key_valid2),
        .ct_addr(ct_addr2),
        .ct_rddata(ct_rddata)
    );
    
    // Detect when either finds a key
    assign found_key = key_valid1 || key_valid2;
    
    // Output logic - Simple
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdy <= 1'b0;
            key_valid <= 1'b0;
            key <= 24'h000000;
        end else begin
            if (found_key) begin
                // Key found by either module
                rdy <= 1'b1;
                key_valid <= 1'b1;
                key <= key_valid1 ? key1 : key2;
            end else if (rdy1 && rdy2) begin
                // Both finished, no key found
                rdy <= 1'b1;
                key_valid <= 1'b0;
                key <= 24'h000000;
            end else begin
                rdy <= 1'b0;
                key_valid <= 1'b0;
            end
        end
    end
    
    // Ciphertext
    always_comb begin
        // Priority to c1
        ct_addr = ct_addr1;
        if (ct_addr1 == 8'd0 && ct_addr2 != 8'd0) begin
            ct_addr = ct_addr2;
        end
    end
    
endmodule: doublecrack