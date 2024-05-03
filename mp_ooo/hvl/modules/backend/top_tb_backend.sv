module top_tb_backend;
    timeunit 1ps;
    timeprecision 1ps;

    import rv32i_types::*;

    int clock_half_period_ps = 5;

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;

    int timeout = 100000000; // in cycles, change according to your needs

    // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
    mem_itf mem_itf_i(.*);
    mem_itf mem_itf_d(.*);
    magic_dual_port mem(.itf_i(mem_itf_i), .itf_d(mem_itf_d));
    // random_magic_tb random_magic_tb0(.itf_i(mem_itf_i), .itf_d(mem_itf_d));

    // Single memory port connection when caches are integrated into design (CP3 and after)
    /*
    bmem_itf bmem_itf(.*);
    blocking_burst_memory burst_memory(.itf(bmem_itf));
    */

    mon_itf mon_itf(.*);    
    monitor monitor(.itf(mon_itf));

    // Magic Frontend and Backend DUT
    logic [31:0]  pc;
    instr_queue_t iqueue_rdata;
    logic         instr_valid;
    logic         iqueue_ren;
    logic         iqueue_full;
    logic         iqueue_empty;
    logic         branch;
    logic         br_en;
    logic [31:0]  target_addr;

    logic frontend_stall;
    always_comb begin
      // one of many stall conditions, this will grow as the processor grows
      frontend_stall = iqueue_full;
    end

    magic_frontend magic_frontend0 (
      .clk(clk),
      .rst(rst),
      .stall(frontend_stall),
      .imem_resp(mem_itf_i.resp),
      .br_resolved(branch),
      .br_jmp(br_en),
      .br_jmp_addr(target_addr),
      .flush(flush),
      .instr_valid(instr_valid),
      .imem_addr(mem_itf_i.addr),
      .imem_rmask(mem_itf_i.rmask),
      .pc(pc)
    );

    backend backend0 (
      .clk(clk),
      .rst(rst),
      .flush(flush),
      .branch(branch),
      .br_en(br_en),
      .target_addr(target_addr),
      .iqueue_ren(iqueue_ren),
      .iqueue_rdata(iqueue_rdata),
      .iqueue_empty(iqueue_empty),
      .dmem_addr(mem_itf_d.addr),
      .dmem_rmask(mem_itf_d.rmask),
      .dmem_wmask(mem_itf_d.wmask),
      .dmem_rdata(mem_itf_d.rdata),
      .dmem_wdata(mem_itf_d.wdata),
      .dmem_resp(mem_itf_d.resp)
    );

    fifo #(.WIDTH(32), .DEPTH(32), .DTYPE(instr_queue_t)) instr_queue (
      .clk(clk),
      .rst(rst | flush),
      .wen(instr_valid),
      .wdata('{instr: mem_itf_i.rdata, pc: pc}),
      .ren(iqueue_ren),
      .rdata(iqueue_rdata),
      .full(iqueue_full),
      .empty(iqueue_empty)
    );

    always_comb begin
        mon_itf.valid = backend0.commit0.monitor.valid;
        mon_itf.order = backend0.commit0.monitor.order;
        mon_itf.inst = backend0.commit0.monitor.inst;
        mon_itf.rs1_addr = backend0.commit0.monitor.rs1_addr;
        mon_itf.rs2_addr = backend0.commit0.monitor.rs2_addr;
        mon_itf.rs1_rdata = backend0.commit0.monitor.rs1_rdata;
        mon_itf.rs2_rdata = backend0.commit0.monitor.rs2_rdata;
        mon_itf.rd_addr = backend0.commit0.monitor.rd_addr;
        mon_itf.rd_wdata = backend0.commit0.monitor.rd_wdata;
        mon_itf.pc_rdata = backend0.commit0.monitor.pc_rdata;
        mon_itf.pc_wdata = backend0.commit0.monitor.pc_wdata;
        mon_itf.mem_addr = backend0.commit0.monitor.mem_addr;
        mon_itf.mem_rmask = backend0.commit0.monitor.mem_rmask;
        mon_itf.mem_wmask = backend0.commit0.monitor.mem_wmask;
        mon_itf.mem_rdata = backend0.commit0.monitor.mem_rdata;
        mon_itf.mem_wdata = backend0.commit0.monitor.mem_wdata;
    end

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        if (mon_itf.halt) begin
            $finish;
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        if (mem_itf_i.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        if (mem_itf_d.error != 0) begin
            repeat (5) @(posedge clk);
            $finish;
        end
        timeout <= timeout - 1;
    end

endmodule : top_tb_backend
