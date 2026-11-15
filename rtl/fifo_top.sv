module fifo_top #(
    parameter int WIDTH = 32,
    parameter int DEPTH = 8,
    parameter int ADDRESS_WIDTH = $clog2(DEPTH)
)(
    input logic shared_rst_n, // shared asynchronouss reset active low
    input logic wclk,
    input logic w_en,
    input logic [WIDTH-1:0] wdata,
    input logic rclk,
    input logic r_en,
    output logic [WIDTH-1:0] rdata,
    output logic full,
    output logic empty
);

    logic wrst_n, rrst_n; 
    logic [ADDRESS_WIDTH-1:0] waddr, raddr;
    logic [ADDRESS_WIDTH:0] wptr_gray, rptr_gray;
    logic [ADDRESS_WIDTH:0] wptr_sync, rptr_sync; // wptr_sync = write gray pointer received in the read domain, rptr_sync = read gray pointer in the write domain

    rst_synchronizer wr_rst_sync (
        .clk(wclk),
        .shared_rst_n(shared_rst_n),
        .local_rst_n(wrst_n)
    );

    rst_synchronizer rd_rst_sync (
        .clk(rclk),
        .shared_rst_n(shared_rst_n),
        .local_rst_n(rrst_n)
    );

    wptr_handler #(
        .DEPTH(DEPTH),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
    ) u_wptr_handler (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .w_en(w_en),
        .rptr_sync(rptr_sync),
        .waddr(waddr),
        .wptr_gray(wptr_gray),
        .full(full)
    );

    rptr_handler #(
        .DEPTH(DEPTH),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
    ) u_rptr_handler (
        .rclk(rclk),
        .rrst_n(rrst_n),
        .r_en(r_en),
        .wptr_sync(wptr_sync),
        .raddr(raddr),
        .rptr_gray(rptr_gray),
        .empty(empty)
    );

    ptr_synchronizer #(
        .DEPTH(DEPTH),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
    ) u_wptr_synchronizer (
        .clk(rclk),
        .rst_n(rrst_n),
        .ptr_gray_in(wptr_gray),
        .ptr_gray_out(wptr_sync)
    );

    ptr_synchronizer #(
        .DEPTH(DEPTH),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
    ) u_rptr_synchronizer (
        .clk(wclk),
        .rst_n(wrst_n),
        .ptr_gray_in(rptr_gray),
        .ptr_gray_out(rptr_sync)
    );

    fifo_mem #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
    ) u_fifo_mem (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .wreq(w_en),
        .full(full),
        .waddr(waddr),
        .wdata(wdata),
        .rclk(rclk),
        .rrst_n(rrst_n),
        .rreq(r_en),
        .empty(empty),
        .raddr(raddr),
        .rdata(rdata)
    );

endmodule