/**
 * Module: free_list
 * File  : free_list.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * The Free List (FL) represents all the physical registers that are not being used. 
 * This can be represented as a FIFO containing physical register indexes. 
 * The Free List is read/popped during renaming, when an architectural destination register
 * needs to be mapped to a physical register. The Free List is written/pushed after an instruction
 * that uses a destination register commits at the end of the ROB.
*/
module free_list
import backend_types::*;
(
  input logic clk, rst,

  input  cob_entry_t              cob_data [COB_DEPTH],
  output [FREE_LIST_ADDR_WIDTH:0] free_rptr,
  brb_itf.req                     brif,

  free_list_i.r flif
);

  logic [PHYS_REG_WIDTH-1:0] free_list [FREE_LIST_DEPTH];
  logic [FREE_LIST_ADDR_WIDTH:0] wptr, rptr;

  assign free_rptr = rptr;

  always_ff @ (posedge clk) begin
    // Reset free list to contain all excess physical registers and full condition
    if (rst) begin
      rptr <= '0;
      wptr <= {1'b1, {FREE_LIST_ADDR_WIDTH{1'b0}}};  
      for (int i = 0; i < FREE_LIST_DEPTH; i++) begin
        free_list[i] <= (PHYS_REG_WIDTH'(unsigned'(i + NUM_ARCH_REGISTERS)));
      end
    end
    else if (brif.broadcast && brif.kill) begin
      // Reset read and write pointers on a flush
      rptr <= cob_data[brif.tag].free_rptr;

      // Concurrent Nonspeculative Writes
      if (flif.wen && ~flif.full) begin
        free_list[wptr[FREE_LIST_ADDR_WIDTH-1:0]] <= flif.wdata;
        wptr <= wptr + 1'b1;
      end
    end
    else begin
      if (flif.wen && ~flif.full) begin
        free_list[wptr[FREE_LIST_ADDR_WIDTH-1:0]] <= flif.wdata;
        wptr <= wptr + 1'b1;
      end
      if (flif.ren && ~flif.empty) begin
        flif.rdata <= free_list[rptr[FREE_LIST_ADDR_WIDTH-1:0]];
        rptr <= rptr + 1'b1;
      end
    end
  end

  always_comb begin
    flif.full  = ({~wptr[FREE_LIST_ADDR_WIDTH], wptr[FREE_LIST_ADDR_WIDTH-1:0]} == rptr);
    flif.empty = (wptr == rptr);
  end
  
endmodule : free_list
