module fifo_mem #(
    parameter int WIDTH = 32,
    parameter int DEPTH = 8,
    parameter int ADDRESS_WIDTH = $clog2(DEPTH)
)(
    input logic wclk,
    input logic wrst_n,
    input logic wreq, // write request
    input logic full,
    input logic [ADDRESS_WIDTH-1:0] waddr,
    input logic [WIDTH-1:0] wdata,

    input logic rclk,
    input logic rrst_n,
    input logic rreq, //read request
    input logic empty,
    input logic [ADDRESS_WIDTH-1:0] raddr,
    output logic [WIDTH-1:0] rdata
);

    logic [WIDTH-1:0] storage [0:DEPTH-1];

    always_ff @(posedge wclk) begin
        if (wrst_n && wreq && !full) begin
            storage[waddr] <= wdata;
        end
    end

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rdata <= '0;
        end
        else if (rreq && !empty) begin
            rdata <= storage[raddr];
        end
    end

endmodule