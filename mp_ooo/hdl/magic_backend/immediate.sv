module immediate
import magic_backend_types::*;
(
  input logic [31:0] instr,
  input instr_type_t instr_type,

  output logic [31:0] immediate
);

always_comb begin
  case (instr_type)
    i: immediate  = {{21{instr[31]}}, instr[30:20]};
    s: immediate  = {{21{instr[31]}}, instr[30:25], instr[11:7]};
    b: immediate  = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    u: immediate  = {instr[31:12], 12'h000};
    j: immediate  = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
    default:
      immediate = 32'b0;
  endcase
end

endmodule : immediate
