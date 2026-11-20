interface fifo_write_if #(
    parameter int WIDTH = 32
)(
    input logic wclk,
    input logic wrst_n,
    input logic shared_rst_n
);

    // Write-channel signals

    logic w_en;
    logic [WIDTH-1:0] wdata;
    logic full;
    int unsigned waddr;

    clocking wdriver @(negedge wclk);
        default output #0; // Default skew
        output w_en;
        output wdata;
    endclocking

    clocking wmonitor @(posedge wclk);
        default input #1step; // Default skew
        input w_en;
        input wdata;
        input full;
        input wrst_n;
        input shared_rst_n;
        input waddr;
    endclocking

    modport wdriver_mp (
        clocking wdriver,
        input wclk,
        input shared_rst_n
    );

    modport wmonitor_mp (
        clocking wmonitor,
        input shared_rst_n
    );

endinterface

interface fifo_read_if #(
    parameter int WIDTH = 32
)(
    input logic rclk,
    input logic rrst_n,
    input logic shared_rst_n
);

    // Read-channel signals

    logic r_en;
    logic [WIDTH-1:0] rdata;
    logic empty;
    int unsigned raddr;

    clocking rdriver @(negedge rclk);
        default output #0; // Default skew
        output r_en;
    endclocking

    clocking rmonitor @(posedge rclk);
        default input #1step; // Default skew
        input r_en;
        input empty;
        input rrst_n;
        input shared_rst_n;
        input #0 rdata;
        input raddr;
    endclocking

    modport rdriver_mp (
        clocking rdriver,
        input rclk,
        input shared_rst_n
    );

    modport rmonitor_mp (
        clocking rmonitor,
        input shared_rst_n
    );
    

endinterface
