module ghr
(
  input logic clk, rst,
  
  input logic shift_en,
  input logic shift_data,
  input logic wen,
  input logic [31:0] wdata,
  output logic [31:0] rdata,
  output logic [31:0] rdata_reg
);

logic [31:0] data;

always_ff @ (posedge clk) begin
  if (rst) begin
    data <= '0;
  end else begin
    if (wen) begin
      data <= wdata;
    end else if (shift_en) begin
      data <= {data[30:0], shift_data};
    end
  end
end

/* Write through, cuz why not? */
always_comb begin
  if (rst) begin
    rdata = '0;
  end else begin
    if (wen) begin
      rdata = wdata;
    end else if (shift_en) begin
      rdata = {data[30:0], shift_data};
    end else begin
      rdata = data;
    end
  end

  rdata_reg = data;
end

endmodule
