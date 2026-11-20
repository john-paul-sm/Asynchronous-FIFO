`uvm_analysis_imp_decl(_wr) // Analaysis implementation Write declaration
`uvm_analysis_imp_decl(_rd) // Analaysis implementation Read declaration

class fifo_scoreboard#(int WIDTH = 32) extends uvm_scoreboard;
    `uvm_component_param_utils(fifo_scoreboard#(WIDTH));

    logic [WIDTH-1:0] expected_data[$];

    int unsigned write_samples = 0;
    int unsigned read_samples = 0;
    int unsigned writes_seen = 0;
    int unsigned reads_seen = 0;
    int unsigned matches_seen = 0;

    int unsigned writes_rejected = 0;
    int unsigned reads_rejected = 0;

    uvm_analysis_imp_wr#(write_observation#(WIDTH), fifo_scoreboard#(WIDTH)) wr_imp;
    uvm_analysis_imp_rd#(read_observation#(WIDTH), fifo_scoreboard#(WIDTH)) rd_imp;

    function new (string name, uvm_component parent);
        super.new(name, parent);
        wr_imp = new("wr_imp", this);
        rd_imp = new("rd_imp", this);
    endfunction

    function void write_wr(write_observation#(WIDTH) observation);
        write_samples++;
        // Shared reset discards the expected unread contents.
        if (!observation.shared_rst_n) begin
            expected_data.delete();
            return;
        end

        if (observation.wrst_n && observation.w_en && observation.full) begin
            writes_rejected++;
        end        

        // Only accepted writes add data to the reference model.
        if (observation.accepted) begin
            writes_seen++;
            expected_data.push_back(observation.wdata);
        end
    endfunction

    function void write_rd(read_observation#(WIDTH) observation);
        logic [WIDTH-1:0] expected_word;
        read_samples++;

        if (!observation.shared_rst_n) begin
            expected_data.delete();
            return;
        end

        if (observation.rrst_n && observation.r_en && observation.empty) begin
            reads_rejected++;
        end        

        if (observation.accepted) begin
            reads_seen++;
            // An accepted read must have a corresponding expected word.
            if (expected_data.size() == 0) begin
                `uvm_error("SB_UNEXPECTED_READ", $sformatf("Accepted read with no expected data: observed=0x%0h",observation.rdata))
                return;
            end

            expected_word = expected_data.pop_front();

            if (observation.rdata !== expected_word) begin
                `uvm_error("SB_DATA_MISMATCH", $sformatf( "Read mismatch: expected=0x%0h observed=0x%0h", expected_word, observation.rdata))
            end
            else begin
                matches_seen++;
                `uvm_info("SB_READ_MATCH",$sformatf("Read matched: data=0x%0h", observation.rdata), UVM_LOW)
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SB_COUNTS", $sformatf("wr_samples=%0d rd_samples=%0d writes=%0d reads=%0d matches=%0d writes_rejected=%0d reads_rejected=%0d pending=%0d", write_samples, read_samples, writes_seen, reads_seen, matches_seen, writes_rejected, reads_rejected, expected_data.size()), UVM_LOW)
    endfunction
endclass