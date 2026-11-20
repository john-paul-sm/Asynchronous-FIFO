class write_sequence #(int WIDTH = 32) extends uvm_sequence#(write_item#(WIDTH));
    `uvm_object_param_utils(write_sequence#(WIDTH));

    function new (string name = "write_sequence");
        super.new(name);
    endfunction

    virtual task body();
        write_item#(WIDTH) req;
        req = write_item#(WIDTH)::type_id::create("req");
        start_item(req);

        if (!req.randomize()) begin
            `uvm_fatal("WRITE_RANDOMIZE", "The write request was not randomized.");
        end

        finish_item(req);
    endtask
endclass

class read_sequence extends uvm_sequence#(read_item);
    `uvm_object_utils(read_sequence);

    function new (string name = "read_sequence");
        super.new(name);
    endfunction

    virtual task body();
        read_item req;
        req = read_item::type_id::create("req");
        start_item(req);

        if (!req.randomize()) begin
            `uvm_fatal("READ_RANDOMIZE", "The read request was not randomized.");
        end

        finish_item(req);
    endtask
endclass