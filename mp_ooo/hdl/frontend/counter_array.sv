module bim_array
#(
  parameter SET_IDX = (8),
  parameter WIDTH   = (2)
)
(
  input logic clk, rst,

  input logic [SET_IDX-1:0] bim_raddr0,
  output logic [WIDTH-1:0]  bim_rdata0,
  input logic [SET_IDX-1:0] bim_raddr1,
  output logic [WIDTH-1:0]  bim_rdata1,

  input logic               bim_we,
  input logic [SET_IDX-1:0] bim_waddr,
  input logic [WIDTH-1:0]   bim_wdata
);

logic [WIDTH-1:0] registers [(1<<SET_IDX)-1:0];
//logic [(1<<SET_IDX)-1:0] spread_checker;

logic [SET_IDX-1:0] bim_waddr_reg;

always_comb begin
  bim_rdata1 = registers[bim_raddr1];
end

always_ff @ (posedge clk) begin
  if (rst) begin
    for (int i = 0; i < (1<<(SET_IDX-2)); i++) begin
      for (int j = 0; j < (4); j++) begin
        registers[i*4+j] <= 2'b10;
      end
    end
  end else begin
    if (bim_we) begin
      registers[bim_waddr] <= bim_wdata;
      //spread_checker <= (256'd1 << bim_waddr);
    end
    if (bim_raddr0 == bim_waddr && bim_we) begin
      bim_rdata0 <= bim_wdata;
    end else begin
      bim_rdata0 <= registers[bim_raddr0];
      //spread_checker <= (256'd1 << bim_raddr0);
    end
  end 
end

endmodule
