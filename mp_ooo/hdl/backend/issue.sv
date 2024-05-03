/**
 * Module: issue
 * File  : issue.sv
 * Author: Max Ma
 * Date  : March 20, 2024
 *
 * Description:
 * ------------
 * The issue stage handles requests from reservation stations. It evaluates
 * incoming requests and the functional units' status to determine the next
 * instruction for execution. Priority schemes based on age-order should be
 * employed to prevent instruction starvation.
 *
 * Critical Path Analysis:
 * ------------
 * The critical path spans reservation station request logic and functional
 * unit statuses. It then spans read logic from the physical register file and writes
 * to the input registers of the execution units.
*/
module issue
import backend_types::*;
(
  // Issue Logic
  output logic              issue,
  input  logic [NUM_EU-1:0] eu_ready,

  // Interface Ports
  res_i.issue int_rsif,
  res_i.issue mud_rsif, 
  res_i.issue bra_rsif,
  res_i.issue mem_rsif,
  prf_i.issue pfif,

  // Pipeline Stage
  output issue_stage_t issue_stage
);

  // Wakeup/Issue Priority Encoder
  always_comb begin
    // Default Conditions
    issue          = '0;
    int_rsif.ren   = '0;
    int_rsif.raddr = '0;
    mud_rsif.ren   = '0;
    mud_rsif.raddr = '0;
    bra_rsif.ren   = '0;
    bra_rsif.raddr = '0;
    mem_rsif.ren   = '0;
    mem_rsif.raddr = '0;

    // **NOTE** Multiple Issue Queues Prioritization:
    // Prioritize branch queue, then memory queue, then integer/arithmetic queue
    if (|bra_rsif.req) begin
      for (int i = 0; i < BR_ISSUE_DEPTH; i++) begin
        if (bra_rsif.req[i] && eu_ready[bru] && ~bra_rsif.empty) begin
          issue = 1'b1;
          bra_rsif.ren = 1'b1;
          bra_rsif.raddr = unsigned'(i); // Should be replaced by age-order reservation station
          break;
        end
      end
    end else if (|mem_rsif.req) begin
      for (int i = 0; i < MEM_ISSUE_DEPTH; i++) begin
        if (mem_rsif.req[i] && eu_ready[agu] && ~mem_rsif.empty) begin
          issue = 1'b1;
          mem_rsif.ren = 1'b1;
          mem_rsif.raddr = unsigned'(i); // Should be replaced by age-order reservation station
          break;
        end
      end
    end else if (|mud_rsif.req) begin
      for (int i = 0; i < MUD_ISSUE_DEPTH; i++) begin
        if (mud_rsif.req[i] && eu_ready[mud_rsif.euid[i]] && ~mud_rsif.empty) begin
          issue = 1'b1;
          mud_rsif.ren = 1'b1;
          mud_rsif.raddr = unsigned'(i); // Should be replaced by age-order reservation station
          break;
        end
      end
    end else begin
      for (int i = 0; i < INT_ISSUE_DEPTH; i++) begin
        if (int_rsif.req[i] && eu_ready[int_rsif.euid[i]] && ~int_rsif.empty) begin
          issue = 1'b1;
          int_rsif.ren = 1'b1;
          int_rsif.raddr = unsigned'(i); // Should be replaced by age-order reservation station
          break;
        end
      end
    end
  end

  // Read Physical Register File
  res_entry_t issue_entry;
  always_comb begin
    issue_entry = bra_rsif.ren ? bra_rsif.rdata :
                  mem_rsif.ren ? mem_rsif.rdata :
                  mud_rsif.ren ? mud_rsif.rdata :
                  int_rsif.ren ? int_rsif.rdata : 'x;

    pfif.prs1_addr = issue_entry.meta.prs1_addr;
    pfif.prs2_addr = issue_entry.meta.prs2_addr;
  end

  // Issue Stage Output, Flopped at EU Registers
  always_comb begin
    issue_stage.valid     = issue;
    issue_stage.ctrl      = issue_entry.ctrl;
    issue_stage.meta      = issue_entry.meta;
    issue_stage.psr1_data = pfif.rs1_rdata;
    issue_stage.psr2_data = pfif.rs2_rdata;
  end

  // RVFI Logic
  always_comb begin
    issue_stage.rvfi = issue_entry.rvfi;
    issue_stage.rvfi.rs1_rdata = pfif.rs1_rdata;
    issue_stage.rvfi.rs2_rdata = pfif.rs2_rdata;
  end

endmodule : issue
