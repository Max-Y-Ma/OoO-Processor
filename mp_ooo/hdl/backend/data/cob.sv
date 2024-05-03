/**
 * Module: cob
 * File  : cob.sv
 * Author: Max Ma
 * Date  : April 13, 2024
 *
 * Description:
 * ------------
 * The Control Order Buffer (COB) keeps track of all branch information which includes information like target address,
 * branch taken/not taken, and program counter. An entry in the COB is enqueued during the 
 * dispatch stage. The head of the COB contains the oldest in-flight branch currently being executed. 
 * The COB is updated during a writeback on the CDB. When the head of the ROB is a branch and is ready-to-commit, 
 * it will take the branch data from the head of the COB since it must also be ready.
*/
module cob 
import backend_types::*;
(
  input logic clk, rst,
  
  input  logic [FREE_LIST_ADDR_WIDTH:0] free_rptr,
  input  rat_entry_t [NUM_ARCH_REGISTERS-1:0] rat_data,
  output cob_entry_t cob_data [COB_DEPTH],

  // RAT Interface
  input logic                      rtif_wen,
  input logic [ARCH_REG_WIDTH-1:0] rtif_ard_addr,
  input rat_entry_t                rtif_prd_wdata,

  cob_itf.r   coif,
  brb_itf.req brif,
  cdb_i.req   cbif
);

  // Control Order Buffer
  cob_entry_t cob [COB_DEPTH];
  assign cob_data = cob;

  // Free Entry Calculation
  logic [COB_ADDR_WIDTH-1:0] free_entry;
  always_comb begin
    free_entry = '0;
    for (int i = 0; i < COB_DEPTH; i++) begin
      if (~cob[i].valid) begin
        free_entry = COB_ADDR_WIDTH'(unsigned'(i));
        break;
      end
    end
  end

  always_ff @ (posedge clk) begin
    if (rst) begin
      for (int i = 0; i < COB_DEPTH; i++) begin
        cob[i].valid <= '0;
      end
    end 
    else begin
      // Enqueue and Dequeue Logic
      if (coif.allocate & ~coif.full) begin
        cob[free_entry].valid <= 1'b1;
        cob[free_entry].branch_mask <= coif.mask;

        // Concurrent BRB Update Logic for COB Entry Data
        if (brif.broadcast) begin
          if (coif.mask[brif.tag]) begin
            if (brif.clean) begin
              cob[free_entry].branch_mask[brif.tag] <= 1'b0;
            end
            else if (brif.kill) begin
              cob[free_entry] <= '0;
            end 
          end
        end
      end
      if (coif.wen) begin
        cob[coif.waddr]             <= coif.wdata;
        cob[coif.waddr].free_rptr   <= free_rptr;
        cob[coif.waddr].rat_data    <= rat_data;

        // Concurrent RAT Update for JAL/JALR from Dispatch Stage
        if (rtif_wen && (rtif_ard_addr != '0)) begin
          cob[coif.waddr].rat_data[rtif_ard_addr] <= rtif_prd_wdata;
        end
        // CDB Snoop/Update Logic
        if (cbif.valid && (rat_data[cbif.ard].data == cbif.prd)) begin
          cob[coif.waddr].rat_data[cbif.ard].valid <= 1'b1;
        end

        // Concurrent BRB Update Logic for COB Entry Data
        if (brif.broadcast) begin
          if (coif.wdata.branch_mask[brif.tag]) begin
            if (brif.clean) begin
              cob[coif.waddr].branch_mask[brif.tag] <= 1'b0;
            end
            else if (brif.kill) begin
              cob[coif.waddr].valid <= '0;
            end 
          end
        end
      end
      if (coif.ren & ~coif.empty) begin
        cob[coif.raddr].valid <= '0;
      end
      // Branch Resolution Clean/Kill Logic
      if (brif.broadcast) begin
        for (int i = 0; i < COB_DEPTH; i++) begin
          // Update Reservation Station Entries Under Speculation of Branch
          if (cob[i].branch_mask[brif.tag] == 1'b1) begin
            if (brif.clean) begin
              cob[i].branch_mask[brif.tag] <= 1'b0;
            end
            else if (brif.kill) begin
              cob[i].valid <= '0;
            end
          end 
        end 
      end 

      // CDB Snoop/Update Logic: Update Backup RATs for Nonspeculative Instructions
      for (int i = 0; i < COB_DEPTH; i++) begin
        if (coif.wen && (coif.waddr == COB_ADDR_WIDTH'(unsigned'(i)))) begin 
          if (cbif.valid && ~coif.wdata.branch_mask[i] && (rat_data[cbif.ard].data == cbif.prd)) begin
            cob[i].rat_data[cbif.ard].valid <= 1'b1;
          end
        end
        else if (cbif.valid && ~cob[i].branch_mask[i] && (cob[i].rat_data[cbif.ard].data == cbif.prd)) begin
          cob[i].rat_data[cbif.ard].valid <= 1'b1;
        end
      end
    end
  end

    // Full, Empty, and Free Address Signals
  always_comb begin
    coif.full = 1'b1;
    coif.empty = 1'b1;
    for (int i = 0; i < COB_DEPTH; i++) begin
      coif.full = coif.full & cob[i].valid;
      coif.empty = coif.empty & ~cob[i].valid;
    end
  end

  always_comb begin
    coif.index = free_entry;
  end
  
endmodule : cob