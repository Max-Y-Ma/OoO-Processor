/**
 * Module: rrf
 * File  : rrf.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * The Retirement Register File (RRF) contains the actual mapping of the architectural to physical registers.
 * This is because it is only updated after an instruction commits from the head of the ROB. This garuntees that
 * mappings in the RRF are those currently holding architectural register values. Replacing an entry in the RRF
 * implies that the physical register is now free; thus, enqueue to the free list. 
*/
module rrf
import backend_types::*;
(
  input  logic clk, rst,

  rrf_i.r rrif
);

  // RAT Mapping Data
  logic [PHYS_REG_WIDTH-1:0] rrf [NUM_ARCH_REGISTERS];

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < NUM_ARCH_REGISTERS; i++) begin
        rrf[i] <= (PHYS_REG_WIDTH'(unsigned'(i)));
      end
    end else if (rrif.wen) begin
      rrf[rrif.ard_addr] <= rrif.prd_wdata;
    end
  end

  assign rrif.free_prd = rrf[rrif.ard_addr];
  assign rrif.valid = (rrf[rrif.ard_addr] != rrif.prd_wdata);

endmodule : rrf
