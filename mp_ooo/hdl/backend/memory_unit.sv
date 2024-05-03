/**
 * Module: memory_unit
 * File  : memory_unit.sv
 * Author: Max Ma
 * Date  : April 6, 2024
 *
 * Description:
 * ------------
 * The memory_unit is responsible for executing loads and stores correctly. In this simple memory unit,
 * we execute load and store instructions completely in order to avoid address and age dependecencies.
 *
 * Critical Path Analysis:
 * ------------
*/
module memory_unit 
import rv32i_types::*;
import backend_types::*;
(
  input  logic clk, rst,

  input  logic        issue_store,
  input  logic [2:0]  mem_funct3,

  // Branch Signals
  input  logic        flush,

  // Memory Data Signals
  input  logic        ivalid,
  input  logic        mem_write,
  input  logic        mem_read,
  input  logic [31:0] mem_addr,
  input  logic [31:0] mem_wdata,
  output logic [31:0] mem_rdata,
  output logic        ovalid,

  // Data Memory Port
  output logic [31:0] dmem_addr,
  output logic [3:0]  dmem_rmask,
  output logic [3:0]  dmem_wmask,
  input  logic [31:0] dmem_rdata,
  output logic [31:0] dmem_wdata,
  input  logic        dmem_resp,

  output logic [31:0] rvfi_dmem_addr,
  output logic [3:0]  rvfi_dmem_rmask
);

  // Store Queue / Register
  logic [31:0] st_addr, st_wdata; 
  always_ff @(posedge clk) begin
    if (rst || flush) begin
      st_addr   <= '0;
      st_wdata  <= '0;
    end 
    else if (ivalid && mem_write) begin
      st_addr   <= mem_addr;
      st_wdata  <= mem_wdata;
    end
  end

  // Load Queue / Register
  logic        load;
  logic [31:0] ld_addr;
  always_ff @(posedge clk) begin
    if (rst || ovalid || flush) begin
      ld_addr   <= '0;
      load      <= '0;
    end 
    else if (ivalid && mem_read) begin
      ld_addr   <= mem_addr;
      load      <= 1'b1;
    end
  end

  // Bus Assertion Logic
  always_comb begin
    dmem_addr = '0;
    dmem_rmask = '0;
    dmem_wmask = '0;
    dmem_wdata = '0;

    // Execute Store Instruction
    if (issue_store && ~flush) begin
      dmem_addr = {st_addr[31:2], 2'b00};
      unique case (mem_funct3)
        sb : dmem_wmask = (4'h1 << st_addr[1:0]);
        sh : dmem_wmask = (4'h3 << st_addr[1:0]);
        sw : dmem_wmask = (4'hF);
        default: dmem_wmask = 'x;
      endcase
      unique case (mem_funct3)
        sb : dmem_wdata[8 *st_addr[1:0] +: 8 ] = st_wdata[7:0];
        sh : dmem_wdata[16*st_addr[1]   +: 16] = st_wdata[15:0];
        sw : dmem_wdata                        = st_wdata;
        default: dmem_wdata = 'x;
      endcase
    end

    // Execute Load Instruction
    else if (mem_read && ~flush) begin
      dmem_addr = {mem_addr[31:2], 2'b00};
      unique case(mem_funct3)
        lb  : dmem_rmask = (4'h1 << mem_addr[1:0]);
        lbu : dmem_rmask = (4'h1 << mem_addr[1:0]);
        lh  : dmem_rmask = (4'h3 << mem_addr[1:0]);
        lhu : dmem_rmask = (4'h3 << mem_addr[1:0]);
        lw  : dmem_rmask = (4'hF);
        default: dmem_rmask = 'x;
      endcase
    end
  end

  // Output Logic: Magic Memory
  assign ovalid = ~flush & ((load & dmem_resp) | (mem_write & ivalid));
  always_comb begin
    unique case (mem_funct3)
      lb : mem_rdata = {{24{dmem_rdata[7 +8 *ld_addr[1:0]]}}, dmem_rdata[8 *ld_addr[1:0] +: 8 ]};
      lbu: mem_rdata = {{24{1'b0}}                          , dmem_rdata[8 *ld_addr[1:0] +: 8 ]};
      lh : mem_rdata = {{16{dmem_rdata[15+16*ld_addr[1]  ]}}, dmem_rdata[16*ld_addr[1]   +: 16]};
      lhu: mem_rdata = {{16{1'b0}}                          , dmem_rdata[16*ld_addr[1]   +: 16]};
      lw : mem_rdata = dmem_rdata;
      default: mem_rdata = 'x;
    endcase
  end

  always @(posedge clk) begin
    if (rst) begin
      rvfi_dmem_addr  <= '0;
      rvfi_dmem_rmask <= '0;
    end else begin
      rvfi_dmem_addr  <= dmem_addr;
      rvfi_dmem_rmask <= dmem_rmask;
    end
  end

endmodule : memory_unit
