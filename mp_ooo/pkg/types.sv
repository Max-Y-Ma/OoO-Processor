package cache_types;
  typedef enum logic [2:0] {
    IDLE,
    CHECK,
    WRITEBACK,
    FETCH,
    FETCH_WAIT
  } controller_state_t;

  typedef enum logic [2:0] {
      LINE_IDLE,
      WAIT,
      SERIALIZE,
      DESERIALIZE,
      DESERIALIZE_DONE
  } cacheline_state_t;
endpackage;

package rv32i_types;
  typedef enum logic [6:0] {
    op_lui   = 7'b0110111, // U load upper immediate 
    op_auipc = 7'b0010111, // U add upper immediate PC 
    op_jal   = 7'b1101111, // J jump and link 
    op_jalr  = 7'b1100111, // I jump and link register 
    op_br    = 7'b1100011, // B branch 
    op_load  = 7'b0000011, // I load 
    op_store = 7'b0100011, // S store 
    op_imm   = 7'b0010011, // I arith ops with register/immediate operands 
    op_reg   = 7'b0110011, // R arith ops with register operands 
    op_csr   = 7'b1110011  // I control and status register
  } rv32i_op_t;

  typedef enum bit [2:0] {
    beq  = 3'b000,
    bne  = 3'b001,
    blt  = 3'b100,
    bge  = 3'b101,
    bltu = 3'b110,
    bgeu = 3'b111
  } branch_funct3_t;
 
  typedef struct packed {
    logic valid;
    logic [63:0] order;
    logic [31:0] inst;
    logic [4:0]  rs1_addr;
    logic [4:0]  rs2_addr;
    logic [31:0] rs1_rdata;
    logic [31:0] rs2_rdata;
    logic [4:0]  rd_addr;
    logic [31:0] pc_rdata;
    logic [31:0] pc_wdata;
    logic [31:0] mem_addr;
    logic [3:0]  mem_rmask;
    logic [3:0]  mem_wmask;
    logic [31:0] mem_wdata;
  } rvfi_signals_t;

  typedef enum bit [2:0] {
    lb  = 3'b000,
    lh  = 3'b001,
    lw  = 3'b010,
    lbu = 3'b100,
    lhu = 3'b101
  } load_funct3_t;

  typedef enum bit [2:0] {
    sb = 3'b000,
    sh = 3'b001,
    sw = 3'b010
  } store_funct3_t;

  typedef enum bit [2:0] {
    addi  = 3'b000,
    slli  = 3'b001,
    slti  = 3'b010,
    sltiu = 3'b011,
    xori  = 3'b100,
    sri   = 3'b101, // Check bit 30 for logical/arithmetic
    ori   = 3'b110,
    andi  = 3'b111
  } arith_funct3_t;

  typedef enum bit [2:0] {
    addr   = 3'b000, // Check bit 30 and 25 for add, subtract, or multiply
    sllr   = 3'b001, // Check bit 25 for multiply
    sltr   = 3'b010, // Check bit 25 for multiply
    sltru  = 3'b011, // Check bit 25 for multiply
    xorr   = 3'b100, // Check bit 25 for divide
    srr    = 3'b101, // Check bit 30 for logical/arithmetic or Check bit 25 for divide
    orr    = 3'b110, // Check bit 25 for divide
    andr   = 3'b111  // Check bit 25 for divide
  } arith_reg_funct3_t;

  typedef enum bit [2:0] { 
    mulr    = 3'b000,
    mulhr   = 3'b001,
    mulhsur = 3'b010,
    mulhur  = 3'b011
  } arith_mul_funct3_t;

  typedef enum bit [1:0] { 
    uu_mul = 2'b00,
    ss_mul = 2'b01,
    su_mul = 2'b10
  } mul_type_t;

  typedef enum bit [1:0] {
    ss_div = 2'b00,
    uu_div = 2'b01,
    ss_rem = 2'b10,
    uu_rem = 2'b11
  } div_type_t;

  typedef enum bit [2:0] {
    alu_add = 3'b000, // Check bit 30 for add/sub
    alu_sll = 3'b001,
    alu_sra = 3'b010,
    alu_sub = 3'b011,
    alu_xor = 3'b100,
    alu_srl = 3'b101, // Check bit 30 for logical/arithmetic
    alu_or  = 3'b110,
    alu_and = 3'b111
  } rv32i_alu_opcode_t;
 
  // Typedefs for RVFI Monitor Signals
  typedef struct packed {
    // Required Signals
    logic        valid;
    logic [63:0] order;
    logic [31:0] inst;
    logic [4:0]  rs1_addr;
    logic [4:0]  rs2_addr;
    logic [31:0] rs1_rdata;
    logic [31:0] rs2_rdata;
    logic [4:0]  rd_addr;
    logic [31:0] rd_wdata;
    logic [31:0] pc_rdata;
    logic [31:0] pc_wdata;
    logic [31:0] mem_addr;
    logic [3:0]  mem_rmask;
    logic [3:0]  mem_wmask;
    logic [31:0] mem_rdata;
    logic [31:0] mem_wdata;
  } rvfi_signal_t;

  // Control Operands
  typedef enum bit {
    rs1_out_t = 1'b0,
    pc_out_t = 1'b1
  } op1_mux_t;

  typedef enum bit {
    rs2_out_t = 1'b0,
    imm_out_t = 1'b1
  } op2_mux_t;

  typedef enum bit {
    pc_target  = 1'b0,
    rs1_target = 1'b1
  } target_mux_t;
endpackage

package backend_types;
  // Package Parameters
  localparam NOP_BUBBLE = 'h13;
  
  /* CPU Config */
  localparam NUM_EU = 6;
  localparam EU_WIDTH = $clog2(NUM_EU);
  localparam NUM_ARCH_REGISTERS = 32;
  localparam ARCH_REG_WIDTH = $clog2(NUM_ARCH_REGISTERS);
  localparam NUM_PHYS_REGISTERS = 64;
  localparam PHYS_REG_WIDTH = $clog2(NUM_PHYS_REGISTERS);

  localparam ROB_DEPTH = 32;
  localparam ROB_ADDR_WIDTH = $clog2(ROB_DEPTH);
  localparam FREE_LIST_DEPTH = NUM_PHYS_REGISTERS - NUM_ARCH_REGISTERS;
  localparam FREE_LIST_ADDR_WIDTH = $clog2(FREE_LIST_DEPTH);

  /* EBR Config */
  localparam COB_DEPTH = 4;
  localparam COB_ADDR_WIDTH = $clog2(COB_DEPTH);

  /* Reservation Config */
  localparam INT_ISSUE_DEPTH = 8;
  localparam MUD_ISSUE_DEPTH = 8;
  localparam BR_ISSUE_DEPTH  = COB_DEPTH;
  localparam MEM_ISSUE_DEPTH = 8;

  /* LSU Config */
  localparam LOAD_DEPTH  = 4;
  localparam STORE_DEPTH = 4;
  localparam LOAD_ADDR_WIDTH  = $clog2(LOAD_DEPTH);
  localparam STORE_ADDR_WIDTH = $clog2(STORE_DEPTH);

  /* Cache Config */
  localparam ICACHE_WAYS = 2;
  localparam ICACHE_SETS = 16;
  localparam DCACHE_WAYS = 2;
  localparam DCACHE_SETS = 16;

  import rv32i_types::*;

  typedef struct packed {
    logic [31:0] target_addr;
    logic [31:0] return_addr;
    logic        br_en;
  } bru_result_t;

  typedef struct packed {
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_mask;
  } agu_result_t;

  typedef enum bit [EU_WIDTH-1:0] {
    alu  = 'h0,
    cmp  = 'h1,
    mul  = 'h2,
    div  = 'h3,
    agu  = 'h4,
    bru  = 'h5
  } euid_t;

  typedef struct packed {
    euid_t                     euid;
    logic [ARCH_REG_WIDTH-1:0] ard_addr;
    logic [ARCH_REG_WIDTH-1:0] ars1_addr;
    logic [ARCH_REG_WIDTH-1:0] ars2_addr;
    logic [PHYS_REG_WIDTH-1:0] prd_addr;
    logic [PHYS_REG_WIDTH-1:0] prs1_addr;
    logic                      prs1_ready;
    logic [PHYS_REG_WIDTH-1:0] prs2_addr;
    logic                      prs2_ready;
    logic [ROB_ADDR_WIDTH-1:0] rob_index;
    logic [COB_ADDR_WIDTH-1:0] cob_index;
    logic [COB_DEPTH-1:0]      branch_mask;
  } metadata_t;
   
  typedef struct packed {
    logic [31:0] pc;
    logic [31:0] imm;
    logic [2:0]  op;
    logic [2:0]  funct3;
    logic        regf_we;
    logic        branch;
    logic        mem_write;
    logic        mem_read;
    op1_mux_t    op1_mux;
    op2_mux_t    op2_mux;
    target_mux_t target_mux;
  } ctrl_sig_t;

  // Structural Types
  typedef struct packed {
    logic [31:0] pc;
    logic [31:0] inst;
    logic [COB_ADDR_WIDTH-1:0] branch_tag;
    logic [COB_DEPTH-1:0]      branch_mask;
  } iqueue_t;

  typedef struct packed {
    logic                      valid;
    logic [PHYS_REG_WIDTH-1:0] data;
  } rat_entry_t;

  typedef struct packed {
    logic         valid;
    ctrl_sig_t    ctrl;
    metadata_t    meta;
    rvfi_signal_t rvfi;
  } res_entry_t;

  typedef struct packed {
    logic                      ready;
    logic [ARCH_REG_WIDTH-1:0] ard;
    logic [PHYS_REG_WIDTH-1:0] prd;
    logic                      store;
    logic                      load;
    logic                      branch;
    logic [COB_ADDR_WIDTH-1:0] cob_index;
    logic [COB_DEPTH-1:0]      branch_mask;
    rvfi_signal_t              rvfi;
  } rob_entry_t;

  typedef struct packed {
    logic                                 valid;
    logic [ROB_ADDR_WIDTH:0]              rob_wptr;
    logic [STORE_ADDR_WIDTH:0]            store_wptr;
    logic [FREE_LIST_ADDR_WIDTH:0]        free_rptr;
    rat_entry_t [NUM_ARCH_REGISTERS-1:0]  rat_data;  
    logic [COB_DEPTH-1:0]                 branch_mask;
  } cob_entry_t;

  // Pipeline Stage Types
  typedef struct packed {
    logic         valid;
    ctrl_sig_t    ctrl;
    metadata_t    meta;
    rvfi_signal_t rvfi;
  } rename_stage_t;

  typedef struct packed {
    logic         valid;
    ctrl_sig_t    ctrl;
    metadata_t    meta;
    logic [31:0]  psr1_data;
    logic [31:0]  psr2_data;
    rvfi_signal_t rvfi;
  } issue_stage_t;

  typedef struct packed {
    logic [ROB_ADDR_WIDTH-1:0] id;
    logic [31:0]               addr;
    logic [31:0]               wdata;
    logic [3:0]                wmask;
    logic [2:0]                op;
    logic                      allocated;
    logic                      resolved;
    logic                      committed;
    logic [COB_DEPTH-1:0]      branch_mask;
  } store_queue_entry_t;

  typedef struct packed {
    issue_stage_t              stage;
    logic [ROB_ADDR_WIDTH-1:0] id;
    logic [31:0]               addr;
    logic [31:0]               rdata;
    logic [2:0]                op;
    logic [3:0]                req_mask;
    logic                      allocated;
    logic                      fire_ready;
    logic                      fired;
    logic                      addr_resolved;
    logic                      data_resolved;
    logic [COB_DEPTH-1:0]      branch_mask;
  } load_queue_entry_t;
endpackage

package magic_backend_types;
  import backend_types::*;

  typedef struct packed {
    logic [31:0] pc;
    logic [31:0] instr;
    logic [COB_ADDR_WIDTH-1:0] branch_tag;
    logic [COB_DEPTH-1:0]      branch_mask;
  } instr_queue_t;

  typedef enum logic [6:0] {
    op_lui   = 7'b0110111, // U load upper immediate
    op_auipc = 7'b0010111, // U add upper immediate PC
    op_jal   = 7'b1101111, // J jump and link
    op_jalr  = 7'b1100111, // I jump and link register
    op_br    = 7'b1100011, // B branch
    op_load  = 7'b0000011, // I load
    op_store = 7'b0100011, // S store
    op_imm   = 7'b0010011, // I arith ops with register/immediate operands
    op_reg   = 7'b0110011, // R arith ops with register operands
    op_csr   = 7'b1110011  // I control and status register
  } rv32i_op_t;

  typedef enum bit [2:0] {
    beq  = 3'b000,
    bne  = 3'b001,
    blt  = 3'b100,
    bge  = 3'b101,
    bltu = 3'b110,
    bgeu = 3'b111
  } br_ops;

  typedef enum logic[2:0] {
    i = 3'b000,
    s = 3'b001,
    b = 3'b011,
    u = 3'b010,
    j = 3'b110,
    r = 3'b100
  } instr_type_t;

  typedef enum logic [3:0] {
      lb   = 4'b0000,
      lh   = 4'b0001,
      lw   = 4'b0010,
      lbu  = 4'b0100,
      lhu  = 4'b0101,
      sb   = 4'b1000,
      sh   = 4'b1001,
      sw   = 4'b1010,
      none = 4'b0111
  } mem_ops;

  typedef enum logic [2:0] {
      wb_lb   = 3'b000,
      wb_lh   = 3'b001,
      wb_lw   = 3'b010,
      wb_lbu  = 3'b100,
      wb_lhu  = 3'b101,
      wb_none = 3'b111
  } load_ops;

  typedef enum logic [3:0] {
      alu_add  = 4'b0000,
      alu_sub  = 4'b1000,
      alu_sll  = 4'b0001,
      alu_slt  = 4'b0010,
      alu_sltu = 4'b0011,
      alu_xor  = 4'b0100,
      alu_srl  = 4'b0101,
      alu_sra  = 4'b1101,
      alu_or   = 4'b0110,
      alu_and  = 4'b0111
  } alu_ops;

  typedef enum logic {
      rs1_out = 1'b0,
      pc_out = 1'b1
  } alu_m1_sel_t;

  typedef enum logic {
      rs2_out = 1'b0,
      imm_out = 1'b1
  } alu_m2_sel_t;

  typedef enum logic {
        pc_rs1 = 1'b0,
        pc_prev = 1'b1
  } ex_pc_sel_t;

 typedef struct packed {
    // Decode Controls
    instr_type_t instr_type;

    // Execute Controls
    alu_ops      alu_op;
    logic        alu_bypass;
    alu_m1_sel_t alu_m1_sel;
    alu_m2_sel_t alu_m2_sel;
    logic        br, jmp;
    br_ops       br_op;
    ex_pc_sel_t  ex_pc_sel;

    // Memory Operation
    mem_ops mem_op;

    // Writeback Controls
    logic wb_mem, wb_pc;
    logic rd_we;
  } control_word_t;

  typedef struct packed {
    logic valid;
    logic [63:0] order;
    logic [31:0] inst;
    logic [4:0]  rs1_addr;
    logic [4:0]  rs2_addr;
    logic [31:0] rs1_rdata;
    logic [31:0] rs2_rdata;
    logic [4:0]  rd_addr;
    logic [31:0] pc_rdata;
    logic [31:0] pc_wdata;
    logic [31:0] mem_addr;
    logic [3:0]  mem_rmask;
    logic [3:0]  mem_wmask;
    logic [31:0] mem_wdata;
  } rvfi_signals_t;

endpackage;

package frontend_types;
  import backend_types::*;

  typedef struct packed {
    logic valid;
    logic [COB_DEPTH-1:0] branch_mask;
    logic [31:0] guess_jmp_pc;
    logic [31:0] guess_jmp_addr;
    logic        guess_jmp;
    //logic [31:0] ghr;
    logic [1:0] store_2bsat;
  } branch_queue_t;
endpackage;

// Backend Interfaces
interface rat_i;
  import backend_types::*;

  logic                      wen;
  rat_entry_t                prd_wdata;
  logic [ARCH_REG_WIDTH-1:0] ars1_addr, ars2_addr, ard_addr;
  rat_entry_t                prs1_rdata, prs2_rdata;

  // Device port that listens for reqs
  modport rename (
    output ars1_addr, ars2_addr
  );

  modport d (
    input prs1_rdata, prs2_rdata,
    output wen, prd_wdata, ard_addr
  );

  modport r (
    input wen, prd_wdata, ars1_addr, ars2_addr, ard_addr,
    output prs1_rdata, prs2_rdata
  );

endinterface : rat_i

interface free_list_i;
  import backend_types::*;

  logic                      wen, ren;
  logic                      full, empty;
  logic [PHYS_REG_WIDTH-1:0] wdata, rdata;

  modport rename (
    input empty,
    output ren
  );

  modport d (
    input rdata
  );

  modport commit (
    input full,
    output wen, wdata
  );

  modport r (
    input wen, wdata, ren,
    output rdata, full, empty
  );

endinterface : free_list_i

interface rob_i;
  import backend_types::*;

  // Queue Port
  logic                    wen, ren;
  rob_entry_t              wdata, rdata;
  logic                    full, empty;
  logic [ROB_ADDR_WIDTH:0] index;

  modport d (
    input full, index,
    output wen, wdata
  );

  modport commit (
    input rdata, empty,
    output ren
  );

  modport lsu (
    input rdata, ren
  );

  modport r (
    input wen, ren, wdata,
    output rdata, full, empty, index
  );

endinterface : rob_i

interface cob_itf;
  import backend_types::*;

  // Queue Port
  logic                      wen, ren, allocate;
  cob_entry_t                wdata;
  logic                      full, empty;
  logic [COB_ADDR_WIDTH-1:0] raddr, waddr;
  logic [COB_DEPTH-1:0]      mask;
  logic [COB_ADDR_WIDTH-1:0] index;

  modport frontend (
    input full, index,
    output allocate, mask
  );

  modport d (
    output wen, wdata, waddr
  );

  modport execute (
    output ren, raddr
  );

  modport r (
    input wen, ren, waddr, wdata, raddr, allocate, mask,
    output full, empty, index
  );

endinterface : cob_itf

interface rrf_i;
  import backend_types::*;

  logic                      wen;
  logic [ARCH_REG_WIDTH-1:0] ard_addr;
  logic [PHYS_REG_WIDTH-1:0] prd_wdata, free_prd;
  logic                      valid;

  modport commit (
    output wen, ard_addr, prd_wdata,
    input free_prd, valid
  );

  modport r (
    input wen, ard_addr, prd_wdata,
    output free_prd, valid
  );

endinterface : rrf_i

interface prf_i;
  import backend_types::*;

  logic [PHYS_REG_WIDTH-1:0] prs1_addr, prs2_addr;
  logic [31:0]               rs1_rdata, rs2_rdata;

  modport issue (
    input rs1_rdata, rs2_rdata,
    output prs1_addr, prs2_addr
  );

  modport r (
    input prs1_addr, prs2_addr,
    output rs1_rdata, rs2_rdata
  );

endinterface : prf_i

interface res_i 
import backend_types::*;
#(
  parameter DEPTH = INT_ISSUE_DEPTH,
  parameter ADDR_WIDTH = $clog2(DEPTH)
);

  logic                  wen, ren;
  logic                  full, empty;
  res_entry_t            wdata, rdata;
  logic [ADDR_WIDTH-1:0] raddr;
  logic [DEPTH-1:0]      req;
  logic [EU_WIDTH-1:0]   euid [DEPTH];

  modport d (
    input full, empty,
    output wen, wdata
  );

  modport issue (
    input req, euid, empty, rdata,
    output ren, raddr
  );

  modport r (
    input wen, ren, wdata, raddr, 
    output full, empty, rdata, req, euid
  );

endinterface : res_i

interface lsu_itf;
  import backend_types::*;

  /* Load Interface */
  logic                      ld_valid, ld_ready;
  logic [ROB_ADDR_WIDTH-1:0] ld_id;
  logic [2:0]                ld_op;
  logic [COB_DEPTH-1:0]      ld_branch_mask;

  /* Store Interface */
  logic                      st_valid, st_ready;
  logic [ROB_ADDR_WIDTH-1:0] st_id;
  logic [2:0]                st_op;
  logic [COB_DEPTH-1:0]      st_branch_mask;

  modport lsu (
    input  ld_valid,
    input  ld_id,
    input  ld_op,
    input  ld_branch_mask,
    output ld_ready,
    input  st_valid,
    input  st_id,
    input  st_op,
    input  st_branch_mask,
    output st_ready
  );

  modport d (
    output ld_valid,
    output ld_id,
    output ld_op,
    output ld_branch_mask,
    input  ld_ready,
    output st_valid,
    output st_id,
    output st_op,
    output st_branch_mask,
    input  st_ready
  );

endinterface : lsu_itf

interface cdb_i;
  import backend_types::*;
  import rv32i_types::*;

  logic                      valid;
  logic [ARCH_REG_WIDTH-1:0] ard;
  logic [PHYS_REG_WIDTH-1:0] prd;
  logic [ROB_ADDR_WIDTH-1:0] rob_index;
  logic [COB_ADDR_WIDTH-1:0] cob_index;
  logic [31:0]               result;
  rvfi_signal_t              rvfi;

  modport r (
    output valid, rob_index, cob_index, result, ard, prd, rvfi
  );

  modport req (
    input valid, rob_index, cob_index, result, ard, prd, rvfi
  );
endinterface : cdb_i

interface brb_itf;
  import backend_types::*;

  logic                      broadcast;
  logic                      clean;
  logic                      kill;
  logic [COB_ADDR_WIDTH-1:0] tag;

  modport response (
    output broadcast, clean, kill, tag
  );

  modport req (
    input broadcast, clean, kill, tag
  );
endinterface : brb_itf

