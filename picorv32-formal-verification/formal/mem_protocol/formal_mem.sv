// Formal wrapper: checks the PicoRV32 native memory-interface protocol.
module formal_mem (input clk);
    (* anyseq *) wire        resetn;
    (* anyseq *) wire        mem_ready;
    (* anyseq *) wire [31:0] mem_rdata;

    wire        mem_valid, mem_instr, trap;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0]  mem_wstrb;

    picorv32 #(.ENABLE_COUNTERS(0), .COMPRESSED_ISA(0)) dut (
        .clk(clk), .resetn(resetn), .trap(trap),
        .mem_valid(mem_valid), .mem_instr(mem_instr), .mem_ready(mem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata)
    );

    // Start in reset
    reg init = 1;
    always @(posedge clk) init <= 0;
    always @* if (init) assume(!resetn);

    // Memory may only acknowledge an active request
    always @* if (resetn) assume(!mem_ready || mem_valid);

    // Protocol: a pending request must stay stable until accepted
    reg past_valid = 0;
    always @(posedge clk) past_valid <= 1;

    always @(posedge clk) if (past_valid && $past(resetn) && resetn) begin
        if ($past(mem_valid && !mem_ready)) begin
            assert(mem_valid);
            assert(mem_addr  == $past(mem_addr));
            assert(mem_wstrb == $past(mem_wstrb));
            assert(mem_instr == $past(mem_instr));
            if ($past(mem_wstrb != 0))
                assert(mem_wdata == $past(mem_wdata));
        end
    end

    // Reachability (non-vacuity): an instruction fetch can complete
    always @(posedge clk) cover(resetn && mem_valid && mem_ready && mem_instr);
endmodule
