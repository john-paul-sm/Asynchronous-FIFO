class fifo_base_test extends uvm_test;
    `uvm_component_utils(fifo_base_test);

    localparam int WIDTH = 32;

    fifo_env#(WIDTH) env;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fifo_env#(WIDTH)::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        // Wait until both clock domains have completed reset recovery.
        wait (env.wr_agent.monitor.vif.wmonitor.wrst_n && env.rd_agent.monitor.vif.rmonitor.rrst_n);

        // Observe four additional write-clock cycles.
        repeat (4) @(env.wr_agent.monitor.vif.wmonitor);

        phase.drop_objection(this);
    endtask
endclass

class fifo_smoke_test extends fifo_base_test;
    `uvm_component_utils(fifo_smoke_test);

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        write_sequence#(WIDTH) write_seq;
        read_sequence read_seq;

        phase.raise_objection(this);

        // Both domains must finish reset recovery before traffic.
        wait (env.wr_agent.monitor.vif.wmonitor.wrst_n && env.rd_agent.monitor.vif.rmonitor.rrst_n);

        write_seq = write_sequence#(WIDTH)::type_id::create("write_seq");
        read_seq = read_sequence::type_id::create("read_seq");

        `uvm_info("SMOKE", "Starting one write", UVM_LOW)

        write_seq.start(env.wr_agent.sequencer);

        // Confirm that the monitor recorded an accepted write.
        wait (env.scoreboard.writes_seen >= 1);

        // Wait for the write pointer to become visible in the read domain.
        wait (env.rd_agent.monitor.vif.rmonitor.empty === 1'b0);

        `uvm_info("SMOKE", "Starting one read", UVM_LOW)

        read_seq.start(env.rd_agent.sequencer);

        wait (env.scoreboard.reads_seen >= 1);

        // Allow the accepted-read observation to finish processing.
        @(env.rd_agent.monitor.vif.rmonitor);

        if (env.scoreboard.writes_seen != 1 || env.scoreboard.reads_seen != 1 || env.scoreboard.matches_seen != 1 || env.scoreboard.expected_data.size() != 0) begin
            `uvm_error("SMOKE_COUNTS", $sformatf("Expected one write/read/match and no pending data: writes=%0d reads=%0d matches=%0d pending=%0d", env.scoreboard.writes_seen, env.scoreboard.reads_seen, env.scoreboard.matches_seen, env.scoreboard.expected_data.size()))
        end
        else begin
            `uvm_info("SMOKE_CHECK", "One accepted write, one accepted read, and one data match", UVM_LOW)
        end

        phase.drop_objection(this);
    endtask
endclass

class fifo_fill_drain_test extends fifo_base_test;
    `uvm_component_utils(fifo_fill_drain_test);

    localparam int DEPTH = 8;
    localparam int CYCLES = 2;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_top.set_timeout(10us);
    endfunction

    virtual task run_phase(uvm_phase phase);
        write_sequence#(WIDTH) write_seq;
        read_sequence read_seq;
        int unsigned target_count;

        phase.raise_objection(this);

        wait (env.wr_agent.monitor.vif.wmonitor.wrst_n && env.rd_agent.monitor.vif.rmonitor.rrst_n);

        for (int cycle = 0; cycle < CYCLES; cycle++) begin
            target_count = (cycle + 1) * DEPTH;

            `uvm_info("FILL_DRAIN", $sformatf("Cycle %0d: filling the FIFO", cycle + 1), UVM_LOW)

            for (int i = 0; i < DEPTH; i++) begin
                wait (env.wr_agent.monitor.vif.wmonitor.full === 1'b0);

                write_seq = write_sequence#(WIDTH)::type_id::create($sformatf("write_%0d_%0d", cycle, i));
                write_seq.start(env.wr_agent.sequencer);

                repeat (2) @(env.wr_agent.monitor.vif.wmonitor);
            end

            if (env.scoreboard.writes_seen != target_count || env.scoreboard.expected_data.size() != DEPTH || env.wr_agent.monitor.vif.wmonitor.full !== 1'b1) begin
                `uvm_fatal("FILL_CHECK", $sformatf("Cycle %0d: writes=%0d target=%0d pending=%0d full=%b", cycle + 1, env.scoreboard.writes_seen, target_count, env.scoreboard.expected_data.size(), env.wr_agent.monitor.vif.wmonitor.full))
            end

            after_fill();

            `uvm_info("FILL_DRAIN", $sformatf("Cycle %0d: draining the FIFO", cycle + 1), UVM_LOW)

            for (int i = 0; i < DEPTH; i++) begin
                wait (env.rd_agent.monitor.vif.rmonitor.empty === 1'b0);

                read_seq = read_sequence::type_id::create($sformatf("read_%0d_%0d", cycle, i));
                read_seq.start(env.rd_agent.sequencer);

                repeat (2) @(env.rd_agent.monitor.vif.rmonitor);
            end

            if (env.scoreboard.reads_seen != target_count || env.scoreboard.matches_seen != target_count || env.scoreboard.expected_data.size() != 0 || env.rd_agent.monitor.vif.rmonitor.empty !== 1'b1) begin
                `uvm_fatal("DRAIN_CHECK", $sformatf("Cycle %0d: reads=%0d matches=%0d target=%0d pending=%0d empty=%b", cycle + 1, env.scoreboard.reads_seen, env.scoreboard.matches_seen, target_count, env.scoreboard.expected_data.size(), env.rd_agent.monitor.vif.rmonitor.empty))
            end

            after_drain();

            `uvm_info("FILL_DRAIN", $sformatf("Cycle %0d completed with %0d total matching reads", cycle + 1, env.scoreboard.matches_seen), UVM_LOW)
        end

        phase.drop_objection(this);
    endtask

    virtual task after_fill();
    endtask

    virtual task after_drain();
    endtask
endclass

class fifo_boundary_test extends fifo_fill_drain_test;
    `uvm_component_utils(fifo_boundary_test);

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task after_fill();
        write_sequence#(WIDTH) extra_write;
        int unsigned writes_before;
        int unsigned rejected_before;

        writes_before = env.scoreboard.writes_seen;
        rejected_before = env.scoreboard.writes_rejected;

        // Deliberately request a write while full.
        extra_write = write_sequence#(WIDTH)::type_id::create("extra_write");
        extra_write.start(env.wr_agent.sequencer);

        repeat (2) @(env.wr_agent.monitor.vif.wmonitor);

        if (env.scoreboard.writes_seen != writes_before || env.scoreboard.writes_rejected != rejected_before + 1 || env.scoreboard.expected_data.size() != DEPTH || env.wr_agent.monitor.vif.wmonitor.full !== 1'b1) begin
            `uvm_fatal("BLOCKED_WRITE", $sformatf("Unexpected response to full-FIFO write: writes=%0d rejected=%0d pending=%0d full=%b", env.scoreboard.writes_seen, env.scoreboard.writes_rejected, env.scoreboard.expected_data.size(), env.wr_agent.monitor.vif.wmonitor.full))
        end

        `uvm_info("BLOCKED_WRITE", "Full-FIFO write request observed; accepted count and queue size unchanged", UVM_LOW)
    endtask

    virtual task after_drain();
        read_sequence extra_read;
        int unsigned reads_before;
        int unsigned rejected_before;
        logic [WIDTH-1:0] data_before;

        reads_before = env.scoreboard.reads_seen;
        rejected_before = env.scoreboard.reads_rejected;
        data_before = env.rd_agent.monitor.vif.rmonitor.rdata;

        // Deliberately request a read while empty.
        extra_read = read_sequence::type_id::create("extra_read");
        extra_read.start(env.rd_agent.sequencer);

        repeat (2) @(env.rd_agent.monitor.vif.rmonitor);

        if (env.scoreboard.reads_seen != reads_before || env.scoreboard.matches_seen != reads_before || env.scoreboard.reads_rejected != rejected_before + 1 || env.scoreboard.expected_data.size() != 0 || env.rd_agent.monitor.vif.rmonitor.empty !== 1'b1 || env.rd_agent.monitor.vif.rmonitor.rdata !== data_before) begin
            `uvm_fatal("BLOCKED_READ", $sformatf("Unexpected response to empty-FIFO read: reads=%0d matches=%0d rejected=%0d pending=%0d empty=%b data_before=0x%0h data_after=0x%0h", env.scoreboard.reads_seen, env.scoreboard.matches_seen, env.scoreboard.reads_rejected, env.scoreboard.expected_data.size(), env.rd_agent.monitor.vif.rmonitor.empty, data_before, env.rd_agent.monitor.vif.rmonitor.rdata))
        end

        `uvm_info("BLOCKED_READ", "Empty-FIFO read request observed; accepted count and read output unchanged", UVM_LOW)
    endtask
endclass

class fifo_concurrent_test extends fifo_base_test;
    `uvm_component_utils(fifo_concurrent_test);

    localparam int NUM_WORDS = 32;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_top.set_timeout(20us);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        wait (env.wr_agent.monitor.vif.wmonitor.wrst_n && env.rd_agent.monitor.vif.rmonitor.rrst_n);

        `uvm_info("CONCURRENT", $sformatf("Starting %0d writes and %0d reads concurrently", NUM_WORDS, NUM_WORDS), UVM_LOW)

        fork
            begin
                write_sequence#(WIDTH) write_seq;

                for (int i = 0; i < NUM_WORDS; i++) begin
                    wait (env.wr_agent.monitor.vif.wmonitor.full === 1'b0);

                    write_seq = write_sequence#(WIDTH)::type_id::create($sformatf("write_%0d", i));
                    write_seq.start(env.wr_agent.sequencer);

                    repeat (2) @(env.wr_agent.monitor.vif.wmonitor);

                    if (env.scoreboard.writes_seen != i + 1) begin
                        `uvm_fatal("CONCURRENT_WRITE", $sformatf("After write request %0d, accepted writes=%0d", i + 1, env.scoreboard.writes_seen))
                    end
                end
            end

            begin
                read_sequence read_seq;

                for (int i = 0; i < NUM_WORDS; i++) begin
                    wait (env.rd_agent.monitor.vif.rmonitor.empty === 1'b0);

                    read_seq = read_sequence::type_id::create($sformatf("read_%0d", i));
                    read_seq.start(env.rd_agent.sequencer);

                    repeat (2) @(env.rd_agent.monitor.vif.rmonitor);

                    if (env.scoreboard.reads_seen != i + 1) begin
                        `uvm_fatal("CONCURRENT_READ", $sformatf("After read request %0d, accepted reads=%0d", i + 1, env.scoreboard.reads_seen))
                    end
                end
            end
        join

        // Allow the write domain to observe that the FIFO has drained.
        wait (env.wr_agent.monitor.vif.wmonitor.full === 1'b0);

        if (env.scoreboard.writes_seen != NUM_WORDS || env.scoreboard.reads_seen != NUM_WORDS || env.scoreboard.matches_seen != NUM_WORDS || env.scoreboard.writes_rejected != 0 || env.scoreboard.reads_rejected != 0 || env.scoreboard.expected_data.size() != 0 || env.rd_agent.monitor.vif.rmonitor.empty !== 1'b1) begin
            `uvm_fatal("CONCURRENT_CHECK", $sformatf("writes=%0d reads=%0d matches=%0d writes_rejected=%0d reads_rejected=%0d pending=%0d empty=%b", env.scoreboard.writes_seen, env.scoreboard.reads_seen, env.scoreboard.matches_seen, env.scoreboard.writes_rejected, env.scoreboard.reads_rejected, env.scoreboard.expected_data.size(), env.rd_agent.monitor.vif.rmonitor.empty))
        end

        `uvm_info("CONCURRENT", "Both streams completed and all read data matched", UVM_LOW)

        phase.drop_objection(this);
    endtask
endclass