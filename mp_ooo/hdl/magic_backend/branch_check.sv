module branch_check
import magic_backend_types::*;
(
  input logic [31:0]    alu_in_a,
  input logic [31:0]    alu_in_b,
  input br_ops          br_op,
  output logic          br_en
);

logic signed [31:0] as;
logic signed [31:0] bs;
logic unsigned [31:0] au;
logic unsigned [31:0] bu;

assign as =   signed'(alu_in_a);
assign bs =   signed'(alu_in_b);
assign au = unsigned'(alu_in_a);
assign bu = unsigned'(alu_in_b);

always_comb begin
  unique case(br_op)
    beq:  br_en = au == bu;
    bne:  br_en = au != bu;
    blt:  br_en = as < bs;
    bltu: br_en = au < bu;
    bge:  br_en = as >= bs;
    bgeu: br_en = au >= bu;
    default: br_en = 1'bx;
  endcase
end

endmodule : branch_check
