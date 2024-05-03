/**
 * Module: cmp
 * File  : cmp.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * A "pipelined" execution unit that computes comparison and equality operations
*/
module cmp
import backend_types::*;
import rv32i_types::*;
(
  input logic clk, rst,

  /* EBR Branch Bus */
  brb_itf.req          brif,

  /* Request interface */
  input  issue_stage_t istage,
  input  logic [31:0]  cmp_a, cmp_b,
  input  logic         ivalid,
  output logic         iready,

  /* Reply interface */
  output issue_stage_t ostage,
  output logic [31:0]  oresult,
  output logic         ovalid,
  input  logic         oready
);

  /* CMP Signals */
  logic                 cmp_f;
  logic [2:0]           cmp_op;
  logic signed   [31:0] as;
  logic signed   [31:0] bs;
  logic unsigned [31:0] au;
  logic unsigned [31:0] bu;

  /* Pipeline Signals */
  logic cmp_stall;

  /* CMP Assignments */
  assign cmp_op = istage.ctrl.op;
  assign as = signed'(cmp_a);
  assign bs = signed'(cmp_b);
  assign au = unsigned'(cmp_a);
  assign bu = unsigned'(cmp_b);

  /* Request & Reply interface assignements */
  assign cmp_stall = ~oready & ovalid;
  assign iready    = ~(cmp_stall);

  always_ff @ (posedge clk) begin
    if (rst) begin
      ovalid <= 1'b0;
    end
    else if (~cmp_stall) begin
      ostage  <= istage;
      ovalid  <= ivalid;
      oresult <= {31'b0, cmp_f};

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

  // Comparator Operations
  always_comb begin
    unique case (cmp_op)
      beq:     cmp_f = (au == bu);
      bne:     cmp_f = (au != bu);
      blt:     cmp_f = (as < bs);
      bge:     cmp_f = (as >= bs);
      bltu:    cmp_f = (au < bu);
      bgeu:    cmp_f = (au >= bu);
      default: cmp_f = 1'bx;
    endcase
  end
endmodule : cmp
