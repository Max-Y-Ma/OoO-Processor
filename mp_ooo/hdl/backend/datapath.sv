/**
 * Module: datapath
 * File  : datapath.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * Contains All modules surrounding and connecting the common data bus
*/
module datapath
import backend_types::*;
(
  input logic clk, rst,

  output logic store,
  output logic load,

  // COB Port
  output cob_entry_t cob_data_wire [COB_DEPTH],

  // Interface Ports
  rat_i.r            rtif,
  rrf_i.r            rrif,
  free_list_i.r      flif,
  rob_i.r            rbif,
  res_i.r            int_rsif,  
  res_i.r            mud_rsif,  
  res_i.r            bra_rsif,
  res_i.r            mem_rsif,
  prf_i.r            pfif,
  cob_itf.r          coif,
  brb_itf.req        brif,
  cdb_i.req          cbif
);

  // Data Wires
  logic [FREE_LIST_ADDR_WIDTH:0] free_rptr;
  rat_entry_t [NUM_ARCH_REGISTERS-1:0] rat_data;
  cob_entry_t cob_data [COB_DEPTH];
  assign cob_data_wire = cob_data;

  // RAT Interface
  logic                      rtif_wen;
  logic [ARCH_REG_WIDTH-1:0] rtif_ard_addr;
  rat_entry_t                rtif_prd_wdata;

  assign rtif_wen = rtif.wen;
  assign rtif_ard_addr = rtif.ard_addr;
  assign rtif_prd_wdata = rtif.prd_wdata;

  // RAT
  rat rat0 (
    .clk(clk),
    .rst(rst),
    .cob_data(cob_data),
    .rat_data(rat_data),
    .brif(brif),
    .rtif(rtif),
    .cbif(cbif)
  );

  // RRF
  rrf rrf0 (
    .clk(clk),
    .rst(rst),
    .rrif(rrif)
  );

  // Free List
  free_list free_list0 (
    .clk(clk),
    .rst(rst),
    .cob_data(cob_data),
    .free_rptr(free_rptr),
    .brif(brif),
    .flif(flif)
  );

  // ROB
  rob rob0 (
    .clk(clk),
    .rst(rst),
    .store(store),
    .load(load),
    .rbif(rbif),
    .cob_data(cob_data),
    .brif(brif),
    .cbif(cbif)
  );

  // COB
  cob cob0 (
    .clk(clk),
    .rst(rst),
    .free_rptr(free_rptr),
    .rat_data(rat_data),
    .cob_data(cob_data),
    .rtif_wen(rtif_wen),
    .rtif_ard_addr(rtif_ard_addr),
    .rtif_prd_wdata(rtif_prd_wdata),
    .coif(coif),
    .brif(brif),
    .cbif(cbif)
  );

  // Reservation Stations
  reservation #(
    .DEPTH(INT_ISSUE_DEPTH)
  ) int_reservation0 (
    .clk(clk),
    .rst(rst),
    .rsif(int_rsif),
    .brif(brif),
    .cbif(cbif)
  );

  reservation #(
    .DEPTH(MUD_ISSUE_DEPTH)
  ) mud_reservation0 (
    .clk(clk),
    .rst(rst),
    .rsif(mud_rsif),
    .brif(brif),
    .cbif(cbif)
  );

  reservation #(
    .DEPTH(BR_ISSUE_DEPTH)
  ) branch_reservation0 (
    .clk(clk),
    .rst(rst),
    .rsif(bra_rsif),
    .brif(brif),
    .cbif(cbif)
  );

  reservation #(
    .DEPTH(MEM_ISSUE_DEPTH)
  ) mem_reservation0 (
    .clk(clk),
    .rst(rst),
    .rsif(mem_rsif),
    .brif(brif),
    .cbif(cbif)
  );
   
  // Physical Register File
  regfile regfile0 (
    .clk(clk),
    .rst(rst),
    .pfif(pfif),
    .cbif(cbif)
  );

endmodule
