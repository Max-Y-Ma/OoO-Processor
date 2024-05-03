/**
 * Module: reservation
 * File  : reservation.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * The Reservation Station (RS) acts like a buffer/queue for instructions waiting to execute.
 * These instructions are waiting for source operands to become available as they snoop the CDB.
 * When an entry becomes ready, it must assert a request signal in order to be issued.
 * A oldest-goes-first policy is used to determine which entry has the most priority. 
*/
module reservation
import backend_types::*; 
#(
  parameter DEPTH = INT_ISSUE_DEPTH,
  parameter ADDR_WIDTH = $clog2(DEPTH)
) (
  input logic clk, rst,

  res_i.r       rsif,
  brb_itf.req   brif,
  cdb_i.req     cbif
);

  // Reservation Station
  res_entry_t res_station [DEPTH];

  // Free Entry Calculation
  logic [ADDR_WIDTH-1:0] free_entry;
  always_comb begin
    free_entry = '0;
    for (int i = 0; i < DEPTH; i++) begin
      if (~res_station[i].valid) begin
        free_entry = ADDR_WIDTH'(unsigned'(i));
        break;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < DEPTH; i++) begin
        res_station[i].valid <= 1'b0;
        res_station[i].meta.prs1_addr  <= '0;
        res_station[i].meta.prs2_addr  <= '0;
      end
    end 
    else begin
      if (rsif.wen & ~rsif.full) begin
        res_station[free_entry] <= rsif.wdata;

        // Concurrrent BRB Update Reservation Station
        if (brif.broadcast) begin
          if (rsif.wdata.meta.branch_mask[brif.tag]) begin
            if (brif.clean) begin
              res_station[free_entry].meta.branch_mask[brif.tag] <= 1'b0;
            end
            else if (brif.kill) begin
              res_station[free_entry].valid <= '0;
              res_station[free_entry].meta.prs1_addr  <= '0;
              res_station[free_entry].meta.prs2_addr  <= '0;
            end 
          end 
        end 
      end 
      if (rsif.ren & ~rsif.empty) begin
        res_station[rsif.raddr].valid <= 1'b0;
        res_station[rsif.raddr].meta.prs1_addr  <= '0;
        res_station[rsif.raddr].meta.prs2_addr  <= '0;
      end
      // CDB Snoop/Update Logic
      if (cbif.valid && cbif.prd != '0) begin
        for (int i = 0; i < DEPTH; i++) begin
          if (res_station[i].meta.prs1_addr == cbif.prd) begin
            res_station[i].meta.prs1_ready <= 1'b1;
          end
          if (res_station[i].meta.prs2_addr == cbif.prd) begin
            res_station[i].meta.prs2_ready <= 1'b1;
          end
        end
      end
      // Branch Resolution Clean/Kill Logic
      if (brif.broadcast) begin
        for (int i = 0; i < DEPTH; i++) begin
          // Update Reservation Station Entries Under Speculation of Branch
          if (res_station[i].meta.branch_mask[brif.tag] == 1'b1) begin
            if (brif.clean) begin
              res_station[i].meta.branch_mask[brif.tag] <= 1'b0;
            end 
            else if (brif.kill) begin
              res_station[i].valid <= '0;
              res_station[i].meta.prs1_addr  <= '0;
              res_station[i].meta.prs2_addr  <= '0;
            end
          end 
        end 
      end 
    end
  end

  // Full, Empty, and Free Address Signals
  always_comb begin
    rsif.full = 1'b1;
    rsif.empty = 1'b1;
    for (int i = 0; i < DEPTH; i++) begin
      rsif.full = rsif.full & res_station[i].valid;
      rsif.empty = rsif.empty & ~res_station[i].valid;
    end
  end

  // 1 Combinational Read Port
  always_comb begin
    rsif.rdata = res_station[rsif.raddr];

    for (int i = 0; i < DEPTH; i++) begin
      rsif.euid[i] = res_station[i].meta.euid;
    end
  end

  // Request Logic
  always_comb begin
    for (int i = 0; i < DEPTH; i++) begin
      rsif.req[i] = res_station[i].valid & res_station[i].meta.prs1_ready & res_station[i].meta.prs2_ready;
    end
  end

endmodule : reservation
