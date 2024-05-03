/**
 * Module: rat
 * File  : rat.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * The Register Alias Table (RAT) is the speculative mapping of the architectural to physical registers.
 * Architectural source registers are queried for their corronding physical registers.
 * Architectural destination registers are updated to their physical registers from the free list.
 * A valid bit indicates whether the physical register's value is ready-for-use or speculative. 
*/
module rat
import backend_types::*;
(
  input logic clk, rst,
 
  input  cob_entry_t                          cob_data [COB_DEPTH],
  output rat_entry_t [NUM_ARCH_REGISTERS-1:0] rat_data,
  brb_itf.req                                 brif,

  rat_i.r rtif,
  cdb_i.req cbif
);

  // RAT Mapping Data
  rat_entry_t [NUM_ARCH_REGISTERS-1:0] rat;
  assign rat_data = rat;

  // 1 Synchronous Write Port
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < NUM_ARCH_REGISTERS; i++) begin
        rat[i].valid <= 1'b1;
        rat[i].data <= '0;
      end
    end 
    else if (brif.broadcast && brif.kill) begin
      // Parallel load RRF entires on a flush
      for (int i = 0; i < NUM_ARCH_REGISTERS; i++) begin
        rat[i] <= cob_data[brif.tag].rat_data[i];
      end
      for (int i = 0; i < COB_DEPTH; i++) begin
        if (cbif.valid && ~cob_data[brif.tag].branch_mask[i] && (cob_data[brif.tag].rat_data[cbif.ard].data == cbif.prd)) begin
          rat[cbif.ard].valid <= 1'b1;
        end
      end
    end
    else begin
      // CDB Snoop/Update Logic
      if (cbif.valid && (rat[cbif.ard].data == cbif.prd)) begin
        rat[cbif.ard].valid <= 1'b1;
      end
      // Prioritize New RAT Speculative State
      if (rtif.wen && (rtif.ard_addr != '0)) begin
        rat[rtif.ard_addr] <= rtif.prd_wdata;
      end
    end
  end

  // 2 Synchronous, Write-Through Read Ports
  always_ff @(posedge clk) begin
    if (rst) begin
      rtif.prs1_rdata <= 'x;
      rtif.prs2_rdata <= 'x;
    end else begin
      if (rtif.ars1_addr == '0) begin
        rtif.prs1_rdata <= {1'b1, {PHYS_REG_WIDTH{1'b0}}};
      end else if (rtif.ars1_addr == rtif.ard_addr) begin
        rtif.prs1_rdata <= rtif.prd_wdata;
      end else if (cbif.valid && (rat[rtif.ars1_addr].data == cbif.prd)) begin
        rtif.prs1_rdata <= {1'b1, cbif.prd};
      end else begin
        rtif.prs1_rdata <= rat[rtif.ars1_addr];
      end

      if (rtif.ars2_addr == '0) begin
        rtif.prs2_rdata <= {1'b1, {PHYS_REG_WIDTH{1'b0}}};
      end else if (rtif.ars2_addr == rtif.ard_addr) begin
        rtif.prs2_rdata <= rtif.prd_wdata;
      end else if (cbif.valid && (rat[rtif.ars2_addr].data == cbif.prd)) begin
        rtif.prs2_rdata <= {1'b1, cbif.prd};
      end else begin
        rtif.prs2_rdata <= rat[rtif.ars2_addr];
      end
    end
  end
  
endmodule : rat
