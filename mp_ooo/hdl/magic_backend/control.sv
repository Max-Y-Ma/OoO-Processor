module control
import magic_backend_types::*;
(
  input logic [31:0] instr,
  output control_word_t control_word
);

logic [2:0] funct3;
logic       funct7;
alu_ops     alu_op_id;
rv32i_op_t opcode;
assign opcode = rv32i_op_t'(instr[6:0]);
assign funct3 = instr[14:12];
assign funct7 = instr[30];

always_comb begin

  control_word.instr_type = instr_type_t'(3'bxxx);
  control_word.alu_bypass = 1'b0;
  control_word.alu_op     = alu_ops'(3'bxxx);
  control_word.alu_m1_sel = alu_m1_sel_t'(1'bx);
  control_word.alu_m2_sel = alu_m2_sel_t'(1'bx);
  control_word.br         = 1'b0;
  control_word.jmp        = 1'b0;
  control_word.br_op      = br_ops'(3'bxxx);
  control_word.ex_pc_sel  = ex_pc_sel_t'(1'bx);
  control_word.mem_op     = none;
  control_word.wb_mem     = 1'b0;
  control_word.wb_pc      = 1'b0;
  control_word.rd_we      = 1'b0;

  unique case (opcode)
    op_lui: begin
      control_word.instr_type = u;
      control_word.alu_bypass = 1'b1;
      control_word.alu_m2_sel = imm_out;
      control_word.rd_we      = 1'b1;
    end
    op_auipc: begin
      control_word.instr_type = u;
      control_word.alu_op     = alu_add;
      control_word.alu_m1_sel = pc_out;
      control_word.alu_m2_sel = imm_out;
      control_word.rd_we     = 1'b1;
    end
    op_jal: begin
      control_word.instr_type = j;
      control_word.jmp        = 1'b1;
      control_word.ex_pc_sel  = pc_prev;
      control_word.rd_we      = 1'b1;
      control_word.wb_pc      = 1'b1;
    end
    op_jalr: begin
      control_word.instr_type = i;
      control_word.alu_op     = alu_add;
      control_word.alu_m1_sel = rs1_out;
      control_word.alu_m2_sel = imm_out;
      control_word.jmp        = 1'b1;
      control_word.ex_pc_sel  = pc_rs1;
      control_word.rd_we      = 1'b1;
      control_word.wb_pc      = 1'b1;
    end
    op_br: begin
      // Determine ALU operation for branch
      control_word.instr_type = b;
      control_word.alu_m1_sel = rs1_out;
      control_word.alu_m2_sel = rs2_out;
      control_word.br         = 1'b1;
      control_word.br_op      = br_ops'(funct3);
      control_word.ex_pc_sel  = pc_prev;
    end
    op_load: begin
      control_word.instr_type = i;
      control_word.alu_op     = alu_add;
      control_word.alu_m1_sel = rs1_out;
      control_word.alu_m2_sel = imm_out;
      control_word.mem_op     = mem_ops'({1'b0, funct3});
      control_word.wb_mem     = 1'b1;
      control_word.rd_we      = 1'b1;
    end
    op_store: begin
      control_word.instr_type = s;
      control_word.alu_op     = alu_add;
      control_word.alu_m1_sel = rs1_out;
      control_word.alu_m2_sel = imm_out;
      control_word.mem_op     = mem_ops'({1'b1, funct3});
    end
    op_imm: begin
      control_word.instr_type = i;
      if (funct3 == 3'h5) begin
        control_word.alu_op     = alu_ops'({funct7, funct3});
      end
      else begin
        control_word.alu_op     = alu_ops'({1'b0, funct3});
      end
      control_word.alu_m1_sel = rs1_out;
      control_word.alu_m2_sel = imm_out;
      control_word.rd_we      = 1'b1;
    end
    op_reg: begin
      control_word.instr_type = r;
      control_word.alu_op     = alu_ops'({funct7, funct3});
      control_word.alu_m1_sel = rs1_out;
      control_word.alu_m2_sel = rs2_out;
      control_word.rd_we = 1'b1;
    end
    op_csr: begin
    end
    default : begin
    end
  endcase
end


endmodule : control
