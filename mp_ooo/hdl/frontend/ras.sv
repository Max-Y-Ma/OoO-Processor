/* Behavior:
 * Does not allow pushing and popping on the same cycle.
 * Outputs are combinational.
 * Rdata will output the top of the stack.
 * In case of push, rdata will output what was previously at the top of the
 * stack, not what will be pushed to the top. (not write through)
 *
 */
module ras
import rv32i_types::*;
#(
  parameter DEPTH = (32),
  localparam PTR_WIDTH = $clog2(DEPTH)
) (
  input logic clk, rst,

  input rv32i_op_t opcode,
  input logic [4:0] rd,
  input logic [4:0] rs1,

  input logic [31:0] wdata,
  output logic [31:0] rdata,
  output logic ras_popped,
  output logic full, empty,

  input logic stall, flush
);

logic [31:0] stack [DEPTH];
logic [PTR_WIDTH-1:0] ptr;

logic rd_link;
logic rs1_link;
assign rd_link = (rd == 5'd1 || rd == 5'd5);
assign rs1_link = (rs1 == 5'd1 || rs1 == 5'd5);

logic push;
logic pop;

/* Stack Control Logic */
/* Refer to page 16 of riscv-spec-v2.2 */
/* This is more advanced and supports coroutines, but requires pushing and
 * popping on the same cycle.
 */
//always_comb begin
//  if (opcode == op_jal) begin
//    if (rd_link) begin
//      push = 1'b1;
//    end else begin
//      push = 1'b0;
//    end
//    pop = 1'b0;
//  end else if (opcode == op_jalr) begin
//    if (rd_link) begin
//      push = 1'b1;
//    end else begin
//      push = 1'b0;
//    end
//    if (rs1_link) begin
//      if (~rd_link) begin
//        pop = 1'b1;
//      end else begin
//        if (rd == rs1) begin
//          pop = 1'b0;
//        end else begin
//          pop = 1'b1;
//        end
//      end
//    end else begin
//      pop = 1'b0;
//    end
//  end else begin
//    push = 1'b0;
//    pop = 1'b0;
//  end
//end

/* This assumes no coroutine. */
always_comb begin
  if (opcode == op_jal) begin
    if (rd_link) begin
      push = 1'b1;
    end else begin
      push = 1'b0;
    end
    pop = 1'b0;
  end else if (opcode == op_jalr) begin
    if (rd_link) begin
      push = 1'b1;
      pop = 1'b0;
    end else if (rs1_link) begin
      push = 1'b0;
      pop = 1'b1;
    end else begin
      push = 1'b0;
      pop = 1'b0;
    end
  end else begin
    push = 1'b0;
    pop = 1'b0;
  end
end

always_ff @ (posedge clk) begin
  if (rst | flush) begin
    ptr <= '0;
  end else begin
    if (pop && !(ptr == '0) && !stall) begin
      ptr <= ptr - 1'b1;
    end else if (push && !(ptr == '1) && !stall) begin
      stack[ptr] <= wdata;
      ptr <= ptr + 1'b1;
    end
  end
end

/* Same cycle Logic */
always_comb begin
  if (rst | flush) begin
    ras_popped = 1'b0;
    full = 1'b0;
    empty = 1'b1;
  end else begin
    if (pop & ~stall) begin
      full = 1'b0;
      empty = ((ptr - 1'b1) == '0);
    end else if (push & ~stall) begin
      full = ((ptr + 1'b1) == '1);
      empty = 1'b0;
    end else begin
      full = (ptr == '1);
      empty = (ptr == '0);
    end

    if (pop && !(ptr == '0) && !stall) begin
      ras_popped = 1'b1;
    end else begin
      ras_popped = 1'b0;
    end
  end
  
  rdata = stack[ptr - 1'b1];
end

endmodule
