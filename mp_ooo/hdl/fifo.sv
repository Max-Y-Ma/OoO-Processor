module fifo #(
  parameter WIDTH = 32,
  parameter DEPTH = 4,
  parameter type DTYPE = logic[WIDTH-1:0],
  localparam PTR_WIDTH = $clog2(DEPTH)
) (
  input logic clk,
  input logic rst,
  input logic wen,
  input DTYPE wdata,
  input logic ren,
  output DTYPE rdata,

  output logic full,
  output logic empty
);

DTYPE fifo [DEPTH];
logic [PTR_WIDTH:0] wptr, rptr;

always_ff @ (posedge clk) begin
  if (rst) begin
    wptr <= '0;
    rptr <= '0;
  end else begin
    if (wen & ~full) begin
      fifo[wptr[PTR_WIDTH-1:0]] <= wdata;
      wptr <= wptr + 1'b1;
    end
    if (ren & ~empty) begin
      rptr <= rptr + 1'b1;
    end
  end
end

always_comb begin
  full = {~wptr[PTR_WIDTH], wptr[PTR_WIDTH-1:0]} == rptr;
  empty = wptr == rptr;
  rdata = fifo[rptr[PTR_WIDTH-1:0]];
end

endmodule : fifo
