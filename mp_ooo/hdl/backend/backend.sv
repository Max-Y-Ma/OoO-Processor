/**
 * Module: backend
 * File  : backend.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Port Description:
 * ------------
 * This is the top-level module for the out-of-order backend.
 * It interfaces with the instruction queue to support superscalar execution.
 * Additionally, it provides two separate queues downstream for the load and store modules.
 *
 * Module Description:
 * ------------
 * This module houses the instruction queue read logic. It facilitates parallel computation
 * of the rename and decode stages following the retrieval of an instruction from the queue.
 * These signals are subsequently directed to the out-of-order datapath for execution.
*/
module backend
import backend_types::*;
(
  input logic clk, rst,

  // Branch Logic Signals
  output logic        branch, 
  output logic        br_en,
  output logic [31:0] target_addr,
  output logic [31:0] pc_out,
  
  // Branch Resolution Bus
  output cob_entry_t                cob_data_wire [COB_DEPTH],
  output logic [COB_ADDR_WIDTH-1:0] br_tag,
  brb_itf.req                       brif,
  output logic                      coif_full,
  output logic [COB_ADDR_WIDTH-1:0] coif_index,
  input logic                       coif_allocate,
  input logic [COB_DEPTH-1:0]       coif_mask,

  // Instruction Queue Read Port
  output logic    iqueue_ren,
  input  iqueue_t iqueue_rdata,
  input  logic    iqueue_empty,

  // Data Memory Port
  output logic [31:0] dmem_addr,
  output logic [3:0]  dmem_rmask,
  output logic [3:0]  dmem_wmask,
  input  logic [31:0] dmem_rdata,
  output logic [31:0] dmem_wdata,
  input  logic        dmem_resp
);

  // Interface Ports
  rat_i                             rtif();
  rrf_i                             rrif();
  free_list_i                       flif();
  rob_i                             rbif();
  res_i #(.DEPTH(INT_ISSUE_DEPTH))  int_rsif();
  res_i #(.DEPTH(MUD_ISSUE_DEPTH))  mud_rsif();
  res_i #(.DEPTH(BR_ISSUE_DEPTH))   bra_rsif();
  res_i #(.DEPTH(MEM_ISSUE_DEPTH))  mem_rsif();
  prf_i                             pfif();
  cdb_i                             cbif();
  cob_itf                           coif();
  lsu_itf                           lsu_if();

  // Frontend COB Interface Ports
  assign coif_full = coif.full;
  assign coif_index = coif.index;
  assign coif.allocate = coif_allocate;
  assign coif.mask = coif_mask;

  /* TODO GET RID OF */
  issue_stage_t              lsu_agu_stage;
  logic                      lsu_agu_valid;
  logic [ROB_ADDR_WIDTH-1:0] lsu_agu_id;
  logic [31:0]               lsu_agu_addr;
  logic [31:0]               lsu_agu_wdata;
  logic [3:0]                lsu_agu_mask;
  logic                      lsu_agu_ready;
  issue_stage_t              lsu_ostage;
  logic                      lsu_ovalid;
  logic                      lsu_oready;
  logic [31:0]               lsu_oresult;
  logic [31:0]               lsu_oaddr;
  logic [3:0]                lsu_omask;

  // Datapath/Components
  logic store, load;
  logic commit_store, commit_load;
  datapath datapath0 (
    .clk(clk),
    .rst(rst),
    .store(store),
    .load(load),
    .rtif(rtif.r),         // RAT Interface
    .rrif(rrif.r),         // RRF Interface
    .flif(flif.r),         // Free List Interface
    .rbif(rbif.r),         // ROB Interface
    .int_rsif(int_rsif.r), // Integer Reservation Interface
    .mud_rsif(mud_rsif.r), // Multiply/Division Interface
    .bra_rsif(bra_rsif.r), // Branch Reservation Interface
    .mem_rsif(mem_rsif.r), // Memory Reservation Interface
    .pfif(pfif.r),         // Physical Reg Interface
    .coif(coif.r),
    .cob_data_wire(cob_data_wire),
    .brif(brif),                  // Branch Resolution Bus Interface
    .cbif(cbif.req)       // Common Data Bus Interface
  );

  // Pipeline Stages
  rename_stage_t rename_stage;
  issue_stage_t issue_stage;

  // Stall Signals
  logic dispatch_stall;

  // Memory absolute UNIT
  logic [STORE_ADDR_WIDTH:0] lsu_store_wptr;
  lsu lsu0(
    .clk(clk),
    .rst(rst),
    .rob_if(rbif.lsu),
    .lsu_if(lsu_if.lsu),
    .cob_data_wire(cob_data_wire),
    .lsu_store_wptr(lsu_store_wptr),
    .brif(brif),
    .agu_stage(lsu_agu_stage),
    .agu_valid(lsu_agu_valid),
    .agu_id(lsu_agu_id),
    .agu_addr(lsu_agu_addr),
    .agu_wdata(lsu_agu_wdata),
    .agu_mask(lsu_agu_mask),
    .agu_ready(lsu_agu_ready),
    .lsu_ostage(lsu_ostage),
    .lsu_ovalid(lsu_ovalid),
    .lsu_oready(lsu_oready),
    .lsu_oresult(lsu_oresult),
    .lsu_oaddr(lsu_oaddr),
    .lsu_omask(lsu_omask),
    .dmem_addr(dmem_addr),
    .dmem_rmask(dmem_rmask),
    .dmem_wmask(dmem_wmask),
    .dmem_rdata(dmem_rdata),
    .dmem_wdata(dmem_wdata),
    .dmem_resp(dmem_resp)
  );

  // Rename Stage
  rename rename0 (
    .clk(clk),
    .rst(rst),
    .iqueue_ren(iqueue_ren),
    .iqueue_rdata(iqueue_rdata),
    .iqueue_empty(iqueue_empty),
    .dispatch_stall(dispatch_stall),
    .rtif(rtif.rename),
    .flif(flif.rename),
    .brif(brif),
    .rename_stage(rename_stage)
  );

  // Dispatch Stage
  dispatch dispatch0 (
    .clk(clk),
    .rst(rst),
    .dispatch_stall(dispatch_stall),
    .rtif(rtif.d),
    .flif(flif.d),
    .rbif(rbif.d),
    .lsu_if(lsu_if.d),
    .int_rsif(int_rsif.d),
    .mud_rsif(mud_rsif.d),
    .bra_rsif(bra_rsif.d),
    .mem_rsif(mem_rsif.d),
    .coif(coif.d),
    .lsu_store_wptr(lsu_store_wptr),
    .brif(brif),
    .cbif(cbif.req),
    .irename_stage(rename_stage)
  );

  // Issue Stage
  logic issue;
  logic [NUM_EU-1:0] eu_ready;
  issue issue0 (
    .issue(issue),
    .eu_ready(eu_ready),
    .int_rsif(int_rsif.issue),
    .mud_rsif(mud_rsif.issue),
    .bra_rsif(bra_rsif.issue),
    .mem_rsif(mem_rsif.issue),
    .pfif(pfif.issue),
    .issue_stage(issue_stage)
  );

  // Execute Stage
  logic issue_store;
  execute execute0 (
    .clk(clk),
    .rst(rst),
    .issue(issue),
    .eu_ready(eu_ready),
    .branch(branch),
    .br_en(br_en),
    .target_addr(target_addr),
    .pc_out(pc_out),
    .br_tag(br_tag),
    .coif(coif.execute), 
    .brif(brif),
    .cbif(cbif.r),
    .issue_stage(issue_stage),
    .lsu_agu_stage(lsu_agu_stage),
    .lsu_agu_valid(lsu_agu_valid),
    .lsu_agu_id(lsu_agu_id),
    .lsu_agu_addr(lsu_agu_addr),
    .lsu_agu_wdata(lsu_agu_wdata),
    .lsu_agu_mask(lsu_agu_mask),
    .lsu_agu_ready(lsu_agu_ready),
    .lsu_ostage(lsu_ostage),
    .lsu_ovalid(lsu_ovalid),
    .lsu_oready(lsu_oready),
    .lsu_oresult(lsu_oresult),
    .lsu_oaddr(lsu_oaddr),
    .lsu_omask(lsu_omask)
  );

  // Commit Stage
  commit commit0 (
    .clk(clk),
    .rst(rst),
    .flif(flif.commit),
    .rrif(rrif.commit),
    .rbif(rbif.commit),
    .brif(brif)
  );

endmodule : backend
