module multiplier_pipeline
#(
  parameter DEPTH = 1
) (
  input logic clk, rst,

  input  logic        mul_stall,
  input  logic [31:0] mul_a,
  input  logic [31:0] mul_b,
  input  logic [1:0]  mul_type,
  output logic [63:0] mul_p
);

/* Pipeline Signals */
logic [63:0]  mul_result [DEPTH+1:0];

/* Multiplier Control */
assign mul_p = mul_result[DEPTH+1];

always_ff @ (posedge clk) begin
  integer i;
  for (i = 0; i < DEPTH+1; i++) begin
    if (rst) begin
      mul_result[i+1] <= '0;
    end
    else if (~mul_stall) begin
      mul_result[i+1] <= mul_result[i];
    end
  end
end

multiplier_combinational multiplier_combinational (
  .a(mul_a),
  .b(mul_b),
  .mul_type(mul_type),
  .p(mul_result[0])
);

endmodule