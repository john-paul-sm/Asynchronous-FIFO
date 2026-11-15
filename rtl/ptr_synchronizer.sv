module ptr_synchronizer #(
    parameter int DEPTH = 8,
    parameter int ADDRESS_WIDTH = $clog2(DEPTH)
)(
    input logic clk, // local clk
    input logic rst_n,
    input logic [ADDRESS_WIDTH:0] ptr_gray_in, //incoming registered gray pointer
    output logic [ADDRESS_WIDTH:0] ptr_gray_out // synchronized gray pointer / second stage in the 2-FF synchronizer
);

    logic [ADDRESS_WIDTH:0] sync_ff1; // stage 1 in the 2-FF synchronizer

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr_gray_out <= '0;
            sync_ff1 <= '0;
        end
        else begin
            ptr_gray_out <= sync_ff1;
            sync_ff1 <= ptr_gray_in;
        end
    end

endmodule

// This module is to be instantiated twice for two clock domain crossings:
// 1. Read Gray Pointer to the write domain
// 2. Write Gray pointer to the read domain