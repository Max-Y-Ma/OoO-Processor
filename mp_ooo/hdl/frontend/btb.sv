module btb
#(
  parameter  SET_IDX  = (7),
  localparam PC_BITS = (15),
  localparam TAG_SIZE = (PC_BITS - SET_IDX - 2),
  localparam DATA_SIZE = (PC_BITS - 1),
  localparam BTB_SIZE = (TAG_SIZE + DATA_SIZE)
)
(
  //input logic         clk, rst,
  input logic         clk,

  input logic         backend_jmp,
  input logic         backend_jmp_answer,
  input logic [31:0]  backend_jmp_pc,
  input logic [31:0]  backend_jmp_dest,

  input logic [31:0]  pc,
  output logic        btb_hit,
  output logic [31:0] btb_pc
);

logic [BTB_SIZE-1:0] backend_btb_entry;
logic [BTB_SIZE-1:0] btb_entry;
logic [BTB_SIZE-1:0] btb_entry_wt;
logic                btb_wt;
logic [BTB_SIZE-1:0] btb_entry_not_wt;

logic [TAG_SIZE-1:0] btb_entry_not_wt_tag;
logic [30:0] btb_entry_not_wt_data;

logic [31:0]         pc_reg;

logic                update_btb;

always_ff @ (posedge clk) begin
  pc_reg <= pc;

  /* Write through emulation */
  if (update_btb && backend_jmp_pc[SET_IDX+1:2] == pc[SET_IDX+1:2]) begin
    btb_entry_wt <= backend_btb_entry;
    btb_wt <= '1;
  end
  else begin
    btb_wt <= '0;
  end
end

always_comb begin
  update_btb = backend_jmp & backend_jmp_answer;
  backend_btb_entry = {backend_jmp_pc[PC_BITS-1:PC_BITS-TAG_SIZE], backend_jmp_dest[PC_BITS-1:2], 1'b1};

  /* Write through emulation */
  if (btb_wt) begin
    btb_entry = btb_entry_wt;
  end
  else begin
    btb_entry = btb_entry_not_wt;
  end

  /* Return BTB PC if tag match */
  if (btb_entry[BTB_SIZE-1:DATA_SIZE] == pc_reg[PC_BITS-1:PC_BITS-TAG_SIZE] && btb_entry[0]) begin
    btb_hit = '1;
    btb_pc  = {16'h6000, 1'b0, btb_entry[PC_BITS-2:1], 2'b00};
  end
  else begin
    btb_hit = '0;
    btb_pc  = '0;
  end
end

/* Only update btb on backend hit */
btb_array btb_array0 (
  .clk0(clk),
  .csb0(~update_btb),
  .addr0(backend_jmp_pc[SET_IDX+1:2]),
  .din0(backend_btb_entry),

  .clk1(clk),
  .csb1(1'b0),
  .addr1(pc[SET_IDX+1:2]),
  .dout1(btb_entry_not_wt)
);

//always_comb begin
//  btb_entry_not_wt = {btb_entry_not_wt_tag, btb_entry_not_wt_data};
//end
//
//btb_tag_array btb_tag_array0 (
//  .clk0(clk),
//  .csb0(~update_btb),
//  .addr0(backend_jmp_pc[SET_IDX+1:2]),
//  .din0(backend_btb_entry[BTB_SIZE-1:31]),
//
//  .clk1(clk),
//  .csb1(1'b0),
//  .addr1(pc[SET_IDX+1:2]),
//  .dout1(btb_entry_not_wt_tag)
//);
//
//btb_data_array btb_data_array0 (
//  .clk0(clk),
//  .csb0(~update_btb),
//  .addr0(backend_jmp_pc[SET_IDX+1:2]),
//  .din0(backend_btb_entry[30:0]),
//
//  .clk1(clk),
//  .csb1(1'b0),
//  .addr1(pc[SET_IDX+1:2]),
//  .dout1(btb_entry_not_wt_data)
//);
endmodule

