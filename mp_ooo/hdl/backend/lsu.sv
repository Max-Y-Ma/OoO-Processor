module lsu
import backend_types::*;
import rv32i_types::*;
#(
  parameter  LOAD_ENTRIES  = LOAD_DEPTH,
  parameter  STORE_ENTRIES = STORE_DEPTH,
  parameter  NUM_AGU       = 1,
  localparam LD_IDX        = LOAD_ADDR_WIDTH,
  localparam ST_IDX        = STORE_ADDR_WIDTH
) (
  input  logic clk, rst,

  /* ROB interface */
  rob_i.lsu               rob_if,

  /* Dispatch interface */
  lsu_itf.lsu             lsu_if,

  /* EBR bus interface */
  input cob_entry_t       cob_data_wire [COB_DEPTH],
  output logic [ST_IDX:0] lsu_store_wptr,
  brb_itf.req             brif,

  /* AGU interface */
  input  issue_stage_t              agu_stage,
  input  logic                      agu_valid,
  input  logic [ROB_ADDR_WIDTH-1:0] agu_id,
  input  logic [31:0]               agu_addr,
  input  logic [31:0]               agu_wdata,
  input  logic [3:0]                agu_mask,
  output logic                      agu_ready,

  /* CDB interface */
  output issue_stage_t lsu_ostage,
  output logic         lsu_ovalid,
  input  logic         lsu_oready,
  output logic [31:0]  lsu_oresult,
  output logic [31:0]  lsu_oaddr,
  output logic [3:0]   lsu_omask,

  /* Memory interface */
  output logic [31:0]   dmem_addr,
  output logic [3:0]    dmem_rmask,
  output logic [3:0]    dmem_wmask,
  input  logic [31:0]   dmem_rdata,
  output logic [31:0]   dmem_wdata,
  input  logic          dmem_resp
);

  /* Store queue */
  store_queue_entry_t      store_queue     [STORE_ENTRIES-1:0];
  logic                    store_full;
  logic                    store_wrapped;
  logic [ST_IDX:0]         store_rptr;
  logic [ST_IDX:0]         store_wptr;
  logic [ST_IDX-1:0]       store_head_idx;
  logic [ST_IDX-1:0]       store_tail_idx;
  logic [ST_IDX-1:0]       store_order_idx;
  logic [ST_IDX-1:0]       store_age_idx;
  logic [ST_IDX-1:0]       store_commit_order;
  logic                    store_already_committed;
  logic                    store_queue_next_committed [STORE_ENTRIES-1:0];

  /* Wire EBR store pointer state */
  assign lsu_store_wptr = store_wptr;

  /* Load queue */
  logic [3:0]              fwd_mask        [LOAD_ENTRIES-1:0];
  logic                    fwd_allowed     [LOAD_ENTRIES-1:0];
  load_queue_entry_t       load_queue      [LOAD_ENTRIES-1:0];
  logic [ST_IDX-1:0]       load_age        [LOAD_ENTRIES-1:0];
  logic [LD_IDX:0]         load_pointer;
  logic [LD_IDX-1:0]       load_request_idx;
  logic [LD_IDX-1:0]       load_response_idx;

  logic [31:0]             fwd_load_rdata    [LOAD_ENTRIES-1:0];
  logic [LOAD_ENTRIES-1:0] fwd_load_resolved;

  /* DMEM Control Signals */
  logic st_dmem_ready;
  logic st_dmem_valid;
  logic ld_dmem_ready;
  logic ld_dmem_valid;

  logic write_req;
  logic next_write_req;
  logic dmem_ready;
  logic next_dmem_ready;
  logic dmem_load_cancel;
  logic dmem_load_cancelled;

  /* Store queue fifo */
  assign store_full     = {~store_wptr[ST_IDX], store_wptr[ST_IDX-1:0]} == store_rptr;
  assign store_tail_idx = store_wptr[ST_IDX-1:0];
  assign store_head_idx = store_rptr[ST_IDX-1:0];
  assign store_wrapped  = store_wptr[ST_IDX] ^ store_rptr[ST_IDX];

  /* Store queue shifting fifo */
  always_ff @ (posedge clk) begin
    /* Reset logic mark all entries unallocated */
    if (rst) begin
      store_wptr <= '0;
      store_rptr <= '0;
      for (int i = 0; i < STORE_ENTRIES; i++) begin
        store_queue[i].allocated <= 1'b0;
      end
    end
    /* Dequeue store upon response */
    if (dmem_resp & write_req) begin
      /* Deallocate entry */
      store_queue[store_head_idx].allocated <= 1'b0;
      /* Move read pointer up the queue */
      store_rptr <= store_rptr + 1'b1;
    end
    /* Processing ROB store retirements, implying next store is resolved */
    /* Process the first unresolved store that we see, and only 1 */
    /* Note: dmem cannot fire and the resolution of the store be entry 0 */
    for (int i = 0; i < STORE_ENTRIES; i++) begin
      store_queue[i].committed <= store_queue_next_committed[i];
    end
    /* Insertion of new store request */
    if (lsu_if.st_valid & lsu_if.st_ready) begin
      /* Allocate entry at write ptr */
      store_queue[store_tail_idx].allocated   <= 1'b1;
      store_queue[store_tail_idx].committed   <= 1'b0;
      store_queue[store_tail_idx].resolved    <= 1'b0;
      store_queue[store_tail_idx].id          <= lsu_if.st_id;
      store_queue[store_tail_idx].op          <= lsu_if.st_op;
      store_queue[store_tail_idx].branch_mask <= lsu_if.st_branch_mask;
      store_wptr                              <= store_wptr + 1'b1;

      // Concurrent BRB Update Logic
      if (brif.broadcast) begin
        if (lsu_if.st_branch_mask[brif.tag]) begin
          if (brif.clean) begin
            store_queue[store_tail_idx].branch_mask[brif.tag] <= 1'b0;
          end
          else if (brif.kill && ~store_queue[store_tail_idx].committed) begin
            store_queue[store_tail_idx].allocated <= 1'b0;
            store_queue[store_tail_idx].resolved  <= 1'b0;
            store_queue[store_tail_idx].committed <= 1'b0;
            store_wptr <= cob_data_wire[brif.tag].store_wptr;
          end
        end
      end
    end
    /* AGU resolution of a store, since IDs are unique no load conflict */
    if (agu_valid) begin
      /* Find entry that has the same ROB ID and fill it out */
      for (int i = 0; i < STORE_ENTRIES; i++) begin
        if (store_queue[i].allocated & store_queue[i].id == agu_id &
          ~store_queue[i].resolved) begin
          store_queue[i].addr     <= { agu_addr[31:2], 2'b0 };
          store_queue[i].resolved <= 1'b1;
          store_queue[i].wmask    <= agu_mask;
          store_queue[i].wdata    <= agu_wdata;
        end
      end
    end

    // BRB flush logic for allocated store entries
    for (int i = 0; i < STORE_ENTRIES; i++) begin
      if (store_queue[i].allocated) begin
        if (brif.broadcast) begin
          if (store_queue[i].branch_mask[brif.tag]) begin
            if (brif.clean) begin
              store_queue[i].branch_mask[brif.tag] <= 1'b0;
            end
            else if (brif.kill && ~store_queue[i].committed) begin
              store_queue[i].allocated <= 1'b0;
              store_queue[i].resolved  <= 1'b0;
              store_queue[i].committed <= 1'b0;
              store_wptr <= cob_data_wire[brif.tag].store_wptr;
            end
          end
        end
      end
    end
  end

  /* Store queue comb logic */
  always_comb begin
    store_commit_order      = store_head_idx;
    store_already_committed = 1'b0;
    for (int i = 0; i < STORE_ENTRIES; i++) begin
      store_queue_next_committed[i] = store_queue[i].committed;
    end
    for (int i = 0; i < STORE_ENTRIES; i++) begin
      if (rob_if.ren & rob_if.rdata.store) begin
        if (store_queue[store_commit_order].allocated &
          ~store_queue[store_commit_order].committed & ~store_already_committed) begin
          store_queue_next_committed[store_commit_order] = 1'b1;
          store_already_committed                        = 1'b1;
        end
      end
      store_commit_order = store_commit_order + 1'b1;
    end
  end

  /* Load queue FF logic */
  always_ff @ (posedge clk) begin
    /* Reset behaviour */
    if (rst) begin
      for (int i = 0; i < LOAD_ENTRIES; i++) begin
        load_queue[i].allocated              <= '0;
        load_queue[i].addr_resolved          <= '0;
        load_queue[i].data_resolved          <= '0;
        load_queue[i].fired                  <= '0;
      end
    end
    /* CDB Response request dequeue one load, backpressurable */
    if (lsu_oready & lsu_ovalid) begin
      for (int i = LOAD_ENTRIES-1; i >= 0; i--) begin
        if (load_queue[i].data_resolved & load_queue[i].allocated) begin
          load_queue[i].allocated     <= '0;
          load_queue[i].data_resolved <= '0;
          load_queue[i].addr_resolved <= '0;
          load_queue[i].fired         <= '0;
          break;
        end
      end
    end
    /* AGU Response update corresponding load */
    if (agu_valid) begin
      for (int i = 0; i < LOAD_ENTRIES; i++) begin
        if (load_queue[i].allocated & load_queue[i].id == agu_id) begin
          load_queue[i].addr          <= agu_addr;
          load_queue[i].stage         <= agu_stage;
          load_queue[i].addr_resolved <= 1'b1;
          load_queue[i].req_mask      <= agu_mask;
        end
      end
    end
    /* Dispatch response allocate new load */
    if (lsu_if.ld_valid & lsu_if.ld_ready) begin
      for (int i = 0; i < LOAD_ENTRIES; i++) begin
        if (load_queue[i].allocated == '0) begin
          load_queue[i].allocated      <= '1;
          load_queue[i].id             <= lsu_if.ld_id;
          load_queue[i].op             <= lsu_if.ld_op;
          load_queue[i].branch_mask    <= lsu_if.ld_branch_mask;
          load_queue[i].addr_resolved  <= '0;
          load_queue[i].data_resolved  <= '0;
          load_queue[i].fired          <= '0;

          /* Forward age during store dequeue */
          if (dmem_resp & write_req) begin
            if (ST_IDX'({1'b1, store_tail_idx} - {1'b0, store_head_idx}) == ST_IDX'(1)) begin
              load_age[i] <= '0;
              load_queue[i].fire_ready   <= 1'b1;
            end
            else begin
              load_queue[i].fire_ready   <= 1'b0;
              load_age[i] <= ST_IDX'({1'b1, store_tail_idx} - {1'b0, store_head_idx} - 1'b1);
            end
          end
          /* Non-forwarding case */
          else begin
            if (store_rptr == store_wptr) begin
              load_age[i] <= '0;
              load_queue[i].fire_ready   <= 1'b1;
            end
            else begin
              load_queue[i].fire_ready   <= 1'b0;
              load_age[i] <= ST_IDX'({1'b1, store_tail_idx} - {1'b0, store_head_idx});
            end
          end

          // Concurrent BRB Update Logic
          if (brif.broadcast) begin
            if (lsu_if.ld_branch_mask[brif.tag]) begin
              if (brif.clean) begin
                load_queue[i].branch_mask[brif.tag] <= 1'b0;
              end
              else if (brif.kill) begin
                load_queue[i].allocated     <= 1'b0;
                load_queue[i].fire_ready    <= 1'b0;
                load_queue[i].data_resolved <= 1'b0;
                load_queue[i].addr_resolved <= 1'b0;
              end
            end
          end
          break;
        end
      end
    end

    /* DMEM Response update corresponding load can't apply backpressure */
    /* Note: response and dequeue on the same entry can't occur (maybe) */
    if (dmem_resp & ~write_req & ~dmem_load_cancelled) begin
      if (load_queue[load_response_idx].allocated) begin
        load_queue[load_response_idx].rdata                 <= dmem_rdata;
        load_queue[load_response_idx].stage.rvfi.mem_rdata  <= dmem_rdata;
        load_queue[load_response_idx].data_resolved         <= 1'b1;
      end
    end

    /* Store load forwarding only on allocated loads */
    for (int i = 0; i < LOAD_ENTRIES; i++) begin
      if (fwd_load_resolved[i]) begin
        load_queue[i].rdata                <= fwd_load_rdata[i];
        load_queue[i].data_resolved        <= fwd_load_resolved[i];
        load_queue[i].stage.rvfi.mem_rdata <= fwd_load_rdata[i];
      end
    end

    /* Age change during store fire and age checking */
    if (dmem_resp & write_req) begin
      for (int i = 0; i < LOAD_ENTRIES; i++) begin
        if (load_queue[i].allocated) begin
          load_age[i] <= load_age[i] - 1'b1;
          if ((load_age[i] == ST_IDX'(1)) & (load_queue[i].allocated)) begin
            load_queue[i].fire_ready <= 1'b1;
          end
        end
      end
    end

    /* Mark as fired during a load firing event */
    if (ld_dmem_valid & (~write_req | ~st_dmem_valid)) begin
      load_queue[load_request_idx].fired <= 1'b1;
    end

    // BRB flush logic for allocated load entries
    dmem_load_cancel <= 1'b0;
    for (int i = 0; i < LOAD_ENTRIES; i++) begin
      if (load_queue[i].allocated) begin
        if (brif.broadcast) begin
          if (load_queue[i].branch_mask[brif.tag]) begin
            if (brif.clean) begin
              load_queue[i].branch_mask[brif.tag] <= 1'b0;
            end
            else if (brif.kill) begin
              load_queue[i].allocated     <= 1'b0;
              load_queue[i].fire_ready    <= 1'b0;
              load_queue[i].data_resolved <= 1'b0;
              load_queue[i].addr_resolved <= 1'b0;
              if (load_queue[i].fired) begin
                dmem_load_cancel          <= 1'b1;
              end
            end
          end
        end
      end
    end
  end

  /* Load queue Combinational logic */
  always_comb begin

    /* Load cdb logic */
    lsu_ovalid      = 1'b0;
    lsu_oresult     = 'x;
    lsu_oaddr       = 'x;
    lsu_omask       = 'x;
    lsu_ostage      = 'x;
    for (int i = 0; i < LOAD_ENTRIES; i++) begin
      if (load_queue[i].data_resolved & load_queue[i].addr_resolved
        & load_queue[i].allocated) begin
        lsu_ovalid  = 1'b1;
        lsu_oaddr   = load_queue[i].addr;
        lsu_omask   = load_queue[i].req_mask;
        lsu_ostage  = load_queue[i].stage;
        unique case ({load_queue[i].addr[1:0], load_queue[i].op})
          {2'b00, lbu}: lsu_oresult = {24'b0, load_queue[i].rdata[7:0]};
          {2'b01, lbu}: lsu_oresult = {24'b0, load_queue[i].rdata[15:8]};
          {2'b10, lbu}: lsu_oresult = {24'b0, load_queue[i].rdata[23:16]};
          {2'b11, lbu}: lsu_oresult = {24'b0, load_queue[i].rdata[31:24]};
          {2'b00, lb}:  lsu_oresult = {{24{load_queue[i].rdata[7]}},  load_queue[i].rdata[7:0]};
          {2'b01, lb}:  lsu_oresult = {{24{load_queue[i].rdata[15]}}, load_queue[i].rdata[15:8]};
          {2'b10, lb}:  lsu_oresult = {{24{load_queue[i].rdata[23]}}, load_queue[i].rdata[23:16]};
          {2'b11, lb}:  lsu_oresult = {{24{load_queue[i].rdata[31]}}, load_queue[i].rdata[31:24]};

          {2'b00, lhu}: lsu_oresult = {16'b0, load_queue[i].rdata[15:0]};
          {2'b10, lhu}: lsu_oresult = {16'b0, load_queue[i].rdata[31:16]};
          {2'b00, lh}:  lsu_oresult = {{16{load_queue[i].rdata[15]}}, load_queue[i].rdata[15:0]};
          {2'b10, lh}:  lsu_oresult = {{16{load_queue[i].rdata[31]}}, load_queue[i].rdata[31:16]};
          {2'b00, lw}:  lsu_oresult = load_queue[i].rdata;
          default:      lsu_oresult = 'x;
        endcase
      end
    end

    /* Load ready logic */
    load_request_idx = 'x;
    ld_dmem_valid    = '0;
    for (int i = 0; i < LOAD_ENTRIES; i++) begin
      if (load_queue[i].allocated & load_queue[i].addr_resolved
        & ~load_queue[i].data_resolved & load_queue[i].fire_ready) begin
          load_request_idx = unsigned'(LD_IDX'(i));
          ld_dmem_valid    = 1'b1;
      end
    end

    /* Store load forwarding combinational logic */
    for (int i = 0; i < LOAD_ENTRIES; i++) begin
      fwd_load_rdata[i]    = 'x;
      fwd_load_resolved[i] = '0;
      fwd_mask[i]          = '0;
      store_order_idx      = '0;
      store_age_idx        = '0;
      fwd_allowed[i]       = '1;
      if (load_queue[i].allocated & load_queue[i].addr_resolved) begin
        /* Look at only older allocated stores oldest to youngest */
        store_order_idx    = store_head_idx;
        store_age_idx      = '0;
        for (int j = 0; j < STORE_ENTRIES; j++) begin
          if ((store_age_idx < load_age[i]) & store_queue[store_order_idx].allocated) begin
            /* If older store is not resolved, cannot forward */
            if (~store_queue[store_order_idx].resolved) begin
              fwd_allowed[i] = '0;
            end
            else if (load_queue[i].addr[31:2] == store_queue[store_order_idx].addr[31:2]) begin
              for (int k = 0; k < 4; k++) begin
                /* FWD if requested, wmask is set */
                if (store_queue[store_order_idx].wmask[k] & load_queue[i].req_mask[k]) begin
                  fwd_load_rdata[i][8*k+:8]       = store_queue[store_order_idx].wdata[8*k+:8];
                  fwd_mask[i][k]                  = 1'b1;
                end
              end
            end
          end
          store_order_idx = store_order_idx + 1'b1;
          store_age_idx   = store_age_idx   + 1'b1;
        end
        /* See if we managed to complete the required mask and was allowed */
        if ((fwd_mask[i] & load_queue[i].req_mask) == load_queue[i].req_mask &
          fwd_allowed[i]) begin
          fwd_load_resolved[i] = 1'b1;
        end
      end
    end
  end

  /* Ready to fire to dmem when head is allocated & committed */
  assign st_dmem_valid = store_queue[store_head_idx].allocated &
                          store_queue[store_head_idx].committed;

  /* dmem arbiter */
  always_ff @ (posedge clk) begin
    if (rst) begin
      dmem_ready          <= 1'b1;
      write_req           <= 1'b0;
      dmem_load_cancelled <= 1'b0;
    end
    else begin
      /* Set next arbiter bit and ready bit */
      write_req <= next_write_req;
      dmem_ready <= next_dmem_ready;
      /* Set response idx for loads */
      if (dmem_ready) begin
        load_response_idx <= load_request_idx;
      end
      /* Set whether or not we're processing a load */
      /* Cancel loads if they are flushed */
      if (dmem_load_cancel) begin
        dmem_load_cancelled <= 1'b1;
      end
      else if (dmem_resp) begin
        dmem_load_cancelled <= 1'b0;
      end
    end
  end

  /* Arbitrate store and load queue and set AGU values */
  always_comb begin
    /* Default values */
    dmem_addr     = 'x;
    dmem_wdata    = 'x;
    dmem_rmask    = '0;
    dmem_wmask    = '0;
    st_dmem_ready = '0;
    ld_dmem_ready = '0;
    /* Don't change FF values unless we need to */
    next_write_req = write_req;
    next_dmem_ready = dmem_ready;

    if (dmem_resp) begin
      next_write_req   = ~write_req;
      next_dmem_ready  = 1'b1;
    end
    else if (dmem_ready) begin
      /* Write if write request arb or no read req */
      if (st_dmem_valid & (write_req | ~ld_dmem_valid)) begin
        /* Set dmem addr correctly */
        dmem_addr  = { store_queue[store_head_idx].addr[31:2], 2'b0};
        dmem_wdata = store_queue[store_head_idx].wdata;
        dmem_wmask = store_queue[store_head_idx].wmask;
        /* Set arbitration bit & tell store we are ready */
        next_write_req = 1'b1;
        st_dmem_ready  = 1'b1;
        /* Indicate that dmem will not be ready */
        next_dmem_ready = 1'b0;
      end
      else if (ld_dmem_valid & (~write_req | ~st_dmem_valid)) begin
        /* Set dmem addr correctly */
        dmem_addr  = { load_queue[load_request_idx].addr[31:2], 2'b0 };
        dmem_rmask = 4'b1111;
        /* Set arbitration bit & tell load we are ready */
        next_write_req   = 1'b0;
        ld_dmem_ready    = 1'b1;
        /* Indicate that dmem will not be ready soon */
        next_dmem_ready = 1'b0;
      end
    end

    /* AGU ready calculations */

    /* Accept dispatch load store requests if we are not full */
    lsu_if.ld_ready   = '0;
    for (int i = 0; i < LOAD_ENTRIES; i++) begin
      lsu_if.ld_ready |= ~load_queue[i].allocated;
    end
    lsu_if.st_ready = ~store_full;

    /* If either load or store finds a match and is ready, we are ready */
    agu_ready = '0;
    if (agu_valid) begin
      for (int i = 0; i < STORE_ENTRIES; i++) begin
        if (store_queue[i].allocated & ~store_queue[i].resolved) begin
          agu_ready = '1;
        end
      end
      for (int i = 0; i < LOAD_ENTRIES; i++) begin
        if (load_queue[i].allocated & ~load_queue[i].addr_resolved) begin
          agu_ready = '1;
        end
      end
    end
  end
endmodule : lsu
