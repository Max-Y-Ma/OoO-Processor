module branch_fifo
import backend_types::*;
#(
  parameter WIDTH = 32,
  parameter DEPTH = 4,
  localparam PTR_WIDTH = $clog2(DEPTH)
) (
  input logic clk,
  input logic rst,
  input logic wen,
  input iqueue_t wdata,
  input logic ren,
  output iqueue_t rdata,
  output logic full,
  output logic empty,
  brb_itf.req brif
);

iqueue_t fifo [DEPTH];
logic [PTR_WIDTH:0] wptr, rptr;

always_ff @ (posedge clk) begin
  if (rst) begin
    wptr <= '0;
    rptr <= '0;
  end else begin
    if (wen & ~full) begin
      fifo[wptr[PTR_WIDTH-1:0]] <= wdata;
      wptr <= wptr + 1'b1;

      // Concurrent BRB Update Logic for fifo Entry Data
      if (brif.broadcast) begin
        if (wdata.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            fifo[wptr[PTR_WIDTH-1:0]].branch_mask[brif.tag] <= 1'b0;
          end
        end
      end
    end
    if (ren & ~empty) begin
      rptr <= rptr + 1'b1;
    end

    // Branch Resolution Clean/Kill Logic
    if (brif.broadcast) begin
      for (int i = 0; i < DEPTH; i++) begin
        // Update Reservation Station Entries Under Speculation of Branch
        if (fifo[i].branch_mask[brif.tag] == 1'b1) begin
          if (brif.clean) begin
            fifo[i].branch_mask[brif.tag] <= 1'b0;
          end
        end 
      end 
    end 
  end
end

always_comb begin
  full = {~wptr[PTR_WIDTH], wptr[PTR_WIDTH-1:0]} == rptr;
  empty = wptr == rptr;
  rdata = fifo[rptr[PTR_WIDTH-1:0]];
end

endmodule : branch_fifo
