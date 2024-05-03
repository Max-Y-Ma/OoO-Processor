module magic_alu
import magic_backend_types::*;
(
  input   alu_ops       alu_op,
  input   logic         alu_bypass,
  input   logic [31:0]  alu_in_a,
  input   logic [31:0]  alu_in_b,
  output  logic [31:0]  alu_out_f
);

  logic signed   [31:0] as;
  logic signed   [31:0] bs;
  logic unsigned [31:0] au;
  logic unsigned [31:0] bu;

  assign as =   signed'(alu_in_a);
  assign bs =   signed'(alu_in_b);
  assign au = unsigned'(alu_in_a);
  assign bu = unsigned'(alu_in_b);

  always_comb begin
    if (alu_bypass) begin
      alu_out_f = alu_in_b;
    end
    else begin
      unique case(alu_op)
        alu_add:  alu_out_f = (au+bu);
        alu_sub:  alu_out_f = (au-bu);
        alu_sll:  alu_out_f = (au <<  bu[4:0]);
        alu_slt:  alu_out_f = (as < bs ? 32'b1 : 32'b0);
        alu_sltu: alu_out_f = (au < bu ? 32'b1 : 32'b0);
        alu_srl:  alu_out_f = (au >> bu[4:0]);
        alu_sra:  alu_out_f = (unsigned'(as >>> bu[4:0]));
        alu_xor:  alu_out_f = au ^   bu;
        alu_or:   alu_out_f = au |   bu;
        alu_and:  alu_out_f = au &   bu;
        default:  alu_out_f = 'x;
      endcase
    end
  end

endmodule : magic_alu
