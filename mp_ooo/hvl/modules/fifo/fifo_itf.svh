interface fifo_itf #(
  parameter type DTYPE = logic[31:0]
) (
  input logic clk
);

  logic rst, wen, ren;
  logic full, empty;
  DTYPE wdata, rdata;

  // Clocking Blocks
  clocking drv_cb @(posedge clk);
    output rst, wen, ren, wdata;
  endclocking : drv_cb

  clocking mon_cb @(posedge clk);
    input clk, rst, wen, ren, full, empty, wdata, rdata;
  endclocking : mon_cb
endinterface : fifo_itf
