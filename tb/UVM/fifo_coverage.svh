`uvm_analysis_imp_decl(_cov_wr)
`uvm_analysis_imp_decl(_cov_rd)

class fifo_coverage#(int WIDTH = 32) extends uvm_component;
    `uvm_component_param_utils(fifo_coverage#(WIDTH));

    localparam int unsigned FULL_REACHED = 0;
    localparam int unsigned EMPTY_REACHED = 1;
    localparam int unsigned WRITE_WRAP = 2;
    localparam int unsigned READ_WRAP = 3;
    localparam int unsigned WRITE_BLOCKED = 4;
    localparam int unsigned READ_BLOCKED = 5;
    localparam int CFG_EQUAL = 0;
    localparam int CFG_WRITE_FAST = 1;
    localparam int CFG_READ_FAST = 2;
    localparam int CFG_NEARBY = 3;

    localparam int OFFSET_ZERO = 0;
    localparam int OFFSET_2P5 = 1;

    int clock_kind;
    int offset_kind;

    fifo_cfg cfg;

    uvm_analysis_imp_cov_wr#(write_observation#(WIDTH), fifo_coverage#(WIDTH)) wr_imp;
    uvm_analysis_imp_cov_rd#(read_observation#(WIDTH), fifo_coverage#(WIDTH)) rd_imp;

    int unsigned event_hits[6];

    bit write_history_valid;
    bit read_history_valid;

    int unsigned previous_waddr;
    int unsigned previous_raddr;

    bit previous_write_accepted;
    bit previous_read_accepted;

    bit previous_full;
    bit previous_empty;

    covergroup events_cg with function sample(int unsigned event_kind, int clock_kind, int offset_kind);
        option.per_instance = 1;
        option.at_least = 1;

        cp_event: coverpoint event_kind {
            bins full_reached = {FULL_REACHED};
            bins empty_reached = {EMPTY_REACHED};
            bins write_wrap = {WRITE_WRAP};
            bins read_wrap = {READ_WRAP};
            bins write_blocked = {WRITE_BLOCKED};
            bins read_blocked = {READ_BLOCKED};
        }

        cp_clock: coverpoint clock_kind {
            bins equal_clocks = {CFG_EQUAL};
            bins write_faster = {CFG_WRITE_FAST};
            bins read_faster = {CFG_READ_FAST};
            bins nearby_periods = {CFG_NEARBY};
        }

        cp_offset: coverpoint offset_kind {
            bins zero_offset = {OFFSET_ZERO};
            bins offset_2p5ns = {OFFSET_2P5};
        }

        event_clock_offset: cross cp_event, cp_clock, cp_offset;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);

        wr_imp = new("wr_imp", this);
        rd_imp = new("rd_imp", this);

        events_cg = new();
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(fifo_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("COV_CFG", "FIFO coverage couldn't obtain its configuration")
        end

        classify_configuration();

        if (clock_kind < 0 || offset_kind < 0) begin
            `uvm_info("COV_OUTSIDE_MATRIX", "Clock settings are outside the planned matrix; event coverage is still collected", UVM_LOW)
        end

    endfunction

    function void record_event(int unsigned event_kind);
        event_hits[event_kind]++;
        events_cg.sample(event_kind, clock_kind, offset_kind);
    endfunction

    function void write_cov_wr(write_observation#(WIDTH) observation);
        if (!observation.shared_rst_n || !observation.wrst_n) begin
            write_history_valid = 0;
            return;
        end

        if (write_history_valid) begin
            if (!previous_full && observation.full) begin
                record_event(FULL_REACHED);
            end

            if (previous_write_accepted &&
                previous_waddr == cfg.depth - 1 &&
                observation.waddr == 0) begin
                record_event(WRITE_WRAP);
            end
        end

        if (observation.w_en && observation.full) begin
            record_event(WRITE_BLOCKED);
        end

        previous_waddr = observation.waddr;
        previous_write_accepted = observation.accepted;
        previous_full = observation.full;

        write_history_valid = 1;
    endfunction

    function void write_cov_rd(read_observation#(WIDTH) observation);
        if (!observation.shared_rst_n || !observation.rrst_n) begin
            read_history_valid = 0;
            return;
        end

        if (read_history_valid) begin
            if (!previous_empty && observation.empty) begin
                record_event(EMPTY_REACHED);
            end

            if (previous_read_accepted &&
                previous_raddr == cfg.depth - 1 &&
                observation.raddr == 0) begin
                record_event(READ_WRAP);
            end
        end

        if (observation.r_en && observation.empty) begin
            record_event(READ_BLOCKED);
        end

        previous_raddr = observation.raddr;
        previous_read_accepted = observation.accepted;
        previous_empty = observation.empty;

        read_history_valid = 1;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("FIFO_COVERAGE", $sformatf("events=%0.2f%% matrix_cross=%0.2f%% full=%0d empty=%0d wwrap=%0d rwrap=%0d wblocked=%0d rblocked=%0d", events_cg.cp_event.get_inst_coverage(), events_cg.event_clock_offset.get_inst_coverage(), event_hits[FULL_REACHED], event_hits[EMPTY_REACHED], event_hits[WRITE_WRAP], event_hits[READ_WRAP], event_hits[WRITE_BLOCKED], event_hits[READ_BLOCKED]), UVM_LOW)
    endfunction

    function void classify_configuration();
        clock_kind = -1;
        offset_kind = -1;

        if (cfg.wclk_period_ns == 10.0 && cfg.rclk_period_ns == 10.0) begin
            clock_kind = CFG_EQUAL;
        end
        else if (cfg.wclk_period_ns == 8.0 && cfg.rclk_period_ns == 20.0) begin
            clock_kind = CFG_WRITE_FAST;
        end
        else if (cfg.wclk_period_ns == 20.0 && cfg.rclk_period_ns == 8.0) begin
            clock_kind = CFG_READ_FAST;
        end
        else if (cfg.wclk_period_ns == 10.0 && cfg.rclk_period_ns == 11.0) begin
            clock_kind = CFG_NEARBY;
        end

        if (cfg.rclk_offset_ns == 0.0) begin
            offset_kind = OFFSET_ZERO;
        end
        else if (cfg.rclk_offset_ns == 2.5) begin
            offset_kind = OFFSET_2P5;
        end
    endfunction

endclass