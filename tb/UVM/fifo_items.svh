class write_item #(int WIDTH = 32) extends uvm_sequence_item;
    `uvm_object_param_utils(write_item#(WIDTH));
    
    rand bit [WIDTH-1:0] data;
    rand int unsigned idle_cycles;

    function new (string name = "write_item");
        super.new(name);
    endfunction

    constraint idle_cycles_range {
        idle_cycles inside {[0:8]};
    }
endclass

class read_item extends uvm_sequence_item;
    `uvm_object_utils(read_item);

    rand int unsigned idle_cycles;

    function new (string name = "read_item");
        super.new(name);
    endfunction

    constraint idle_cycles_range {
        idle_cycles inside {[0:8]};
    }
endclass

class write_observation#(int WIDTH = 32) extends uvm_sequence_item;
    `uvm_object_param_utils(write_observation#(WIDTH));

    logic [WIDTH-1:0] wdata; // observed data
    logic w_en; // sampled request
    logic full; // sampled boundary flag
    logic wrst_n; // sampled local reset
    logic shared_rst_n; // sampled shared reset
    logic accepted; // whether the operation was accepted
    int unsigned waddr;

    function new (string name = "write_observation");
        super.new(name);
    endfunction
endclass

class read_observation#(int WIDTH = 32) extends uvm_sequence_item;
    `uvm_object_param_utils(read_observation#(WIDTH));

    logic [WIDTH-1:0] rdata; // observed data
    logic r_en; // sampled request
    logic empty; // sampled boundary flag
    logic rrst_n; // sampled local reset
    logic shared_rst_n; // sampled shared reset
    logic accepted; // whether the operation was accepted
    int unsigned raddr;

    function new (string name = "read_observation");
        super.new(name);
    endfunction
endclass