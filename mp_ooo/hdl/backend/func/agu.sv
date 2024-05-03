/**
 * Module: agu
 * File  : agu.sv
 * Author: Max Ma
 * Date  : March 29, 2024
 *
 * Description:
 * ------------
 * A "pipelined" execution unit that calculates the target memory address
*/
module agu
import backend_types::*;
(
  input clk, rst,

  /* EBR Branch Bus */
  brb_itf.req          brif,

  /* Request interface */
  input  issue_stage_t istage,
  input  logic [31:0]  agu_a, agu_b,
  input  logic [2:0]   mem_op,
  input  logic [31:0]  mem_wdata,
  input  logic         ivalid,
  output  logic        iready,

  /* Reply interface */
  output issue_stage_t ostage,
  output agu_result_t  oresult,
  output logic         ovalid,
  input  logic         oready
);

  /* Pipeline Signals */
  logic agu_stall;
  logic [31:0] mem_addr;
  logic [31:0] o_mem_wdata;
  logic [3:0]  mem_mask;

  /* Request & Reply interface assignements */
  assign agu_stall = ~oready & ovalid;
  assign iready    = (ovalid & ~agu_stall) | ~agu_stall;

  always_ff @ (posedge clk) begin
    if (rst) begin
      ovalid <= 1'b0;
    end
    else if (~agu_stall) begin
      ostage  <= istage;
      ovalid  <= ivalid;
      oresult <= '{mem_addr : mem_addr, mem_wdata : o_mem_wdata, mem_mask : mem_mask};

      /* BRB tag update */
      if (brif.broadcast) begin
        if (istage.meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            ostage.meta.branch_mask[brif.tag] <= 1'b0;
          end
          else if (brif.kill) begin
            ovalid <= '0;
          end
        end
      end
    end
    else begin
      /* BRB tag update */
      if (brif.broadcast) begin
        if (ostage.meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            ostage.meta.branch_mask[brif.tag] <= 1'b0;
          end
          else if (brif.kill) begin
            ovalid <= '0;
          end
        end
      end
    end
  end

  always_comb begin
    /* Addr calculation */
    mem_addr  = agu_a + agu_b;
    o_mem_wdata = 'x;
    mem_mask  = 'x;
    /* wdata & Mask calculation */
    unique case (mem_op[1:0])
      2'b00: begin
        mem_mask = 4'b0001 << (mem_addr & 2'b11);
        o_mem_wdata = (mem_wdata << {(mem_addr & 2'b11), 3'b0});
      end
      2'b01: begin
        mem_mask = 4'b0011 << (mem_addr & 2'b10);
        o_mem_wdata = (mem_wdata << {(mem_addr & 2'b10), 3'b0});
      end
      2'b10: begin
        mem_mask = 4'b1111;
        o_mem_wdata = (mem_wdata);
      end
      default: begin end
    endcase
  end

endmodule : agu
