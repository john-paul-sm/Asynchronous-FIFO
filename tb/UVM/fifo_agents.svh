// Drivers

class write_driver #(int WIDTH = 32) extends uvm_driver#(write_item#(WIDTH));
    `uvm_component_param_utils(write_driver#(WIDTH));

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // vif = handle for the virtual interface

    virtual fifo_write_if#(WIDTH).wdriver_mp vif;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual fifo_write_if#(WIDTH).wdriver_mp)::get(this, "", "vif", vif)) begin
            `uvm_fatal("WRITE_VIF", "Write driver  couldn't obtain its interface");
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        write_item#(WIDTH) req;
        int unsigned idle_count;
        bit attempt;

        forever begin
            @(vif.wdriver); // Wait

            attempt = 0;

            // If there is no item being processed, try the next item

            if (vif.shared_rst_n) begin
                if (req == null) begin
                    seq_item_port.try_next_item(req);
                    if (req != null) begin
                        idle_count = req.idle_cycles;
                    end
                end

                // If there is an item pending AND not during an idle cycle, mark it as an attempt

                if (req == null) begin
                    attempt = 0;
                end else if (idle_count > 0) begin
                    attempt = 0;
                    idle_count = idle_count - 1;
                end else if (idle_count == 0) begin
                    attempt = 1;
                end
            end

            vif.wdriver.w_en <= attempt;

            if (attempt) begin
                vif.wdriver.wdata <= req.data;
            end else begin
                vif.wdriver.wdata <= 0;
            end

            @(posedge vif.wclk);

            if (attempt) begin
                seq_item_port.item_done();
                req = null;
            end
        end
    endtask
endclass

class read_driver#(int WIDTH = 32) extends uvm_driver#(read_item);
    `uvm_component_param_utils(read_driver#(WIDTH));

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual fifo_read_if#(WIDTH).rdriver_mp vif;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual fifo_read_if#(WIDTH).rdriver_mp)::get(this, "", "vif", vif)) begin
            `uvm_fatal("READ_VIF", "Read driver  couldn't obtain its interface");
        end        
    endfunction

    virtual task run_phase(uvm_phase phase);
        read_item req;
        int unsigned idle_count;
        bit attempt;

        forever begin
            @(vif.rdriver);

            attempt = 0;

            if (vif.shared_rst_n) begin
                if (req == null) begin
                    seq_item_port.try_next_item(req);
                    if (req != null) begin
                        idle_count = req.idle_cycles;
                    end
                end

                if (req == null) begin
                    attempt = 0;
                end else if (idle_count > 0) begin
                    attempt = 0;
                    idle_count = idle_count - 1;
                end else if (idle_count == 0) begin
                    attempt = 1;
                end
            end

            vif.rdriver.r_en <= attempt;

            @(posedge vif.rclk);

            if (attempt) begin
                seq_item_port.item_done();
                req = null;
            end
        end
    endtask
endclass

// Sequencers

class write_sequencer#(int WIDTH = 32) extends uvm_sequencer#(write_item#(WIDTH));
    `uvm_component_param_utils(write_sequencer#(WIDTH));

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

class read_sequencer extends uvm_sequencer#(read_item);
    `uvm_component_utils(read_sequencer);

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

// Monitors -- observes what happens on the interface

class write_monitor#(int WIDTH = 32) extends uvm_monitor;
    `uvm_component_param_utils(write_monitor#(WIDTH));

    virtual fifo_write_if#(WIDTH).wmonitor_mp vif;
    uvm_analysis_port#(write_observation#(WIDTH)) ap;

    function new (string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual fifo_write_if#(WIDTH).wmonitor_mp)::get(this, "", "vif", vif)) begin
            `uvm_fatal("WRITE_VIF", "Write monitor couldn't obtain its interface");
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        write_observation#(WIDTH) observation;

        forever begin
            @(vif.wmonitor);

            observation = write_observation#(WIDTH)::type_id::create("observation");

            observation.wdata = vif.wmonitor.wdata;
            observation.w_en = vif.wmonitor.w_en;
            observation.full = vif.wmonitor.full;
            observation.wrst_n = vif.wmonitor.wrst_n;
            observation.shared_rst_n = vif.wmonitor.shared_rst_n;
            observation.waddr = vif.wmonitor.waddr;

            observation.accepted = observation.wrst_n && observation.w_en && !observation.full;       

            ap.write(observation);
        end
    endtask
endclass

class read_monitor#(int WIDTH = 32) extends uvm_monitor;
    `uvm_component_param_utils(read_monitor#(WIDTH));

    virtual fifo_read_if#(WIDTH).rmonitor_mp vif;
    uvm_analysis_port#(read_observation#(WIDTH)) ap;

    function new (string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual fifo_read_if#(WIDTH).rmonitor_mp)::get(this, "", "vif", vif)) begin
            `uvm_fatal("READ_VIF", "Read monitor couldn't obtain its interface");
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        read_observation#(WIDTH) observation;

        forever begin
            @(vif.rmonitor);

            observation = read_observation#(WIDTH)::type_id::create("observation");

            observation.rdata = vif.rmonitor.rdata;
            observation.r_en = vif.rmonitor.r_en;
            observation.empty = vif.rmonitor.empty;
            observation.rrst_n = vif.rmonitor.rrst_n;
            observation.shared_rst_n = vif.rmonitor.shared_rst_n;
            observation.raddr = vif.rmonitor.raddr;

            observation.accepted = observation.rrst_n && observation.r_en && !observation.empty;       

            ap.write(observation);
        end
    endtask
endclass

// Agents

class write_agent#(int WIDTH = 32) extends uvm_agent;
    `uvm_component_param_utils(write_agent#(WIDTH));

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    write_driver#(WIDTH) driver;
    write_sequencer#(WIDTH) sequencer;
    write_monitor#(WIDTH) monitor;    

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver = write_driver#(WIDTH)::type_id::create("driver", this);
        sequencer = write_sequencer#(WIDTH)::type_id::create("sequencer", this);
        monitor = write_monitor#(WIDTH)::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass

class read_agent#(int WIDTH = 32) extends uvm_agent;
    `uvm_component_param_utils(read_agent#(WIDTH));

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    read_driver#(WIDTH) driver;
    read_sequencer sequencer;
    read_monitor#(WIDTH) monitor;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver = read_driver#(WIDTH)::type_id::create("driver", this);
        sequencer = read_sequencer::type_id::create("sequencer", this);
        monitor = read_monitor#(WIDTH)::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass


