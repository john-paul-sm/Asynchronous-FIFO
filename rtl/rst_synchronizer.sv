module rst_synchronizer (
    input logic clk,
    input logic shared_rst_n,
    output logic local_rst_n // 2nd stage in the 2-FF synchronizer for the reset
);

    logic rst_sync1; // first stage in the 2-FF synchronizer for the reset

    always_ff @(posedge clk or negedge shared_rst_n) begin
        if(!shared_rst_n) begin
            local_rst_n <= 1'b0;
            rst_sync1 <= 1'b0;
        end
        else begin
            local_rst_n <= rst_sync1;
            rst_sync1 <= 1'b1;
        end
    end
endmodule