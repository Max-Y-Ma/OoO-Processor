/**
 * Module: alu
 * File  : alu.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * A "pipelined" execution unit that computes simple arithmetic and logic operations
*/
module alu
import backend_types::*;
import rv32i_types::*;
(
  input  logic clk, rst,

  /* EBR Branch Bus */
  brb_itf.req          brif,

  /* Request interface */
  input  issue_stage_t istage,
  input  logic [31:0]  alu_a, alu_b,
  input  logic         ivalid,
  output logic         iready,

  /* Reply interface */
  output issue_stage_t ostage,
  output logic [31:0]  oresult,
  output logic         ovalid,
  input  logic         oready
);

  /* ALU Signals */
  logic          [31:0] alu_f;
  logic signed   [31:0] as;
  logic signed   [31:0] bs;
  logic unsigned [31:0] au;
  logic unsigned [31:0] bu;

  /* Pipeline Signals */
  logic alu_stall;
  logic [2:0] alu_op;

  /* ALU assignments */
  assign alu_op = istage.ctrl.op;
  assign as     = signed'(alu_a);
  assign bs     = signed'(alu_b);
  assign au     = unsigned'(alu_a);
  assign bu     = unsigned'(alu_b);

  /* Request & Reply interface assignements */
  assign alu_stall = ~(oready) & ovalid;
  assign iready    = ~(alu_stall);

  always_ff @ (posedge clk) begin
    if (rst) begin
      ovalid <= 1'b0;
    end
    else if (~alu_stall) begin
      ostage  <= istage;
      ovalid  <= ivalid;
      oresult <= alu_f;

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

  // ALU Operations
  always_comb begin
    unique case (alu_op)
      alu_add: alu_f = au + bu;
      alu_sll: alu_f = au << bu[4:0];
      alu_sra: alu_f = unsigned'(as >>> bu[4:0]);
      alu_sub: alu_f = au - bu;
      alu_xor: alu_f = au ^ bu;
      alu_srl: alu_f = au >> bu[4:0];
      alu_or:  alu_f = au | bu;
      alu_and: alu_f = au & bu;
      default: alu_f = 'x;
    endcase
  end
endmodule : alu
