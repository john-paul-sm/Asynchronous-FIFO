`timescale 1ns/1ps

module tb_top;

    import uvm_pkg::*;
    import fifo_pkg::*;

    localparam int WIDTH = 32;
    localparam int DEPTH = 8;

    fifo_cfg cfg;

    logic wclk = 1'b0;
    logic rclk = 1'b0;
    logic shared_rst_n;

    initial begin
        cfg = fifo_cfg::type_id::create("cfg");
        cfg.depth = DEPTH;

        // Optional command-line settings override the defaults.
        void'($value$plusargs("WCLK_PERIOD_NS=%f", cfg.wclk_period_ns));
        void'($value$plusargs("RCLK_PERIOD_NS=%f", cfg.rclk_period_ns));
        void'($value$plusargs("RCLK_OFFSET_NS=%f", cfg.rclk_offset_ns));

        if (cfg.wclk_period_ns <= 0.0 || cfg.rclk_period_ns <= 0.0) begin
            $fatal(1, "Clock periods must be greater than zero");
        end

        if (cfg.rclk_offset_ns < 0.0) begin
            $fatal(1, "Read-clock offset must be nonnegative");
        end

        wclk = 1'b0;
        rclk = 1'b0;
        shared_rst_n = 1'b0;

        uvm_config_db#(fifo_cfg)::set(null, "uvm_test_top.env", "cfg", cfg);

        uvm_config_db#(virtual fifo_write_if#(WIDTH).wdriver_mp)::set(null, "uvm_test_top.env.write_agent.driver", "vif", write_if);
        uvm_config_db#(virtual fifo_read_if#(WIDTH).rdriver_mp)::set(null, "uvm_test_top.env.read_agent.driver", "vif", read_if);
        uvm_config_db#(virtual fifo_write_if#(WIDTH).wmonitor_mp)::set(null, "uvm_test_top.env.write_agent.monitor", "vif", write_if);
        uvm_config_db#(virtual fifo_read_if#(WIDTH).rmonitor_mp)::set(null, "uvm_test_top.env.read_agent.monitor", "vif", read_if);

        $display("CLOCK_CFG wclk_period=%0.3f ns rclk_period=%0.3f ns rclk_offset=%0.3f ns", cfg.wclk_period_ns, cfg.rclk_period_ns, cfg.rclk_offset_ns);

        fork
            begin
                forever begin
                    #(cfg.wclk_period_ns * 1ns / 2.0);
                    wclk = ~wclk;
                end
            end

            begin
                if (cfg.rclk_offset_ns > 0.0) begin
                    #(cfg.rclk_offset_ns * 1ns);
                end

                forever begin
                    #(cfg.rclk_period_ns * 1ns / 2.0);
                    rclk = ~rclk;
                end
            end

            begin
                #50ns;
                shared_rst_n = 1'b1;
            end

            begin
                uvm_top.set_timeout(1us);
                run_test("fifo_base_test");
            end
        join
    end

    // Instantiate write and read interfaces

    fifo_write_if #(.WIDTH(WIDTH)) write_if (.wclk(wclk), .wrst_n(dut.wrst_n), .shared_rst_n(shared_rst_n));
    fifo_read_if #(.WIDTH(WIDTH)) read_if (.rclk(rclk), .rrst_n(dut.rrst_n), .shared_rst_n(shared_rst_n));

    // Connect DUT

    fifo_top #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .shared_rst_n(shared_rst_n),
        .wclk(wclk),
        .w_en(write_if.w_en),
        .wdata(write_if.wdata),
        .rclk(rclk),
        .r_en(read_if.r_en),
        .rdata(read_if.rdata),
        .full(write_if.full),
        .empty(read_if.empty)
    );

    assign write_if.waddr = int'(dut.waddr);
    assign read_if.raddr = int'(dut.raddr);

endmodule