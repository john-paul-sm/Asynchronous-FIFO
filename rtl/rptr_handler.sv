module rptr_handler #(
    parameter int DEPTH = 8,
    parameter int ADDRESS_WIDTH = $clog2(DEPTH)
)(
    input logic rclk,
    input logic rrst_n,
    input logic r_en,
    input logic [ADDRESS_WIDTH:0] wptr_sync,
    output logic [ADDRESS_WIDTH-1:0] raddr,
    output logic [ADDRESS_WIDTH:0] rptr_gray,
    output logic empty
);

    logic next_empty;
    logic [ADDRESS_WIDTH:0] rptr_bin, next_rptr_bin;
    logic [ADDRESS_WIDTH:0] next_rptr_gray;

    assign next_rptr_bin = (rrst_n && r_en && !empty) ? rptr_bin + 1 : rptr_bin;
    assign next_rptr_gray = next_rptr_bin ^ (next_rptr_bin >> 1);

    assign raddr = rptr_bin[ADDRESS_WIDTH-1:0];

    // The FIFO is empty when both the Read and Write Pointers are equal including the wrap bit

    assign next_empty = wptr_sync == next_rptr_gray;

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin <= '0;
            rptr_gray <= '0;
            empty <= 1'b1;
        end
        else begin
            rptr_bin <= next_rptr_bin;
            rptr_gray <= next_rptr_gray;
            empty <= next_empty;
        end
    end

endmodule