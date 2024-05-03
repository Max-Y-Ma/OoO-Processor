module magic_regfile (
  input logic clk, rst,
  input logic rd_we,

  input logic [4:0] rs1_addr,
  input logic [4:0] rs2_addr,
  output logic [31:0] rs1_data,
  output logic [31:0] rs2_data,

  input logic [4:0] rd_addr,
  input logic [31:0] rd_wdata
);

logic [31:0] registers [31:1];

// Forward data if necessary
always_comb begin
  if (rs1_addr == 5'b0) begin
    rs1_data = 32'b0;
  end
  else if (rd_addr == rs1_addr && rd_we) begin
    rs1_data = rd_wdata;
  end
  else begin
    rs1_data = registers[rs1_addr];
  end

  if (rs2_addr == 5'b0) begin
    rs2_data = 32'b0;
  end
  else if (rd_addr == rs2_addr && rd_we) begin
    rs2_data = rd_wdata;
  end
  else begin
    rs2_data = registers[rs2_addr];
  end
end

always_ff @ (posedge clk) begin
  if (rst) begin
    integer i;
    for (i = 1; i < 32; i++) begin
      registers[i] <= 32'b0;
    end
  end
  else if (rd_we && rd_addr != 5'b0) begin
    registers[rd_addr] <= rd_wdata;
  end
end

endmodule : magic_regfile
