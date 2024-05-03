// Frontend Package for UVM testbench
`include "frontend_pkg.svh"

interface frontend_itf (
  input logic clk
);

  logic rst, stall, imem_resp, br_jump, instr_valid;
  logic [31:0] br_jump_addr, imem_addr;
  logic [3:0] imem_rmask;
  
  // Clocking Blocks
  clocking drv_cb @(posedge clk);
    output rst, stall, imem_resp, br_jump, br_jump_addr;
  endclocking : drv_cb

  clocking mon_cb @(posedge clk);
    input clk, rst, stall, imem_resp, br_jump, br_jump_addr;
    input imem_addr, imem_rmask, instr_valid;
  endclocking : mon_cb
endinterface : frontend_itf

module top_tb_frontend;
  timeunit 1ns;
  timeprecision 1ns;

  // UVM Imports
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Clock Generation
  int clock_half_period = 5;
  logic clk;
  initial begin
    clk <= '0; // Trigger Negedge Event
    forever #clock_half_period clk = ~clk;
  end

  // Frontend Interface
  frontend_itf frontend_if(clk);

  // DUT Instantiation
  frontend dut (
    .clk(clk),
    .rst(frontend_if.rst),
    .stall(frontend_if.stall),
    .imem_resp(frontend_if.imem_resp),
    .br_jump(frontend_if.br_jump),
    .br_jump_addr(frontend_if.br_jump_addr),
    .instr_valid(frontend_if.instr_valid),
    .imem_addr(frontend_if.imem_addr),
    .imem_rmask(frontend_if.imem_rmask)
  );

  // Start Testbench
  initial begin
    uvm_config_db #(virtual frontend_itf)::set(null, "*", "frontend_itf", frontend_if);
    run_test();
  end

  // Waveform Dump
  initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, "+all");
  end

endmodule : top_tb_frontend
