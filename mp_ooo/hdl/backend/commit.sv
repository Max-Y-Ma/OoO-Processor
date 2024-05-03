/**
 * Module: commit
 * File  : commit.sv
 * Author: Max Ma
 * Date  : March 30, 2024
 *
 * Description:
 * ------------
 * The commit stage is responsible for checking that the head of the ROB is ready-to-commit. This instruction
 * will be the latest in program order. When an entry from the ROB commits, we write the architectural to
 * physical mapping into the RRF. If the old physical register is being replaced, we enqueue it to the free list.
 *
 * Critical Path Analysis:
 * ------------
 * The critical path spans reading from the ROB, writing to the RRF, and enqueuing the proper physical register to the free list.
*/
module commit
import backend_types::*;
import rv32i_types::*;
(
  input logic clk, rst,

  free_list_i.commit flif,
  rrf_i.commit       rrif,
  rob_i.commit       rbif,
  brb_itf.req        brif
);

  // Flush Logic During Broadcast Cycle
  logic flush;
  assign flush = brif.broadcast && (rbif.rdata.branch_mask[brif.tag]) && brif.kill;


  // Check the ROB & Write RRF Logic
  always_comb begin
    // Default Conditions
    rbif.ren = 1'b0;

    rrif.wen       = '0;
    rrif.ard_addr  = '0;
    rrif.prd_wdata = '0;

    //  ROB is ready-to-commit and not in flush cycle
    if (rbif.rdata.ready && ~rbif.empty && ~flush) begin
      // Dequeue ROB Entry
      rbif.ren = 1'b1;

      // Update RRF
      rrif.wen = 1'b1;
      rrif.ard_addr = rbif.rdata.ard;
      rrif.prd_wdata = rbif.rdata.prd;
    end
  end

  // Free List Enqueue Logic
  always_comb begin
    // Default Condition
    flif.wen = '0;
    flif.wdata = '0;

    // If new physical mapping is not equal to old, enqueue to free list and not in flush cycle
    if (rrif.valid && ~flif.full && ~flush) begin
      flif.wen = 1'b1;
      flif.wdata = rrif.free_prd;
    end
  end

  // RVFI Commit Signals
  logic [63:0] rvfi_order;
  always_ff @(posedge clk) begin
    if (rst) begin
      rvfi_order <= '0;
    end else if (rbif.rdata.ready & rbif.rdata.rvfi.valid && ~rbif.empty && ~flush) begin
      rvfi_order <= rvfi_order + 1'b1;
    end
  end

  rvfi_signal_t monitor;
  always_comb begin
    if (rbif.rdata.ready & rbif.rdata.rvfi.valid && ~rbif.empty && ~flush) begin
      monitor.valid = 1'b1;
      monitor.order     = rvfi_order;
      monitor.inst      = rbif.rdata.rvfi.inst;
      monitor.rs1_addr  = rbif.rdata.rvfi.rs1_addr;
      monitor.rs2_addr  = rbif.rdata.rvfi.rs2_addr;
      monitor.rs1_rdata = rbif.rdata.rvfi.rs1_rdata;
      monitor.rs2_rdata = rbif.rdata.rvfi.rs2_rdata;
      monitor.rd_addr   = rbif.rdata.rvfi.rd_addr;
      monitor.rd_wdata  = rbif.rdata.rvfi.rd_wdata;
      monitor.pc_rdata  = rbif.rdata.rvfi.pc_rdata;
      monitor.pc_wdata  = rbif.rdata.rvfi.pc_wdata;
      monitor.mem_addr  = rbif.rdata.rvfi.mem_addr;
      monitor.mem_rmask = rbif.rdata.rvfi.mem_rmask;
      monitor.mem_wmask = rbif.rdata.rvfi.mem_wmask;
      monitor.mem_rdata = rbif.rdata.rvfi.mem_rdata;
      monitor.mem_wdata = rbif.rdata.rvfi.mem_wdata;
    end else begin
      monitor = '0;
    end
  end

endmodule : commit
