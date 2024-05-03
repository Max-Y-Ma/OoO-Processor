module frontend
import frontend_types::*;
import rv32i_types::*;
import backend_types::*;
(
  input logic clk,
  input logic rst,

  input logic iqueue_full,

  /* imem signals */
  output logic [31:0] imem_addr,
  output logic [3:0]  imem_rmask,
  input logic  [31:0] imem_rdata,
  input logic         imem_resp,

  /* Backend Branch Resolution Signals */
  input logic         backend_jmp,
  input logic         backend_jmp_answer,
  /* input logic [31:0]  backend_jmp_pc, TODO: OOO Branch resolution */
  input logic [31:0]  backend_jmp_dest,

  /* Early Branch Resolution Signals */
  input  logic [COB_ADDR_WIDTH-1:0] br_tag,
  input logic                       coif_full,
  input logic [COB_ADDR_WIDTH-1:0]  coif_index,
  output logic                      coif_allocate,
  output logic [COB_DEPTH-1:0]      coif_mask,

  brb_itf.req                       brif_req,
  brb_itf.response                  brif,

  /* Downstream signals */
  output logic        instr_ready,
  output logic        [31:0] pc,

  /* Misprediction */
  input  cob_entry_t                cob_data_wire [COB_DEPTH],
  output logic [COB_ADDR_WIDTH-1:0] branch_tag,
  output logic [COB_DEPTH-1:0]      branch_mask,
  output logic        flush
);

/* Stall signals */
logic          stall;

/* Original signals that are registered for downstream */
logic [31:0]   pc_fetch;
logic          instr_v;
logic          instr_v_fetch;

/* Predictor Signals */
logic          mispredict;
logic          guess_jmp;
logic          wrong_guess;
logic          wrong_guess_addr;
branch_queue_t head_branch_queue;
logic          branch_queue_full;
logic          branch_queue_empty;
logic [31:0]   mispredict_addr;
logic          is_control_flow;

/* BTB Signals */
logic          btb_hit;
logic [31:0]   btb_pc;

/* RAS Signals */
logic [31:0] ras_pc;
logic ras_popped;
logic ras_full;
logic ras_empty;

/* GSHARE Signals */
//logic [31:0] global_history_register;
//logic [31:0] global_history_register_reg;
logic [1:0] guess_2bsat;

/* Fighting Signals */
logic [31:0] guess_jmp_addr;
logic guess_jmp_entry;

/* Next PC Signals */
logic          br_guess;

/* Metrics */
//integer        branch_hits;
//integer        branch_misses;
//integer        num_wrong_guesses;
//integer        num_wrong_guess_addrs;
//integer        num_flushes;

/* Branch Queue Signals */
branch_queue_t branch_queue_entry;
logic          write_entry;

/* Signal Aliases */
assign stall              = iqueue_full | branch_queue_full | coif_full;
assign instr_ready        = instr_v & imem_resp & ~stall;
//assign branch_queue_entry = '{valid: 1'b1, branch_mask: branch_mask, guess_jmp_pc: pc, guess_jmp_addr: guess_jmp_addr, guess_jmp: guess_jmp_entry, ghr: global_history_register_reg, store_2bsat: guess_2bsat};
assign branch_queue_entry = '{valid: 1'b1, branch_mask: branch_mask, guess_jmp_pc: pc, guess_jmp_addr: guess_jmp_addr, guess_jmp: guess_jmp_entry, store_2bsat: guess_2bsat};
assign write_entry        = is_control_flow & instr_v & imem_resp & ~stall;

always_comb begin
  if (ras_popped) begin
    guess_jmp_entry = 1'b1;
    guess_jmp_addr = ras_pc;
    br_guess = 1'b1;
  end else begin
    guess_jmp_entry = guess_jmp & btb_hit;
    guess_jmp_addr = btb_pc;
  /* Only change the PC to btb address if hit and predictor says yes and it's actually a branch still */
    br_guess = btb_hit & guess_jmp & is_control_flow;
  end
end

always_comb begin
  /* Always ask imem for full word at pc */
  imem_addr = pc_fetch;
  imem_rmask = 4'b1111;
end

always_ff @ (posedge clk) begin
  /* Register instr_v for one cycle for the imem to be able to respond */
  instr_v     <= instr_v_fetch;
  pc          <= pc_fetch;
  /* Register flush for Max */
  flush       <= rst | mispredict;

  /* Branch Resolution Bus */
  brif.broadcast <= backend_jmp;
  brif.clean     <= backend_jmp & ~mispredict;
  brif.kill      <= backend_jmp & mispredict;
  brif.tag       <= br_tag;
end

/* Next PC module */
pc_update_stage fetch_stage0 (
  .clk(clk),
  .rst(rst),
  .stall(stall),
  .imem_resp(imem_resp),
  .br_guess(br_guess),
  .br_guess_addr(guess_jmp_addr),
  .mispredict(mispredict),
  .mispredict_addr(mispredict_addr),
  .pc(pc_fetch),
  .instr_v(instr_v_fetch)
);

/* BTB Cache holding branch addresses */
btb btb0 (
  .clk(clk),
  //.rst(rst),

  .backend_jmp(backend_jmp),
  .backend_jmp_answer(backend_jmp_answer),
  .backend_jmp_pc(head_branch_queue.guess_jmp_pc),
  .backend_jmp_dest(backend_jmp_dest),

  .pc(pc_fetch),
  .btb_hit(btb_hit),
  .btb_pc(btb_pc)
);

/* Assign Instruction Branch Tag */
logic [COB_ADDR_WIDTH-1:0] cob_index;
always_comb begin
  /* Default Conditions */
  coif_allocate = 1'b0;
  coif_mask     = '0;

  /* COB index or Branch Tag */ 
  cob_index = coif_index;
  
  /* Allocate an entry in the COB, which is the Branch Tag */
  if (write_entry) begin
    coif_allocate = 1'b1;
    coif_mask = branch_mask;
  end
end

/* Instruction Branch Tag */
assign branch_tag = cob_index;

/* Assign Instruction Branch Mask */
logic [COB_DEPTH-1:0] global_bmask;
always_ff @(posedge clk) begin
  if (rst) begin
    global_bmask <= '0;
  end else begin
    // BRB Update Logic
    if (brif.broadcast) begin
      if (brif.kill) begin
        global_bmask <= cob_data_wire[brif.tag].branch_mask;
        // Concurrent BRB Update for Global Branch
        if (cob_data_wire[brif.tag].branch_mask[brif.tag]) begin
          global_bmask[brif.tag] <= 1'b0;
        end
      end
      else if (brif.clean) begin
        global_bmask[brif.tag] <= 1'b0;
      end
    end

    // Update Global Branch Mask with valid COB index
    if (write_entry) begin
      global_bmask[cob_index] <= 1'b1;
    end
  end 
end

/* Instruction Branch Mask */
always_comb begin
  branch_mask = global_bmask;

  // BRB Update Logic
  if (brif.broadcast) begin
    if (brif.kill) begin
      branch_mask = '0;
    end
    else if (brif.clean) begin
      branch_mask[brif.tag] = 1'b0;
    end
  end
end

/* Return Address Stack :)))))))))))))))))))))))))) */
ras #(.DEPTH(8)) ras0 (
  .clk(clk),
  .rst(rst),
  .opcode(rv32i_op_t'(imem_rdata[6:0])),
  //.opcode(rv32i_op_t'(7'd0)),
  .rd(imem_rdata[11:7]),
  .rs1(imem_rdata[19:15]),
  .wdata(pc + 3'b100),
  .rdata(ras_pc),
  .ras_popped(ras_popped),
  .full(ras_full),
  .empty(ras_empty),
  .stall(stall),
  .flush(flush)
);

/* FIFO Holding branch information */
branch_file branch_file0 (
  .clk(clk),
  .rst(rst),
  .waddr(cob_index),
  .wen(write_entry),
  .ren(backend_jmp),
  .raddr(br_tag),
  .wdata(branch_queue_entry),
  .rdata(head_branch_queue),
  .full(branch_queue_full),
  .empty(branch_queue_empty),
  .brif(brif_req)
);

/* Predecoder */
predecoder predecoder0 (
  .opcode(rv32i_op_t'(imem_rdata[6:0])),
  .is_control_flow(is_control_flow)
);

/* Always Taken Branch Predictor */
//assign guess_jmp        = 1'b1;
assign wrong_guess_addr = (head_branch_queue.guess_jmp_addr != backend_jmp_dest);
assign wrong_guess      = (head_branch_queue.guess_jmp != backend_jmp_answer);
assign mispredict       = backend_jmp & (wrong_guess | (wrong_guess_addr & backend_jmp_answer) | branch_queue_empty);
assign mispredict_addr  = backend_jmp_answer ? backend_jmp_dest : head_branch_queue.guess_jmp_pc + 3'b100;

/* 2 Bit Saturating Counter Predictor */
simple_predictor #(.SET_IDX(8)) simple_predictor0 (
  .clk(clk),
  .backend_jmp(backend_jmp),
  .backend_jmp_answer(backend_jmp_answer),
  .backend_pc(head_branch_queue.guess_jmp_pc),

  .pc(pc_fetch),
  //.ghr(global_history_register),
  //.backend_ghr(head_branch_queue.ghr),
  .guess_jmp(guess_jmp),

  .backend_2bsat(head_branch_queue.store_2bsat),
  .guess_2bsat(guess_2bsat)

  //.guess_jmp()
);

//ghr ghr0 (
//  .clk(clk),
//  .rst(rst),
//  //.shift_en(is_control_flow & ~stall),
//  .shift_en(write_entry),
//  /* For now, we ignore the btb for the ghr. */
//  //.shift_data(guess_jmp | ras_popped),
//  .shift_data(br_guess),
//  .wen(mispredict),
//  .wdata({head_branch_queue.ghr[30:0], backend_jmp_answer}),
//  .rdata(global_history_register),
//  .rdata_reg(global_history_register_reg)
//);

/* Metrics */
//always_ff @ (posedge clk) begin
//  if (rst) begin
//    branch_hits   <= 0;
//    branch_misses <= 0;
//    num_wrong_guesses <= 0;
//    num_wrong_guess_addrs <= 0;
//    num_flushes <= 0;
//  end
//  else if (mispredict) begin
//    branch_misses <= branch_misses + 1;
//  end
//  else if (backend_jmp) begin
//    branch_hits <= branch_hits + 1;
//  end
//
//  if (backend_jmp) begin
//    if (wrong_guess) begin
//      num_wrong_guesses <= num_wrong_guesses + 1;
//    end
//    else if (wrong_guess_addr) begin
//      num_wrong_guess_addrs <= num_wrong_guess_addrs + 1;
//    end
//  end
//
//  if (flush) begin
//    num_flushes <= num_flushes + 1;
//  end
//end

endmodule
