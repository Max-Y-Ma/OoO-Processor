module pc_update_stage
import rv32i_types::*;
#(
  parameter SUPERSCALAR = 1
) (
  input logic clk,
  input logic rst,

  input logic stall,
  input logic imem_resp,

  input logic br_guess,
  input logic [31:0] br_guess_addr,

  input logic mispredict,
  input logic [31:0] mispredict_addr,

  output logic [31:0] pc,
  output logic        instr_v
);

logic [31:0] pc_reg;
logic        invalid_prev;

always_comb begin
  if (rst) begin
    pc      = 32'h60000000;
    instr_v = 1'b0;
  end
  else if (mispredict) begin
    pc      = mispredict_addr;
    instr_v = 1'b0;
  end
  else if (~stall & imem_resp) begin
    instr_v = 1'b1;
    pc      = invalid_prev ? pc_reg : (br_guess ? br_guess_addr : pc_reg + 4);
  end
  else begin
    /* pc      = br_guess ? br_guess_addr : pc_reg; */
    pc         = pc_reg;
    instr_v = ~invalid_prev;
  end
end

always_ff @(posedge clk) begin
  if (rst) begin
    pc_reg       <= 32'h60000000;
    invalid_prev <= 1'b0;
  end
  else if (mispredict) begin
    pc_reg       <= mispredict_addr;
    invalid_prev <= 1'b1;
  end
  else if (~stall & imem_resp) begin
    if (invalid_prev) begin
      invalid_prev <= 1'b0;
    end
    else begin
      pc_reg <= br_guess ? br_guess_addr : pc_reg + 4;
    end
  end
end

endmodule
