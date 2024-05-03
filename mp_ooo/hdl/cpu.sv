module cpu
import frontend_types::*;
import rv32i_types::*;
import backend_types::*;
(
  // Explicit dual port connections when caches are not integrated into design yet (Before CP3)
    input   logic           clk,
    input   logic           rst,

    // output  logic   [31:0]  imem_addr,
    // output  logic   [3:0]   imem_rmask,
    // input   logic   [31:0]  imem_rdata,
    // input   logic           imem_resp,

    // output  logic   [31:0]  dmem_addr,
    // output  logic   [3:0]   dmem_rmask,
    // output  logic   [3:0]   dmem_wmask,
    // input   logic   [31:0]  dmem_rdata,
    // output  logic   [31:0]  dmem_wdata,
    // input   logic           dmem_resp

    // Single memory port connection when caches are integrated into design (CP3 and after)
    output logic   [31:0]      bmem_addr,
    output logic               bmem_read,
    output logic               bmem_write,
    output logic   [63:0]      bmem_wdata,
    input logic                bmem_ready,

    input logic   [31:0]      bmem_raddr,
    input logic   [63:0]      bmem_rdata,
    input logic               bmem_rvalid
);

// Magic Frontend and Backend DUT
logic [31:0]               pc;
iqueue_t                   iqueue_rdata;
logic                      instr_valid;
logic                      iqueue_ren;
logic                      iqueue_full;
logic                      iqueue_empty;
logic                      branch;
logic                      br_en;
logic [31:0]               target_addr;
logic [31:0]               pc_out;
logic [COB_ADDR_WIDTH-1:0] br_tag;
logic [COB_ADDR_WIDTH-1:0] branch_tag;
logic [COB_DEPTH-1:0]      branch_mask;
cob_entry_t cob_data_wire [COB_DEPTH];

// Frontend COB Interface Ports
logic                      coif_full;
logic [COB_ADDR_WIDTH-1:0] coif_index;
logic                      coif_allocate;
logic [COB_DEPTH-1:0]      coif_mask;

brb_itf brif();   // Branch Resolution Bus Interface

/* Cache Signals */

logic   [31:0]  icache_addr;
logic           icache_read;
logic           icache_write;
logic  [255:0]  icache_rdata;
logic  [255:0]  icache_wdata;
logic           icache_resp;

logic   [31:0]  dcache_addr;
logic           dcache_read;
logic           dcache_write;
logic  [255:0]  dcache_rdata;
logic  [255:0]  dcache_wdata;
logic           dcache_resp;

logic   [31:0]  imem_addr;
logic   [3:0]   imem_rmask;
logic   [31:0]  imem_rdata;
logic           imem_resp;

logic   [31:0]  dmem_addr;
logic   [3:0]   dmem_rmask;
logic   [3:0]   dmem_wmask;
logic   [31:0]  dmem_rdata;
logic   [31:0]  dmem_wdata;
logic           dmem_resp;

logic           instr_ready;

logic           flush;

cache_line cache_line0(
  .clk(clk),
  .rst(rst),

  .bmem_addr(bmem_addr),
  .bmem_read(bmem_read),
  .bmem_write(bmem_write),
  .bmem_wdata(bmem_wdata),
  .bmem_ready(bmem_ready),
  .bmem_raddr(bmem_raddr),
  .bmem_rdata(bmem_rdata),
  .bmem_rvalid(bmem_rvalid),

  .icache_addr(icache_addr),
  .icache_read(icache_read),
  .icache_write(icache_write),
  .icache_rdata(icache_rdata),
  .icache_wdata(icache_wdata),
  .icache_resp(icache_resp),

  .dcache_addr(dcache_addr),
  .dcache_read(dcache_read),
  .dcache_write(dcache_write),
  .dcache_rdata(dcache_rdata),
  .dcache_wdata(dcache_wdata),
  .dcache_resp(dcache_resp)
);

icache #(
  .WAYS(ICACHE_WAYS),
  .SETS(ICACHE_SETS)
) icache0 (
  .clk(clk),
  .rst(rst),

  .ufp_addr(imem_addr),
  .ufp_rmask(imem_rmask),
  .ufp_rdata(imem_rdata),
  .ufp_resp(imem_resp),

  .dfp_addr(icache_addr),
  .dfp_read(icache_read),
  .dfp_write(icache_write),
  .dfp_rdata(icache_rdata),
  .dfp_wdata(icache_wdata),
  .dfp_resp(icache_resp)
);

dcache #(
  .WAYS(DCACHE_WAYS),
  .SETS(DCACHE_SETS)
) dcache0 (
  .clk(clk),
  .rst(rst),

  .ufp_addr(dmem_addr),
  .ufp_rmask(dmem_rmask),
  .ufp_wmask(dmem_wmask),
  .ufp_rdata(dmem_rdata),
  .ufp_wdata(dmem_wdata),
  .ufp_resp(dmem_resp),

  .dfp_addr(dcache_addr),
  .dfp_read(dcache_read),
  .dfp_write(dcache_write),
  .dfp_rdata(dcache_rdata),
  .dfp_wdata(dcache_wdata),
  .dfp_resp(dcache_resp)
);

frontend frontend0 (
  .clk(clk),
  .rst(rst),

  .iqueue_full(iqueue_full),

  .imem_addr(imem_addr),
  .imem_rmask(imem_rmask),
  .imem_rdata(imem_rdata),
  .imem_resp(imem_resp),

  .backend_jmp(branch),
  .backend_jmp_answer(br_en),
  .backend_jmp_dest(target_addr),

  .instr_ready(instr_ready),
  .pc(pc),
  .coif_full(coif_full),
  .coif_index(coif_index),
  .coif_allocate(coif_allocate),
  .coif_mask(coif_mask),
  .cob_data_wire(cob_data_wire),
  .br_tag(br_tag),
  .brif_req(brif.req),
  .brif(brif.response),
  .branch_tag(branch_tag),
  .branch_mask(branch_mask),
  .flush(flush)
);

backend backend0 (
  .clk(clk),
  .rst(rst),
  .branch(branch),
  .br_en(br_en),
  .target_addr(target_addr),
  .pc_out(pc_out),
  .coif_full(coif_full),
  .coif_index(coif_index),
  .coif_allocate(coif_allocate),
  .coif_mask(coif_mask),
  .cob_data_wire(cob_data_wire),
  .br_tag(br_tag),
  .brif(brif.req),
  .iqueue_ren(iqueue_ren),
  .iqueue_rdata(iqueue_rdata),
  .iqueue_empty(iqueue_empty),
  .dmem_addr(dmem_addr),
  .dmem_rmask(dmem_rmask),
  .dmem_wmask(dmem_wmask),
  .dmem_rdata(dmem_rdata),
  .dmem_wdata(dmem_wdata),
  .dmem_resp(dmem_resp)
);

branch_fifo #(.WIDTH(64 + COB_ADDR_WIDTH + COB_DEPTH), .DEPTH(32)) branch_instr_queue (
  .clk(clk),
  .rst(rst | flush),
  .wen(instr_ready),
  .wdata({pc, imem_rdata, branch_tag, branch_mask}),
  .ren(iqueue_ren),
  .rdata(iqueue_rdata),
  .full(iqueue_full),
  .empty(iqueue_empty),
  .brif(brif.req)
);

endmodule : cpu
