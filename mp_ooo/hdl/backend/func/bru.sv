/**
 * Module: bru
 * File  : bru.sv
 * Author: Max Ma
 * Date  : March 29, 2024
 *
 * Description:
 * ------------
 * A "pipelined" execution unit that resolves branches and calculate target address
*/
module bru
import backend_types::*;
import rv32i_types::*;
(
  input logic clk, rst,

  /* EBR Branch Bus */
  brb_itf.req          brif,

  /* Request interface */
  input  issue_stage_t istage,
  input  logic [31:0]  bru_a, bru_b,
  input  logic         ivalid,
  output logic         iready,

  /* Reply interface */
  output issue_stage_t ostage,
  output bru_result_t  oresult,
  output logic         ovalid,
  input  logic         oready
);

  /* BRU Signals */
  logic          [31:0] pc;
  logic                 br_en;
  logic          [2:0]  cmp_op;
  logic          [31:0] target_addr;
  logic          [31:0] target_op1;
  logic          [31:0] target_op2;
  logic          [31:0] return_addr;
  logic signed   [31:0] as;
  logic signed   [31:0] bs;
  logic unsigned [31:0] au;
  logic unsigned [31:0] bu;

  /* Pipeline Signals */
  logic bru_stall;

  /* BRU Assignments */
  assign pc          = istage.ctrl.pc;
  assign cmp_op      = istage.ctrl.op;

  assign target_op1  = (istage.ctrl.target_mux == rs1_target) ?
                       istage.psr1_data : pc;
  assign target_op2  = (istage.ctrl.imm);

  assign target_addr = target_op1 + target_op2;
  assign return_addr = pc + 'h4;

  assign as          = signed'(bru_a);
  assign bs          = signed'(bru_b);
  assign au          = unsigned'(bru_a);
  assign bu          = unsigned'(bru_b);

  /* Request & Reply interface assignements */
  assign bru_stall = ~oready & ovalid;
  assign iready    = ~(bru_stall);

  always_ff @ (posedge clk) begin
    if (rst) begin
      ovalid <= 1'b0;
    end
    else if (~bru_stall) begin
      ostage  <= istage;
      ovalid  <= ivalid;
      oresult <= '{target_addr: target_addr, return_addr: return_addr, br_en: br_en};

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

  /* BRU Operations */
  always_comb begin
    unique case (cmp_op)
      beq:  br_en = (au == bu);
      bne:  br_en = (au != bu);
      blt:  br_en = (as < bs);
      bge:  br_en = (as >= bs);
      bltu: br_en = (au < bu);
      bgeu: br_en = (au >= bu);
      default: br_en = 1'bx;
    endcase
  end

endmodule : bru
