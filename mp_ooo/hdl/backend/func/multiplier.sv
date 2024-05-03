module multiplier
import backend_types::*;
import rv32i_types::*;
#(
  parameter DEPTH = 6
)
(
  input logic clk, rst,

  /* EBR Branch Bus */
  brb_itf.req          brif,

  /* Reqest Interface */
  input  issue_stage_t  istage,
  input  logic [31:0]   mul_a, mul_b,
  input  logic          ivalid,
  output logic          iready,

  /* Reply Interface */
  output issue_stage_t ostage,
  output logic [31:0]  oresult,
  output logic         ovalid,
  input  logic         oready
);


/* Pipeline Signals */
logic         mul_stall;
logic         mul_valid [DEPTH+1:0];
issue_stage_t mul_stage [DEPTH+1:0];
logic [63:0]  mul_result;

/* Multiplier Signals */
logic [1:0] mul_type;
assign mul_type = istage.ctrl.op[1:0];

/* Request & Reply interface assignments */
assign mul_stall = ~oready & ovalid;
assign iready    = (mul_valid[1] & ~mul_stall) | ~mul_stall;

/* Multiplier output logic */
assign ovalid    = mul_valid[DEPTH+1];
assign ostage    = mul_stage[DEPTH+1];

/* Multiplier pipeline stage logic */
assign mul_valid[0] = ivalid & iready;
assign mul_stage[0] = istage;
always_ff @ (posedge clk) begin
  for (int i = 0; i < DEPTH+1; i++) begin
    if (rst) begin
      mul_valid[i+1] <= '0;
      mul_stage[i+1] <= '0;
    end
    else if (~mul_stall) begin
      mul_valid[i+1]  <= mul_valid[i];
      mul_stage[i+1]  <= mul_stage[i];

      /* BRB tag update */
      if (brif.broadcast) begin
        if (mul_stage[i].meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            mul_stage[i+1].meta.branch_mask[brif.tag] <= 1'b0;
          end
          else if (brif.kill) begin
            mul_valid[i+1] <= '0;
          end
        end
      end
    end
    else begin
      /* BRB tag update */
      if (brif.broadcast) begin
        if (mul_stage[i].meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            mul_stage[i+1].meta.branch_mask[brif.tag] <= 1'b0;
          end
          else if (brif.kill) begin
            mul_valid[i+1] <= '0;
          end
        end
      end
    end
  end
end

/* Output Logic */
always_comb begin
  unique case (ostage.ctrl.funct3)
    mulr:    oresult = mul_result[31:0];
    mulhr:   oresult = mul_result[63:32];
    mulhsur: oresult = mul_result[63:32];
    mulhur:  oresult = mul_result[63:32];
    default: oresult = 'x;
  endcase
end

multiplier_pipeline #(
  .DEPTH(DEPTH)
) multiplier_pipeline0 (
  .clk(clk), 
  .rst(rst),
  .mul_stall(mul_stall),
  .mul_a(mul_a),
  .mul_b(mul_b),
  .mul_type(mul_type),
  .mul_p(mul_result)
);

endmodule
