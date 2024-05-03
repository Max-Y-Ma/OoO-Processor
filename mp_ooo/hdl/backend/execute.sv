/**
 * Module: execute
 * File  : execute.sv
 * Author: Max Ma
 * Date  : March 29, 2024
 *
 * Description:
 * ------------
 * The execute stage is responsible for containing all the execution units. It should register
 * the appropriate inputs for each execution unit and give the execution unit status to the
 * issue logic. It also contains CDB arbitration for EU outputs.
 *
 * Critical Path Analysis:
 * ------------
 * The execute stage has many execution units, the critical path could fall into one of these.
 * Additionally the arbitration logic writes to the CDB, which gets snooped by backend data structures.
 * This could become the critical patch if not careful.
*/
module execute
import backend_types::*;
import rv32i_types::*;
#(
  parameter NUM_ALU = 1,
  parameter NUM_CMP = 1,
  parameter NUM_BRU = 1,
  parameter NUM_MUL = 1,
  parameter NUM_DIV = 1,
  parameter NUM_AGU = 1
)
(
  input logic clk, rst,

  // Issue Logic
  input  logic              issue,
  output logic [NUM_EU-1:0] eu_ready,

  // Interface Ports
  cdb_i.r cbif,

  output logic                      branch, 
  output logic                      br_en,
  output logic [31:0]               target_addr,
  output logic [31:0]               pc_out,
  output logic [COB_ADDR_WIDTH-1:0] br_tag,
  cob_itf.execute                   coif,
  brb_itf.req                       brif,

  // Pipeline Stage
  input issue_stage_t               issue_stage,

  // LSU Connection
  output issue_stage_t              lsu_agu_stage,
  output logic                      lsu_agu_valid,
  output logic [ROB_ADDR_WIDTH-1:0] lsu_agu_id,
  output logic [31:0]               lsu_agu_addr,
  output logic [31:0]               lsu_agu_wdata,
  output logic [3:0]                lsu_agu_mask,
  input  logic                      lsu_agu_ready,
  input  issue_stage_t              lsu_ostage,
  input  logic                      lsu_ovalid,
  output logic                      lsu_oready,
  input  logic [31:0]               lsu_oresult,
  input  logic [31:0]               lsu_oaddr,
  input  logic [3:0]                lsu_omask
);

  // Issue State Signals
  issue_stage_t istage [NUM_EU];
  issue_stage_t ostage [NUM_EU];

  // Results
  logic [31:0] result [NUM_EU];

  /* Execution Unit Input signals */
  logic [31:0] src_a, src_b;

  /* Execution Unit Signals */
  /* ALU */
  issue_stage_t       alu_istage  [NUM_ALU-1:0];
  logic [31:0]        alu_a       [NUM_ALU-1:0];
  logic [31:0]        alu_b       [NUM_ALU-1:0];
  logic [NUM_ALU-1:0] alu_ivalid;
  logic [NUM_ALU-1:0] alu_iready;
  issue_stage_t       alu_ostage  [NUM_ALU-1:0];
  logic [31:0]        alu_oresult [NUM_ALU-1:0];
  logic [NUM_ALU-1:0] alu_ovalid;
  logic [NUM_ALU-1:0] alu_oready;
  /* CMP */
  issue_stage_t       cmp_istage  [NUM_CMP-1:0];
  logic [31:0]        cmp_a       [NUM_CMP-1:0];
  logic [31:0]        cmp_b       [NUM_CMP-1:0];
  logic [NUM_CMP-1:0] cmp_ivalid;
  logic [NUM_CMP-1:0] cmp_iready;
  issue_stage_t       cmp_ostage  [NUM_CMP-1:0];
  logic [31:0]        cmp_oresult [NUM_CMP-1:0];
  logic [NUM_CMP-1:0] cmp_ovalid;
  logic [NUM_CMP-1:0] cmp_oready;
  /* BRU */
  issue_stage_t       bru_istage  [NUM_BRU-1:0];
  logic [31:0]        bru_a       [NUM_BRU-1:0];
  logic [31:0]        bru_b       [NUM_BRU-1:0];
  logic [NUM_BRU-1:0] bru_ivalid;
  logic [NUM_BRU-1:0] bru_iready;
  issue_stage_t       bru_ostage  [NUM_BRU-1:0];
  bru_result_t        bru_oresult [NUM_BRU-1:0];
  logic [NUM_BRU-1:0] bru_ovalid;
  logic [NUM_BRU-1:0] bru_oready;
  /* MUL */
  issue_stage_t       mul_istage  [NUM_MUL-1:0];
  logic [31:0]        mul_a       [NUM_MUL-1:0];
  logic [31:0]        mul_b       [NUM_MUL-1:0];
  logic [NUM_MUL-1:0] mul_ivalid;
  logic [NUM_MUL-1:0] mul_iready;
  issue_stage_t       mul_ostage  [NUM_MUL-1:0];
  logic [31:0]        mul_oresult [NUM_MUL-1:0];
  logic [NUM_MUL-1:0] mul_ovalid;
  logic [NUM_MUL-1:0] mul_oready;
  /* DIV */
  issue_stage_t       div_istage  [NUM_DIV-1:0];
  logic [31:0]        div_a       [NUM_DIV-1:0];
  logic [31:0]        div_b       [NUM_DIV-1:0];
  logic [NUM_DIV-1:0] div_ivalid;
  logic [NUM_DIV-1:0] div_iready;
  issue_stage_t       div_ostage  [NUM_DIV-1:0];
  logic [31:0]        div_oresult [NUM_DIV-1:0];
  logic [NUM_DIV-1:0] div_ovalid;
  logic [NUM_DIV-1:0] div_oready;
  /* AGU */
  issue_stage_t       agu_istage  [NUM_AGU-1:0];
  logic [31:0]        agu_a       [NUM_AGU-1:0];
  logic [31:0]        agu_b       [NUM_AGU-1:0];
  logic [31:0]        agu_mem_wdata [NUM_AGU-1:0];
  logic [2:0]         agu_mem_op  [NUM_AGU-1:0];
  logic [NUM_DIV-1:0] agu_ivalid;
  logic [NUM_DIV-1:0] agu_iready;
  issue_stage_t       agu_ostage  [NUM_AGU-1:0];
  agu_result_t        agu_oresult [NUM_AGU-1:0];
  logic [NUM_DIV-1:0] agu_ovalid;
  logic [NUM_DIV-1:0] agu_oready;

  /* Source values based on control word*/
  assign src_a      = (issue_stage.ctrl.op1_mux == pc_out_t)  ? issue_stage.ctrl.pc  : issue_stage.psr1_data;
  assign src_b      = (issue_stage.ctrl.op2_mux == imm_out_t) ? issue_stage.ctrl.imm : issue_stage.psr2_data;

  /* Sending issued instruction to an available EU */
  always_ff @(posedge clk) begin
    // Invalidate all execution units upon a flush
    if (rst) begin
      alu_ivalid <= '0;
      cmp_ivalid <= '0;
      bru_ivalid <= '0;
      mul_ivalid <= '0;
      div_ivalid <= '0;
      agu_ivalid <= '0;
    end else begin
      // **NOTE** A stalled input EU Register will never be issued to by the issue select logic

      // **NOTE** Input EU Registers are valid if a new instruction issues to it
      // **NOTE** Input EU Registers are still valid if stalled

      // Default Condition
      alu_ivalid <= '0;
      cmp_ivalid <= '0;
      bru_ivalid <= '0;
      mul_ivalid <= '0;
      div_ivalid <= '0;
      agu_ivalid <= '0;

      // Update Input EU Register for New Issues
      /* We route the issue to the highest index available EU */
      if (issue) begin
        unique case (issue_stage.meta.euid)
          alu : begin
            for (int i = 0; i < NUM_ALU; i++) begin
              if (alu_iready[i]) begin
                alu_ivalid[i] <= 1'b1;
                alu_a[i]      <= src_a;
                alu_b[i]      <= src_b;
                alu_istage[i] <= issue_stage;

                /* BRB tag update */
                if (brif.broadcast) begin
                  if (issue_stage.meta.branch_mask[brif.tag]) begin
                    if (brif.clean) begin
                      alu_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
                    end
                    else if (brif.kill) begin
                      alu_ivalid[i]       <= 1'b0;
                      alu_istage[i].valid <= 1'b0;
                    end
                  end
                end
              end
            end
          end
          cmp : begin
            for (int i = 0; i < NUM_CMP; i++) begin
              if (cmp_iready[i]) begin
                cmp_ivalid[i] <= 1'b1;
                cmp_a[i]      <= src_a;
                cmp_b[i]      <= src_b;
                cmp_istage[i] <= issue_stage;

                /* BRB tag update */
                if (brif.broadcast) begin
                  if (issue_stage.meta.branch_mask[brif.tag]) begin
                    if (brif.clean) begin
                      cmp_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
                    end
                    else if (brif.kill) begin
                      cmp_ivalid[i]       <= 1'b0;
                      cmp_istage[i].valid <= 1'b0;
                    end
                  end
                end
              end
            end
          end
          mul : begin
            for (int i = 0; i < NUM_MUL; i++) begin
              if (mul_iready[i]) begin
                mul_ivalid[i] <= 1'b1;
                mul_a[i]      <= src_a;
                mul_b[i]      <= src_b;
                mul_istage[i] <= issue_stage;

                /* BRB tag update */
                if (brif.broadcast) begin
                  if (issue_stage.meta.branch_mask[brif.tag]) begin
                    if (brif.clean) begin
                      mul_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
                    end
                    else if (brif.kill) begin
                      mul_ivalid[i]       <= 1'b0;
                      mul_istage[i].valid <= 1'b0;
                    end
                  end
                end
              end
            end
          end
          div : begin
            for (int i = 0; i < NUM_DIV; i++) begin
              if (div_iready[i]) begin
                div_ivalid[i] <= 1'b1;
                div_a[i]      <= src_a;
                div_b[i]      <= src_b;
                div_istage[i] <= issue_stage;

                /* BRB tag update */
                if (brif.broadcast) begin
                  if (issue_stage.meta.branch_mask[brif.tag]) begin
                    if (brif.clean) begin
                      div_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
                    end
                    else if (brif.kill) begin
                      div_ivalid[i]       <= 1'b0;
                      div_istage[i].valid <= 1'b0;
                    end
                  end
                end
              end
            end
          end
          agu : begin
            for (int i = 0; i < NUM_AGU; i++) begin
              if (agu_iready[i]) begin
                agu_ivalid[i]    <= 1'b1;
                agu_a[i]         <= src_a;
                agu_b[i]         <= src_b;
                agu_mem_wdata[i] <= issue_stage.psr2_data;
                agu_mem_op[i]    <= issue_stage.ctrl.funct3;
                agu_istage[i]    <= issue_stage;

                /* BRB tag update */
                if (brif.broadcast) begin
                  if (issue_stage.meta.branch_mask[brif.tag]) begin
                    if (brif.clean) begin
                      agu_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
                    end
                    else if (brif.kill) begin
                      agu_ivalid[i]       <= 1'b0;
                      agu_istage[i].valid <= 1'b0;
                    end
                  end
                end
              end
            end
          end
          bru : begin
            for (int i = 0; i < NUM_BRU; i++) begin
              if (bru_iready[i]) begin
                bru_ivalid[i] <= 1'b1;
                bru_a[i]      <= src_a;
                bru_b[i]      <= src_b;
                bru_istage[i] <= issue_stage;

                /* BRB tag update */
                if (brif.broadcast) begin
                  if (issue_stage.meta.branch_mask[brif.tag]) begin
                    if (brif.clean) begin
                      bru_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
                    end
                    else if (brif.kill) begin
                      bru_ivalid[i]       <= 1'b0;
                      bru_istage[i].valid <= 1'b0;
                    end
                  end
                end
              end
            end
          end
          default : begin end
        endcase
      end

      /* Keep input signals valid during stalls for none stale inputs (different rob entries) */
      for (int i = 0; i < NUM_ALU; i++) begin
        if (~eu_ready[alu] && alu_istage[i].meta.rob_index != alu_ostage[i].meta.rob_index && alu_istage[i].valid) begin
          alu_ivalid[i] <= 1'b1;
        end
      end
      for (int i = 0; i < NUM_CMP; i++) begin
        if (~eu_ready[cmp] && cmp_istage[i].meta.rob_index != cmp_ostage[i].meta.rob_index && cmp_istage[i].valid) begin
          cmp_ivalid[i] <= 1'b1;
        end
      end
      for (int i = 0; i < NUM_MUL; i++) begin
        if (~eu_ready[mul] && mul_istage[i].meta.rob_index != mul_ostage[i].meta.rob_index && mul_istage[i].valid) begin
          mul_ivalid[i] <= 1'b1;
        end
      end
      for (int i = 0; i < NUM_DIV; i++) begin
        if (~eu_ready[div] && div_istage[i].meta.rob_index != div_ostage[i].meta.rob_index && div_istage[i].valid) begin
          div_ivalid[i] <= 1'b1;
        end
      end
      for (int i = 0; i < NUM_AGU; i++) begin
        if (~eu_ready[agu] && agu_istage[i].meta.rob_index != agu_ostage[i].meta.rob_index && agu_istage[i].valid) begin
          agu_ivalid[i] <= 1'b1;
        end
      end
      for (int i = 0; i < NUM_BRU; i++) begin
        if (~eu_ready[bru] && bru_istage[i].meta.rob_index != bru_ostage[i].meta.rob_index && bru_istage[i].valid) begin
          bru_ivalid[i] <= 1'b1;
        end
      end

      /* Branch resolution clean/kill logic for stalled execution units */
      for (int i = 0; i < NUM_ALU; i++) begin
        if (~eu_ready[alu] && alu_istage[i].meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            alu_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
          end 
          else if (brif.kill) begin
            alu_ivalid[i] <= '0;
          end
        end
      end
      for (int i = 0; i < NUM_CMP; i++) begin
        if (~eu_ready[cmp] && cmp_istage[i].meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            cmp_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
          end 
          else if (brif.kill) begin
            cmp_ivalid[i] <= '0;
          end
        end
      end
      for (int i = 0; i < NUM_MUL; i++) begin
        if (~eu_ready[mul] && mul_istage[i].meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            mul_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
          end 
          else if (brif.kill) begin
            mul_ivalid[i] <= '0;
          end
        end
      end
      for (int i = 0; i < NUM_DIV; i++) begin
        if (~eu_ready[div] && div_istage[i].meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            div_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
          end 
          else if (brif.kill) begin
            div_ivalid[i] <= '0;
          end
        end
      end
      for (int i = 0; i < NUM_AGU; i++) begin
        if (~eu_ready[agu] && agu_istage[i].meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            agu_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
          end 
          else if (brif.kill) begin
            agu_ivalid[i] <= '0;
          end
        end
      end
      for (int i = 0; i < NUM_BRU; i++) begin
        if (~eu_ready[bru] && bru_istage[i].meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            bru_istage[i].meta.branch_mask[brif.tag] <= 1'b0;
          end 
          else if (brif.kill) begin
            bru_ivalid[i] <= '0;
          end
        end
      end
    end
  end

  /* Output arbitration & ready / stall logic */
  always_comb begin
    // **NOTE** The following behavioral model for CDB arbitration implies euid with highest index has largest priority
    // **NOTE** The arbitrator could implement a BREAK statement, but I wonder if that is synthesizable

    /* EU ready signal is high as long as there is one available EU of that type */
    eu_ready[alu] = |alu_iready;
    eu_ready[cmp] = |cmp_iready;
    eu_ready[bru] = |bru_iready;
    eu_ready[mul] = |mul_iready;
    eu_ready[div] = |div_iready;
    eu_ready[agu] = |agu_iready;

    /* Default that none of the EUs are ready to be pulled onto the CDB */
    alu_oready = '0;
    cmp_oready = '0;
    bru_oready = '0;
    mul_oready = '0;
    div_oready = '0;
    agu_oready = '0;
    lsu_oready = '0;

    /* Default branch resolution output */
    branch      = '0;
    br_en       = '0;
    target_addr = '0;
    pc_out      = '0;
    br_tag      = '0;
    
    coif.ren    = '0;
    coif.raddr  = '0;

    /* Default CBIF values */
    cbif.valid       = '0;
    cbif.ard         = 'x;
    cbif.prd         = 'x;
    cbif.rob_index   = 'x;
    cbif.result      = 'x;

    /* Default LSU values */
    lsu_agu_valid    = '0;
    lsu_agu_stage    = 'x;
    lsu_agu_id       = 'x;
    lsu_agu_addr     = 'x;
    lsu_agu_wdata    = 'x;
    lsu_agu_mask     = 'x;

    /* Default PC wdata values */
    cbif.rvfi = '0;

    /* Perform arbitrary arbitration on CDB */

    /* CMP sixth */
    for (int i = 0; i < NUM_CMP; i++) begin
      // Concurrent BRB Update for CDB
      if (brif.broadcast) begin
        if (cmp_ostage[i].meta.branch_mask[brif.tag] == 1'b1 && brif.kill) begin
          continue;
        end
      end

      if(cmp_ovalid[i]) begin
        // BRB tag update for CDB
        if (~(brif.broadcast && cmp_ostage[i].meta.branch_mask[brif.tag] && brif.kill)) begin
          // Assert Appropriate CDB Output
          cbif.valid         = 1'b1;
          cbif.ard           = cmp_ostage[i].meta.ard_addr;
          cbif.prd           = cmp_ostage[i].meta.prd_addr;
          cbif.rob_index     = cmp_ostage[i].meta.rob_index;
          cbif.result        = cmp_oresult[i];
          if (~(|bru_ovalid) & ~lsu_ovalid & ~(|agu_ovalid) & ~(|div_ovalid) &
            ~(|mul_ovalid) & ~(|alu_ovalid)) begin
            cmp_oready         = '1;
          end

          /* RVFI */
          cbif.rvfi          = cmp_ostage[i].rvfi;
          cbif.rvfi.rd_wdata = cmp_oresult[i];
          cbif.rvfi.pc_wdata = cmp_ostage[i].rvfi.pc_rdata + 'h4;
        end
      end
    end
    /* ALU fifth */
    for (int i = 0; i < NUM_ALU; i++) begin
      // Concurrent BRB Update for CDB
      if (brif.broadcast) begin
        if (alu_ostage[i].meta.branch_mask[brif.tag] == 1'b1 && brif.kill) begin
          continue;
        end
      end

      if(alu_ovalid[i]) begin
        // BRB tag update for CDB
        if (~(brif.broadcast && alu_ostage[i].meta.branch_mask[brif.tag] && brif.kill)) begin
          // Assert Appropriate CDB Output
          cbif.valid         = 1'b1;
          cbif.ard           = alu_ostage[i].meta.ard_addr;
          cbif.prd           = alu_ostage[i].meta.prd_addr;
          cbif.rob_index     = alu_ostage[i].meta.rob_index;
          cbif.result        = alu_oresult[i];
          if (~(|bru_ovalid) & ~lsu_ovalid & ~(|agu_ovalid) & ~(|div_ovalid) &
            ~(|mul_ovalid)) begin
            alu_oready         = '1;
          end
          /* RVFI */
          cbif.rvfi          = alu_ostage[i].rvfi;
          cbif.rvfi.rd_wdata = alu_oresult[i];
          cbif.rvfi.pc_wdata = alu_ostage[i].rvfi.pc_rdata + 'h4;
        end
      end
    end
    /* MUL fourth */
    for (int i = 0; i < NUM_MUL; i++) begin
      // Concurrent BRB Update for CDB
      if (brif.broadcast) begin
        if (mul_ostage[i].meta.branch_mask[brif.tag] == 1'b1 && brif.kill) begin
          continue;
        end
      end

      if(mul_ovalid[i]) begin
        // BRB tag update for CDB
        if (~(brif.broadcast && mul_ostage[i].meta.branch_mask[brif.tag] && brif.kill)) begin
          // Assert Appropriate CDB Output
          cbif.valid       = 1'b1;
          cbif.ard         = mul_ostage[i].meta.ard_addr;
          cbif.prd         = mul_ostage[i].meta.prd_addr;
          cbif.rob_index   = mul_ostage[i].meta.rob_index;
          cbif.result      = mul_oresult[i];
          if (~(|bru_ovalid) & ~lsu_ovalid & ~(|agu_ovalid) & ~(|div_ovalid)) begin
            mul_oready       = '1;
          end
          /* RVFI */
          cbif.rvfi          = mul_ostage[i].rvfi;
          cbif.rvfi.rd_wdata = mul_oresult[i];
          cbif.rvfi.pc_wdata = mul_ostage[i].rvfi.pc_rdata + 'h4;
        end
      end
    end
    /* DIV third */
    for (int i = 0; i < NUM_DIV; i++) begin
      // Concurrent BRB Update for CDB
      if (brif.broadcast) begin
        if (div_ostage[i].meta.branch_mask[brif.tag] == 1'b1 && brif.kill) begin
          continue;
        end
      end

      if(div_ovalid[i]) begin
        // BRB tag update for CDB
        if (~(brif.broadcast && div_ostage[i].meta.branch_mask[brif.tag] && brif.kill)) begin
          // Assert Appropriate CDB Output
          cbif.valid       = 1'b1;
          cbif.ard         = div_ostage[i].meta.ard_addr;
          cbif.prd         = div_ostage[i].meta.prd_addr;
          cbif.rob_index   = div_ostage[i].meta.rob_index;
          cbif.result      = div_oresult[i];
          if (~(|bru_ovalid) & ~lsu_ovalid & ~(|agu_ovalid)) begin
            div_oready       = '1;
          end
          /* RVFI */
          cbif.rvfi          = div_ostage[i].rvfi;
          cbif.rvfi.rd_wdata = div_oresult[i];
          cbif.rvfi.pc_wdata = div_ostage[i].rvfi.pc_rdata + 'h4;
        end
      end
    end
    /* AGU second */
    for (int i = 0; i < NUM_AGU; i++) begin
      // Concurrent BRB Update for CDB
      if (brif.broadcast) begin
        if (agu_ostage[i].meta.branch_mask[brif.tag] == 1'b1 && brif.kill) begin
          continue;
        end
      end

      if(agu_ovalid[i]) begin
        /* Make sure that only non-flushed instructions go to CDB / LSU */
        if (~(brif.broadcast && agu_ostage[i].meta.branch_mask[brif.tag] && brif.kill)) begin
          /* Give LSU our info */
          lsu_agu_valid    = 1'b1;
          lsu_agu_stage    = agu_ostage[i];
          lsu_agu_id       = agu_ostage[i].meta.rob_index;
          lsu_agu_addr     = agu_oresult[i].mem_addr;
          lsu_agu_mask     = agu_oresult[i].mem_mask;
          lsu_agu_wdata    = agu_oresult[i].mem_wdata;
          /* Store case we are on the CDB arbitration */
          if (agu_ostage[i].ctrl.mem_write) begin
            /* Make sure that we are arbitrated to go */
            if (~(|bru_ovalid) & (~lsu_ovalid)) begin
              // Assert Appropriate CDB Output
              cbif.valid       = 1'b1;
              cbif.ard         = agu_ostage[i].meta.ard_addr;
              cbif.prd         = agu_ostage[i].meta.prd_addr;
              cbif.rob_index   = agu_ostage[i].meta.rob_index;
              cbif.result      = agu_oresult[i].mem_wdata;
              /* RVFI */
              cbif.rvfi           = agu_ostage[i].rvfi;
              cbif.rvfi.mem_wmask = agu_oresult[i].mem_mask;
              cbif.rvfi.mem_wdata = agu_oresult[i].mem_wdata;
              cbif.rvfi.mem_addr  = agu_oresult[i].mem_addr;
              cbif.rvfi.mem_rmask = '0;
              cbif.rvfi.pc_wdata  = agu_ostage[i].rvfi.pc_rdata + 'h4;
              /* Indicate that the store as committed */
              agu_oready = '1;
            end
          end
          /* Load case we are not on the CDB, no arbitration */
          else begin
            /* Assert valid to the LSU and relavent data */
            /* If the lsu is ready, we can tell the agu we chilling */
            if (lsu_agu_ready) begin
              agu_oready = '1;
            end
          end
        end
      end
    end
    /* Load results first */
    if (lsu_ovalid) begin
      // Concurrent BRB Update for CDB
      if (~(brif.broadcast && lsu_ostage.meta.branch_mask[brif.tag] == 1'b1 && brif.kill)) begin
        cbif.valid       = 1'b1;
        cbif.ard         = lsu_ostage.meta.ard_addr;
        cbif.prd         = lsu_ostage.meta.prd_addr;
        cbif.rob_index   = lsu_ostage.meta.rob_index;
        cbif.result      = lsu_oresult;
        if (~(|bru_ovalid)) begin
          lsu_oready       = '1;
        end
        /* RVFI */
        cbif.rvfi           = lsu_ostage.rvfi;
        cbif.rvfi.mem_addr  = lsu_oaddr;
        cbif.rvfi.mem_rmask = lsu_omask;
        cbif.rvfi.mem_wmask = '0;
        cbif.rvfi.rd_wdata  = lsu_oresult;
        cbif.rvfi.pc_wdata  = lsu_ostage.rvfi.pc_rdata + 'h4;
      end
    end
    /* Branch zeroeth */
    for (int i = 0; i < NUM_BRU; i++) begin
      // Concurrent BRB Update for CDB
      if (brif.broadcast) begin
        if (bru_ostage[i].meta.branch_mask[brif.tag] == 1'b1 && brif.kill) begin
          continue;
        end
      end

      if(bru_ovalid[i]) begin
        // BRB tag update for CDB
        if (~(brif.broadcast && bru_ostage[i].meta.branch_mask[brif.tag] && brif.kill)) begin
          // Assert Appropriate CDB Output
          cbif.valid       = 1'b1;
          cbif.ard         = bru_ostage[i].meta.ard_addr;
          cbif.prd         = bru_ostage[i].meta.prd_addr;
          cbif.rob_index   = bru_ostage[i].meta.rob_index;
          cbif.result      = bru_oresult[i].return_addr;
          bru_oready       = '1;
          /* Branch Resolution Output */
          branch           = 1'b1;
          br_en            = bru_oresult[i].br_en;
          target_addr      = bru_oresult[i].target_addr;
          pc_out           = bru_ostage[i].ctrl.pc;
          br_tag           = bru_ostage[i].meta.cob_index;

          coif.ren         = 1'b1;
          coif.raddr       = bru_ostage[i].meta.cob_index;

          /* RVFI */
          cbif.rvfi           = bru_ostage[i].rvfi;
          cbif.rvfi.rd_wdata  = bru_oresult[i].return_addr;
          cbif.rvfi.pc_wdata  = bru_oresult[i].br_en ? 
            bru_oresult[i].target_addr : bru_ostage[i].rvfi.pc_rdata + 'h4;
        end
      end
    end
  end

  /* Execution Unit Generates */
  genvar i;
  generate
  for (i = 0; i < NUM_ALU; i++) begin
    alu alu0 (
      .clk(clk),
      .rst(rst),
      .brif(brif),
      .istage(alu_istage[i]),
      .alu_a(alu_a[i]),
      .alu_b(alu_b[i]),
      .ivalid(alu_ivalid[i]),
      .iready(alu_iready[i]),
      .ostage(alu_ostage[i]),
      .oresult(alu_oresult[i]),
      .ovalid(alu_ovalid[i]),
      .oready(alu_oready[i])
    );
  end
  endgenerate

  generate
  for (i = 0; i < NUM_CMP; i++) begin
    cmp cmp0 (
      .clk(clk),
      .rst(rst),
      .brif(brif),
      .istage(cmp_istage[i]),
      .cmp_a(cmp_a[i]),
      .cmp_b(cmp_b[i]),
      .ivalid(cmp_ivalid[i]),
      .iready(cmp_iready[i]),
      .ostage(cmp_ostage[i]),
      .oresult(cmp_oresult[i]),
      .ovalid(cmp_ovalid[i]),
      .oready(cmp_oready[i])
    );
  end
  endgenerate

  generate
  for (i = 0; i < NUM_BRU; i++) begin
    bru bru0 (
      .clk(clk),
      .rst(rst),
      .brif(brif),
      .istage(bru_istage[i]),
      .bru_a(bru_a[i]),
      .bru_b(bru_b[i]),
      .ivalid(bru_ivalid[i]),
      .iready(bru_iready[i]),
      .ostage(bru_ostage[i]),
      .oresult(bru_oresult[i]),
      .ovalid(bru_ovalid[i]),
      .oready(bru_oready[i])
    );
  end
  endgenerate

  generate
    for (i = 0; i < NUM_MUL; i++) begin
      multiplier multiplier0 (
        .clk(clk),
        .rst(rst),
        .brif(brif),
        .istage (mul_istage[i]),
        .mul_a  (mul_a[i]),
        .mul_b  (mul_b[i]),
        .ivalid (mul_ivalid[i]),
        .iready (mul_iready[i]),
        .ostage (mul_ostage[i]),
        .oresult(mul_oresult[i]),
        .ovalid (mul_ovalid[i]),
        .oready (mul_oready[i])
      );
    end
  endgenerate

  generate
    for (i = 0; i < NUM_DIV; i++) begin
      divider divider0 (
        .clk(clk),
        .rst(rst),
        .brif(brif),
        .istage (div_istage[i]),
        .div_a  (div_a[i]),
        .div_b  (div_b[i]),
        .ivalid (div_ivalid[i]),
        .iready (div_iready[i]),
        .ostage (div_ostage[i]),
        .oresult(div_oresult[i]),
        .ovalid (div_ovalid[i]),
        .oready (div_oready[i])
      );
    end
  endgenerate

  generate
    for(i = 0; i < NUM_AGU; i++) begin
      agu agu0 (
        .clk(clk),
        .rst(rst),
        .brif(brif),
        .istage (agu_istage[i]),
        .agu_a  (agu_a[i]),
        .agu_b  (agu_b[i]),
        .mem_op (agu_mem_op[i]),
        .mem_wdata(agu_mem_wdata[i]),
        .ivalid (agu_ivalid[i]),
        .iready (agu_iready[i]),
        .ostage (agu_ostage[i]),
        .oresult(agu_oresult[i]),
        .ovalid (agu_ovalid[i]),
        .oready (agu_oready[i])
      );
    end
  endgenerate
endmodule : execute
