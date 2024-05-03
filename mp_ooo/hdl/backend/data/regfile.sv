/**
 * Module: regfile
 * File  : regfile.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * The Physical Register File (PRF) is a bank of architecturally-decoupled register values.
 * This means that it contains both active and stale register values used by executing instructions. 
*/
module regfile 
import backend_types::*;
(
  input  logic     clk, rst,
  prf_i.r          pfif,
  cdb_i.req        cbif
);

  // Register File Data
  logic [31:0] data [NUM_PHYS_REGISTERS];

  // 1 Synchronous Write Port
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < NUM_PHYS_REGISTERS; i++) begin
        data[i] <= '0;
      end
    // CDB Snoop/Update Logic 
    end else if (cbif.valid && (cbif.prd != '0)) begin
      data[cbif.prd] <= cbif.result;
    end
  end

  // 2 Combinational Read Port
  always_comb begin
    if (rst) begin
      pfif.rs1_rdata = 'x;
      pfif.rs2_rdata = 'x;
    end else begin
      if (pfif.prs1_addr == '0) begin
        pfif.rs1_rdata = '0;
      end else if (cbif.valid && (pfif.prs1_addr == cbif.prd)) begin
        pfif.rs1_rdata = cbif.result;
      end else begin
        pfif.rs1_rdata = data[pfif.prs1_addr];
      end

      if (pfif.prs2_addr == '0) begin
        pfif.rs2_rdata = '0;
      end else if (cbif.valid && (pfif.prs2_addr == cbif.prd)) begin
        pfif.rs2_rdata = cbif.result;
      end else begin
        pfif.rs2_rdata = data[pfif.prs2_addr];
      end
    end
  end
    
endmodule : regfile
