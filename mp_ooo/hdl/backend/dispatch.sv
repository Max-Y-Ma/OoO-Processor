/**
 * Module: dispatch
 * File  : dispatch.sv
 * Author: Max Ma
 * Date  : March 20, 2024
 *
 * Description:
 * ------------
 * The dispatch stage updates the Rename Address Table (RAT) and allocates an entry
 * in the Reorder Buffer (ROB). It gathers the required data and enqueues itself
 * in the reservation station, awaiting issuance..
 *
 * Critical Path Analysis:
 * ------------
 * The critical path for the dispatch stage spans the Free List read logic, enqueue into
 * the ROB, and the Reservation Station write logic.
*/
module dispatch
import backend_types::*;
(
  input logic clk, rst,

  // Stall Signals
  output logic dispatch_stall,

  // Interface Ports
  rat_i.d       rtif,
  free_list_i.d flif,
  rob_i.d       rbif,
  cob_itf.d     coif,
  res_i.d       int_rsif,
  res_i.d       mud_rsif,
  res_i.d       bra_rsif,
  res_i.d       mem_rsif,
  lsu_itf.d     lsu_if,
  cdb_i.req     cbif,

  // EBR Interface Signals
  input logic [STORE_ADDR_WIDTH:0] lsu_store_wptr,
  brb_itf.req                  brif,

  // Pipeline Stage
  input rename_stage_t irename_stage
);

  logic flush;
  assign flush = brif.broadcast && brif.kill;

  // Rename Stage Data 
  rename_stage_t rename_stage;

  // Dispatch Stall Logic:
  // If ROB is full or Issue Queue(s) are full, we should stall until both are not full
  logic int_type, mud_type, bra_type, ld_type, st_type, mem_type;
  assign int_type = ((rename_stage.meta.euid == alu) || (rename_stage.meta.euid == cmp));
  assign mud_type = ((rename_stage.meta.euid == mul) || (rename_stage.meta.euid == div));
  assign bra_type = (rename_stage.meta.euid == bru);
  assign mem_type = (rename_stage.meta.euid == agu);
  assign ld_type  = (rename_stage.ctrl.mem_read);
  assign st_type  = (rename_stage.ctrl.mem_write);
  assign dispatch_stall = rbif.full | (int_type & int_rsif.full) | (mud_type & mud_rsif.full) | (bra_type & bra_rsif.full) |
                          (mem_type & mem_rsif.full) | (st_type & ~lsu_if.st_ready) | (ld_type & ~lsu_if.ld_ready);

  logic dispatch_stall_dff;
  always_ff @(posedge clk) begin
    if (rst) begin
      dispatch_stall_dff <= '0;
    end 
    else if (flush) begin
      dispatch_stall_dff <= '0;
    end
    else begin
      dispatch_stall_dff <= dispatch_stall;
    end
  end

  // Rename Signal Latch Logic
  rename_stage_t rename_stage_latch;
  always_ff @(posedge clk) begin
    if (rst) begin
      rename_stage_latch <= '0;
    end 
    else if (flush) begin
      rename_stage_latch <= '0;
    end
    else if (dispatch_stall && !dispatch_stall_dff) begin
      rename_stage_latch <= irename_stage;

      // Read RAT Signals
      rename_stage_latch.meta.prs1_addr   <= rtif.prs1_rdata.data;
      rename_stage_latch.meta.prs1_ready  <= rtif.prs1_rdata.valid;
      rename_stage_latch.meta.prs2_addr   <= rtif.prs2_rdata.data;
      rename_stage_latch.meta.prs2_ready  <= rtif.prs2_rdata.valid;

      // BRB Update Logic for Dispatch Stalls
      if (brif.broadcast) begin
        if (irename_stage.meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            rename_stage_latch.meta.branch_mask[brif.tag] <= 1'b0;
          end
          else if (brif.kill) begin
            rename_stage_latch <= '0;
          end 
        end 
      end 
    end
    
    // BRB Update Logic for Dispatch Stalls
    if (brif.broadcast) begin
      if (rename_stage_latch.meta.branch_mask[brif.tag]) begin
        if (brif.clean) begin
          rename_stage_latch.meta.branch_mask[brif.tag] <= 1'b0;
        end
        else if (brif.kill) begin
          rename_stage_latch <= '0;
        end 
      end 
    end 
  end

  // If Stalled, Output Latched Rename State
  always_comb begin
    rename_stage = dispatch_stall_dff ? rename_stage_latch : irename_stage;

    rename_stage.meta.prs1_addr   = dispatch_stall_dff ? rename_stage_latch.meta.prs1_addr  : rtif.prs1_rdata.data;
    rename_stage.meta.prs1_ready  = dispatch_stall_dff ? rename_stage_latch.meta.prs1_ready : rtif.prs1_rdata.valid;
    rename_stage.meta.prs2_addr   = dispatch_stall_dff ? rename_stage_latch.meta.prs2_addr  : rtif.prs2_rdata.data;
    rename_stage.meta.prs2_ready  = dispatch_stall_dff ? rename_stage_latch.meta.prs2_ready : rtif.prs2_rdata.valid;
  end

  // Free List Physical Register
  logic [PHYS_REG_WIDTH-1:0] free_prd;
  always_comb begin
    if (rename_stage.meta.ard_addr == '0) begin
      free_prd = '0;
    end else begin
      free_prd = (rename_stage.ctrl.regf_we) ? flif.rdata : '0;
    end
  end

  // Update RAT with Physical Destination Register Mapping
  always_comb begin
    // Default Conditions
    rtif.wen = '0;
    rtif.prd_wdata = '0;
    rtif.ard_addr = '0;

    // Only update RAT if not stalled and current instruction uses a destination register
    if (~dispatch_stall && ~flush && rename_stage.ctrl.regf_we && rename_stage.valid) begin
      rtif.wen = 1'b1;
      rtif.prd_wdata = {1'b0, free_prd};    
      rtif.ard_addr = rename_stage.meta.ard_addr;
    end
  end

  // Global Branch Mask 
  logic [COB_DEPTH-1:0] global_bmask;
  assign global_bmask = rename_stage.meta.branch_mask;

  logic [COB_ADDR_WIDTH-1:0] cob_index;
  assign cob_index = rename_stage.meta.cob_index;

  // Enqueue ROB Entry
  rob_entry_t rob_entry;
  logic [ROB_ADDR_WIDTH-1:0] rob_index;
  always_comb begin
    // Default Conditions
    rbif.wen   = '0;
    rbif.wdata = '0;

    // Format ROB Entry
    rob_entry.ready       = 1'b0;
    rob_entry.ard         = rename_stage.meta.ard_addr;
    rob_entry.prd         = free_prd;
    rob_entry.store       = rename_stage.ctrl.mem_write;
    rob_entry.load        = rename_stage.ctrl.mem_read;
    rob_entry.branch      = rename_stage.ctrl.branch;
    rob_entry.cob_index   = cob_index;
    rob_entry.branch_mask = global_bmask;

    // Only enqueue to ROB if not stalled
    if (~dispatch_stall && ~flush && rename_stage.valid) begin
      rbif.wen   = 1'b1;
      rbif.wdata = rob_entry;
    end

    rob_index = rbif.index[ROB_ADDR_WIDTH-1:0];
  end

  // Enqueue COB Entry
  cob_entry_t cob_entry;
  always_comb begin
    // Default Conditions
    coif.wen   = '0;
    coif.waddr = '0;
    coif.wdata = '0;

    // Format COB Entry
    cob_entry.valid       = '0;
    // More Early Branch Data Acquired in Datapath Modules
    cob_entry.rob_wptr    = rbif.index;
    cob_entry.store_wptr  = lsu_store_wptr;
    cob_entry.branch_mask = global_bmask;
    cob_entry.free_rptr   = '0;
    cob_entry.rat_data    = '0;

    // Only enqueue to COB if not stalled and Branch Instruction
    if (~dispatch_stall && ~flush && rename_stage.ctrl.branch && rename_stage.valid) begin
      cob_entry.valid = 1'b1;
      
      coif.wen   = 1'b1;
      coif.waddr = cob_index;
      coif.wdata = cob_entry;
    end
  end

  // CDB Snoop/Forwarding Logic with Stalls
  logic prs1_ready_latch, prs2_ready_latch;
  always_ff @(posedge clk) begin
    if (rst) begin
      prs1_ready_latch <= 1'b0;
    end 
    if (flush) begin
      prs1_ready_latch <= 1'b0;
    end
    // Latch CDB physical source register ready signals during a stall
    else if (dispatch_stall && cbif.valid && (rename_stage.meta.prs1_addr == cbif.prd)) begin
      prs1_ready_latch <= 1'b1;
    end
    // Reset latched signal after a stall
    else if (~dispatch_stall & dispatch_stall_dff) begin
      prs1_ready_latch <= 1'b0;
    end

    if (rst) begin
      prs2_ready_latch <= 1'b0;
    end 
    if (flush) begin
      prs2_ready_latch <= 1'b0;
    end
    // Latch CDB physical source register ready signals during a stall
    else if (dispatch_stall && cbif.valid && (rename_stage.meta.prs2_addr == cbif.prd)) begin
      prs2_ready_latch <= 1'b1;
    end
    // Reset latched signal after a stall
    else if (~dispatch_stall & dispatch_stall_dff) begin
      prs2_ready_latch <= 1'b0;
    end
  end

  // Allocate Reserveration Station Entry
  res_entry_t res_entry;
  always_comb begin
    // Default Conditions
    int_rsif.wen          = '0;
    int_rsif.wdata        = '0;
    mud_rsif.wen          = '0;
    mud_rsif.wdata        = '0;
    bra_rsif.wen          = '0;
    bra_rsif.wdata        = '0;
    mem_rsif.wen          = '0;
    mem_rsif.wdata        = '0;
    lsu_if.st_valid       = '0;
    lsu_if.st_op          = 'x;
    lsu_if.st_id          = 'x;
    lsu_if.ld_valid       = '0;
    lsu_if.ld_op          = 'x;
    lsu_if.ld_id          = 'x;
    lsu_if.st_branch_mask = 'x;
    lsu_if.ld_branch_mask = 'x;

    // Format RES Entry
    res_entry.valid          = 1'b0;
    res_entry.ctrl           = rename_stage.ctrl;
    res_entry.meta           = rename_stage.meta;
    res_entry.meta.prd_addr  = free_prd;
    res_entry.meta.rob_index = rob_index;
    res_entry.meta.cob_index = cob_index;
    res_entry.meta.branch_mask = global_bmask;

    // CDB Snoop/Forwarding Logic for Reservation Entry
    if (cbif.valid && (rename_stage.meta.prs1_addr == cbif.prd)) begin
      res_entry.meta.prs1_ready = 1'b1;
    end
    if (cbif.valid && (rename_stage.meta.prs2_addr == cbif.prd)) begin
      res_entry.meta.prs2_ready = 1'b1;
    end

    // CDB Snoop/Forwarding Logic with Stalls
    if (dispatch_stall_dff) begin
      res_entry.meta.prs1_ready |= prs1_ready_latch;
      res_entry.meta.prs2_ready |= prs2_ready_latch;
    end

    // Only enqueue to reservation station if not stalled
    if (~dispatch_stall && ~flush && rename_stage.valid) begin
      res_entry.valid = 1'b1;

      if (int_type) begin
        int_rsif.wen = 1'b1;
        int_rsif.wdata = res_entry;
      end else if (mud_type) begin
        mud_rsif.wen = 1'b1;
        mud_rsif.wdata = res_entry;
      end else if (bra_type) begin
        bra_rsif.wen   = 1'b1;
        bra_rsif.wdata = res_entry;
      end else if (st_type) begin
        mem_rsif.wen          = 1'b1;
        mem_rsif.wdata        = res_entry;
        lsu_if.st_valid       = 1'b1;
        lsu_if.st_op          = res_entry.ctrl.funct3;
        lsu_if.st_id          = rob_index;
        lsu_if.st_branch_mask = global_bmask;
      end else if (ld_type) begin
        mem_rsif.wen          = 1'b1;
        mem_rsif.wdata        = res_entry;
        lsu_if.ld_valid       = 1'b1;
        lsu_if.ld_op          = res_entry.ctrl.funct3;
        lsu_if.ld_id          = rob_index;
        lsu_if.ld_branch_mask = global_bmask;
      end
    end
  end

  // RVFI Logic
  always_comb begin
    rob_entry.rvfi = rename_stage.rvfi;
    res_entry.rvfi = rename_stage.rvfi;
  end

endmodule : dispatch
