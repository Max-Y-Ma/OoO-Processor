module predecoder
import rv32i_types::*;
(
  input rv32i_op_t opcode,
  output logic is_control_flow
);

always_comb begin
  if (opcode == op_jal || opcode == op_br || opcode == op_jalr) begin
    is_control_flow = 1'b1;
  end
  else begin
    is_control_flow = 1'b0;
  end
end

endmodule
