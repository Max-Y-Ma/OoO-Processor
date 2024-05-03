module magic_frontend
import rv32i_types::*;
import backend_types::*;
#(
  parameter SUPERSCALAR = 1
) (
  input logic clk,
  input logic rst,

  input logic stall,

  output logic [31:0] imem_addr,
  output logic [3:0]  imem_rmask,
  input  logic        imem_resp,

  input  logic                      br_jmp,
  input  logic                      br_resolved,
  input  logic [COB_ADDR_WIDTH-1:0] br_tag,
  input  logic [31:0]               br_jmp_addr,
  input  logic [31:0]               br_pc_addr,
  output logic                      flush,

  brb_itf.response brif,

  output logic        instr_valid,
  output logic [31:0] pc
);

logic        mispredict;
logic        instr_valid_fetch;
logic [31:0] pc_fetch;
logic [31:0] branch_misses;

always_comb begin
  imem_addr  = pc_fetch;
  imem_rmask = 4'b1111;
  mispredict = br_jmp;
end

magic_pc_update_stage fetch_stage0 (
  .clk(clk),
  .rst(rst),
  .stall(stall),
  .imem_resp(imem_resp),
  .br_guess(1'b0),
  .br_guess_addr('x),
  .br_resolved(br_resolved),
  .mispredict(br_jmp),
  .mispredict_addr(br_jmp_addr),
  .flush(flush),
  .br_tag(br_tag),
  .brif(brif),
  .pc(pc_fetch),
  .instr_v(instr_valid_fetch)
);

always_ff @ (posedge clk) begin
  if (rst) begin
    branch_misses <= '0;
  end
  else if (br_jmp) begin
    branch_misses <= branch_misses + 1'b1;
  end
end

// Register instr_valid for one cycle for the imem to be able to respond
always_ff @ (posedge clk) begin
  instr_valid <= instr_valid_fetch;
  pc          <= pc_fetch;
end

endmodule
