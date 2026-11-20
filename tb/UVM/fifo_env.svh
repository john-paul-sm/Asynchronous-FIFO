class fifo_env#(int WIDTH = 32) extends uvm_env;
    `uvm_component_param_utils(fifo_env#(WIDTH));

    fifo_cfg cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    write_agent#(WIDTH) wr_agent;
    read_agent#(WIDTH) rd_agent;
    fifo_scoreboard#(WIDTH) scoreboard;
    fifo_coverage#(WIDTH) coverage;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        wr_agent = write_agent#(WIDTH)::type_id::create("write_agent", this);
        rd_agent = read_agent#(WIDTH)::type_id::create("read_agent", this);
        scoreboard = fifo_scoreboard#(WIDTH)::type_id::create("scoreboard", this);
        if (!uvm_config_db#(fifo_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("ENV_CFG", "FIFO environment couldn't obtain its configuration")
        end
        uvm_config_db#(fifo_cfg)::set(this, "coverage", "cfg", cfg);
        coverage = fifo_coverage#(WIDTH)::type_id::create("coverage", this);        
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        wr_agent.monitor.ap.connect(scoreboard.wr_imp);
        rd_agent.monitor.ap.connect(scoreboard.rd_imp);
        wr_agent.monitor.ap.connect(coverage.wr_imp);
        rd_agent.monitor.ap.connect(coverage.rd_imp);        
    endfunction
endclass