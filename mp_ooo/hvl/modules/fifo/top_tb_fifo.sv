// FIFO Package for UVM testbench
`include "fifo_pkg.svh"
`include "fifo_itf.svh"

module top_tb_fifo;
  timeunit 1ns;
  timeprecision 1ns;

  // UVM Imports
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // FIFO Types Imports
  import fifo_pkg::fifo_type_t;

  // Clock Generation
  int clock_half_period = 5;
  logic clk;
  initial begin
    clk <= '0; // Trigger Negedge Event
    forever #clock_half_period clk = ~clk;
  end

  // Reset and Various Events
  uvm_event event_reset = new();

  // FIFO Interface
  fifo_itf #(.DTYPE(fifo_type_t)) fifo_if(clk);

  // DUT Instantiation
  fifo #(.WIDTH(`FIFO_WIDTH), .DEPTH(`FIFO_DEPTH), .DTYPE(fifo_type_t)) dut (
    .clk(clk),
    .rst(fifo_if.rst),
    .wen(fifo_if.wen),
    .ren(fifo_if.ren),
    .wdata(fifo_if.wdata),
    .rdata(fifo_if.rdata),
    .full(fifo_if.full),
    .empty(fifo_if.empty)
  );

  // Start Testbench
  initial begin
    uvm_config_db #(uvm_event)::set(null, "*", "event_reset", event_reset);
    uvm_config_db #(virtual fifo_itf #(.DTYPE(fifo_type_t)))::set(null, "*", "fifo_itf", fifo_if);
    run_test();
  end

  // Waveform Dump
  initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, "+all");
  end

endmodule : top_tb_fifo
