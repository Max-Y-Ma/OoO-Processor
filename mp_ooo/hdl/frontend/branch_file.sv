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
module branch_file
import frontend_types::*;
import backend_types::*; 
#(
  parameter DEPTH = COB_DEPTH,
  parameter ADDR_WIDTH = $clog2(DEPTH)
) (
  input logic                  clk, rst,
  input logic                  wen, 
  input logic                  ren,
  input logic [ADDR_WIDTH-1:0] waddr, 
  input logic [ADDR_WIDTH-1:0] raddr, 
  input branch_queue_t         wdata,
  output branch_queue_t        rdata,
  output logic                 empty, 
  output logic                 full,
  
  brb_itf.req                  brif
);

  // Reservation Station
  branch_queue_t branch_file [DEPTH];

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < DEPTH; i++) begin
        branch_file[i].valid <= 1'b0;
      end
    end 
    else begin
      if (wen & ~full) begin
        branch_file[waddr] <= wdata;

        // Concurrrent BRB Update Reservation Station
        if (brif.broadcast) begin
          if (wdata.branch_mask[brif.tag]) begin
            if (brif.clean) begin
              branch_file[waddr].branch_mask[brif.tag] <= 1'b0;
            end
            else if (brif.kill) begin
              branch_file[waddr] <= '0;
            end 
          end 
        end 
      end 
      if (ren & ~empty) begin
        branch_file[raddr].valid <= 1'b0;
      end
      // Branch Resolution Clean/Kill Logic
      if (brif.broadcast) begin
        for (int i = 0; i < DEPTH; i++) begin
          // Update Reservation Station Entries Under Speculation of Branch
          if (branch_file[i].branch_mask[brif.tag] == 1'b1) begin
            if (brif.clean) begin
              branch_file[i].branch_mask[brif.tag] <= 1'b0;
            end 
            else if (brif.kill) begin
              branch_file[i].valid <= '0;
            end
          end 
        end 
      end 
    end
  end

  // Full, Empty, and Free Address Signals
  always_comb begin
    full = 1'b1;
    empty = 1'b1;
    for (int i = 0; i < DEPTH; i++) begin
      full = full & branch_file[i].valid;
      empty = empty & ~branch_file[i].valid;
    end
  end

  // 1 Combinational Read Port
  assign rdata = branch_file[raddr];

endmodule : branch_file
