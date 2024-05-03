/**
 * Module: rob
 * File  : rob.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * The Reorder Buffer (ROB) keeps track of the instruction order. An entry in the ROB is enqueued during the 
 * dispatch stage. The head of the ROB contains the oldest in-flight instruction currently being executed. 
 * The ROB is updated during a writeback on the CDB. When the head of the ROB is ready-to-commit, 
 * we can update the architectural state of the processor. The ROB also outputs the index where entries are enqueued.
*/
module rob 
import backend_types::*;
(
  input logic clk, rst,

  output logic store,
  output logic load,

  rob_i.r           rbif,
  input cob_entry_t cob_data [COB_DEPTH],
  brb_itf.req       brif,
  cdb_i.req         cbif
);

  rob_entry_t rob [ROB_DEPTH];
  logic [ROB_ADDR_WIDTH:0] wptr, rptr;

  always_ff @ (posedge clk) begin
    if (rst) begin
      wptr <= '0;
      rptr <= '0;
      for (int i = 0; i < ROB_DEPTH; i++) begin
        rob[i].ready <= '0;
      end
    end 
    else begin
      // Enqueue and Dequeue Logic
      if (rbif.wen & ~rbif.full) begin
        rob[wptr[ROB_ADDR_WIDTH-1:0]] <= rbif.wdata;
        wptr <= wptr + 1'b1;

        // Concurrent BRB Update Logic for ROB Entry Data
        if (brif.broadcast) begin
          if (rbif.wdata.branch_mask[brif.tag]) begin
            if (brif.clean) begin
              rob[wptr[ROB_ADDR_WIDTH-1:0]].branch_mask[brif.tag] <= 1'b0;
            end
            else if (brif.kill) begin
              rob[wptr[ROB_ADDR_WIDTH-1:0]].ready <= '0;
              wptr <= cob_data[brif.tag].rob_wptr + 1'b1;
            end
          end
        end
      end
      if (rbif.ren & ~rbif.empty) begin
        rob[rptr[ROB_ADDR_WIDTH-1:0]].ready <= 1'b0;
        rptr <= rptr + 1'b1;
      end
      // CDB Snoop/Update Logic 
      if (cbif.valid) begin
        rob[cbif.rob_index].ready       <= 1'b1;
        rob[cbif.rob_index].rvfi        <= cbif.rvfi;
      end
      // Branch Resolution Clean/Kill Logic
      if (brif.broadcast) begin
        for (int i = 0; i < ROB_DEPTH; i++) begin
          // Update Reservation Station Entries Under Speculation of Branch
          if (rob[i].branch_mask[brif.tag] == 1'b1) begin
            if (brif.clean) begin
              rob[i].branch_mask[brif.tag] <= 1'b0;
            end 
            else if (brif.kill) begin
              rob[i].ready <= '0;
              wptr <= cob_data[brif.tag].rob_wptr + 1'b1;
            end
          end 
        end 
      end 
    end
  end

  always_comb begin
    store = rob[rptr[ROB_ADDR_WIDTH-1:0]].store & rob[rptr[ROB_ADDR_WIDTH-1:0]].ready;
    load = rob[rptr[ROB_ADDR_WIDTH-1:0]].load & rob[rptr[ROB_ADDR_WIDTH-1:0]].ready;

    rbif.rdata = rob[rptr[ROB_ADDR_WIDTH-1:0]];
    rbif.index   = wptr;
    rbif.full    = ({~wptr[ROB_ADDR_WIDTH], wptr[ROB_ADDR_WIDTH-1:0]} == rptr);
    rbif.empty   = (wptr == rptr);
  end
  
endmodule : rob
