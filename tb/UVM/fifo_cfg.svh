class fifo_cfg extends uvm_object;
    `uvm_object_utils(fifo_cfg);

    real wclk_period_ns = 10.0;
    real rclk_period_ns = 14.0;
    real rclk_offset_ns = 2.0;

    int unsigned depth = 8;

    function new(string name = "fifo_cfg");
        super.new(name);
    endfunction
endclass