/**
 * Module: rename
 * File  : rename.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * The rename stage involves decoding a given instruction to extract control and metadata information. 
 * Simultaneously, if the instruction requires a destination register, read signals are asserted to the free list. 
 * Additionally, mappings of architectural registers to physical registersthe is read from the RAT.
 *
 * Critical Path Analysis:
 * ------------
 * The rename stage critical path involves read logic from the instruction queue, decode logic, 
 * then read logic from free list.
*/
module rename 
import backend_types::*;
(
  input logic clk, rst,

  // Instruction Queue Interface
  output logic    iqueue_ren,
  input  iqueue_t iqueue_rdata,
  input  logic    iqueue_empty,

  // Stall Signals
  input logic dispatch_stall,

  // Interface Ports
  rat_i.rename       rtif,
  free_list_i.rename flif,
  brb_itf.req        brif,

  // Pipeline Stage
  output rename_stage_t rename_stage
);

  logic flush;
  assign flush = brif.broadcast && brif.kill;

  // Rename Stall Logic: 
  // If free list is empty, we should stall and not dequeue the instruction queue
  // Dispatch applies backpressure, we should also stall if dispatch stage stalls
  // Dispatch stall will be high upon a flush
  logic rename_stall;
  assign rename_stall = flif.empty | dispatch_stall;

  // Instruction Queue Read Logic
  logic instr_valid;
  logic [31:0] pc, inst;
  logic [COB_ADDR_WIDTH-1:0] branch_tag;
  logic [COB_DEPTH-1:0]      branch_mask;
  always_comb begin
    // Default Conditions
    iqueue_ren  = 1'b0;
    pc          = '0;
    inst        = NOP_BUBBLE;
    instr_valid = '0;
    branch_tag  = '0;
    branch_mask = '0;

    // Only read from non-empty queues and not stalled
    if (~iqueue_empty & ~rename_stall) begin
      iqueue_ren  = 1'b1;
      pc          = iqueue_rdata.pc;
      inst        = iqueue_rdata.inst;
      instr_valid = 1'b1;
      branch_tag  = iqueue_rdata.branch_tag;
      branch_mask = iqueue_rdata.branch_mask;

      // Branch Resolution Clean/Kill Logic
      if (brif.broadcast) begin
        if (iqueue_rdata.branch_mask[brif.tag] == 1'b1) begin
          if (brif.clean) begin
            branch_mask[brif.tag] = 1'b0;
          end
        end 
      end 
    end
  end

  // Decode Stage
  ctrl_sig_t ctrl;
  metadata_t meta;
  decoder decoder0 (
    .instr_valid(instr_valid),
    .inst(inst),
    .ctrl(ctrl),
    .meta(meta)
  );

  // Read Source Register Mappings from RAT
  assign rtif.ars1_addr = instr_valid ? meta.ars1_addr : 'x;
  assign rtif.ars2_addr = instr_valid ? meta.ars2_addr : 'x;
  
  // Assert Read to Free List
  always_comb begin
    flif.ren = 1'b0;
  
    if (meta.ard_addr == '0) begin
      flif.ren = 1'b0;
    end else if (~rename_stall) begin
      flif.ren = (ctrl.regf_we) ? 1'b1 : 1'b0;
    end
  end

  // Pipeline Stage Logic
  always_ff @(posedge clk) begin
    if (rst) begin
      rename_stage <= '0;
    end
    else if (rename_stall | flush | ~instr_valid) begin
      rename_stage.valid <= '0;
    end
    else begin
      rename_stage.valid   <= instr_valid;
      rename_stage.ctrl    <= ctrl;
      rename_stage.ctrl.pc <= pc;

      rename_stage.meta             <= meta;
      rename_stage.meta.euid        <= meta.euid;
      rename_stage.meta.ard_addr    <= meta.ard_addr;
      rename_stage.meta.ars1_addr   <= meta.ars1_addr;
      rename_stage.meta.ars2_addr   <= meta.ars2_addr;
      rename_stage.meta.prs1_addr   <= 'x;
      rename_stage.meta.prs1_ready  <= 'x;
      rename_stage.meta.prs2_addr   <= 'x;
      rename_stage.meta.prs2_ready  <= 'x;
      rename_stage.meta.branch_mask <= branch_mask;
      rename_stage.meta.cob_index   <= branch_tag;

      // RVFI Logic
      if (~iqueue_empty) begin
        rename_stage.rvfi.valid   <= 1'b1;
      end else begin
        rename_stage.rvfi.valid   <= 1'b0;
      end
      rename_stage.rvfi.inst <= inst;
      rename_stage.rvfi.rs1_addr <= meta.ars1_addr;
      rename_stage.rvfi.rs2_addr <= meta.ars2_addr;
      rename_stage.rvfi.rd_addr <= meta.ard_addr;
      rename_stage.rvfi.pc_rdata <= pc;
    end
  end
//larryjoshandmax4lyfe
endmodule : rename
