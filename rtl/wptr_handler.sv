module wptr_handler #(
    parameter int DEPTH = 8,
    parameter int ADDRESS_WIDTH = $clog2(DEPTH)
)(
    input logic wclk,
    input logic wrst_n,
    input logic w_en,
    input logic [ADDRESS_WIDTH:0] rptr_sync,
    output logic [ADDRESS_WIDTH-1:0] waddr,
    output logic [ADDRESS_WIDTH:0] wptr_gray,
    output logic full
);

    logic next_full;
    logic [ADDRESS_WIDTH:0] wptr_bin, next_wptr_bin;
    logic [ADDRESS_WIDTH:0] next_wptr_gray;

    assign next_wptr_bin = (wrst_n && w_en && !full) ? wptr_bin + 1'b1 : wptr_bin;
    assign next_wptr_gray = next_wptr_bin ^ (next_wptr_bin >> 1);

    assign waddr = wptr_bin[ADDRESS_WIDTH-1:0];


    /*
    The FIFO is full if EACH bit of the next write pointer (gray code) is equal to the synchronized read pointer's gray code with the top 2 BITS inverted.
    */

    assign next_full = next_wptr_gray == {~rptr_sync[ADDRESS_WIDTH:ADDRESS_WIDTH-1], rptr_sync[ADDRESS_WIDTH-2:0]};

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin <= '0;
            wptr_gray <= '0;
            full <= 1'b0;
        end
        else begin
            wptr_bin <= next_wptr_bin;
            wptr_gray <= next_wptr_gray;
            full <= next_full;
        end
    end

endmodule