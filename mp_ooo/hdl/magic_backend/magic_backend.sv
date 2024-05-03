module magic_backend
import magic_backend_types::*;
(
  input logic         clk,
  input logic         rst,
  input instr_queue_t instr,
  input logic         instr_empty,
  output logic        instr_ack,

  output logic        backend_jmp,
  output logic        backend_jmp_answer,
  output logic [31:0] backend_jmp_pc,
  output logic [31:0] backend_jmp_dest,

  output logic [3:0]  dmem_rmask,
  output logic [3:0]  dmem_wmask,
  input logic [31:0]  dmem_rdata,
  output logic [31:0] dmem_wdata,
  output logic [31:0] dmem_addr
);

// RVFI struct
rvfi_signals_t rvfi;

// Regfile
logic [31:0]   rs1_data, rs2_data;
logic [31:0]   rd_wdata;

// Decode Signals
control_word_t control_word;
logic [31:0]   immediate;
logic [4:0]    rd_addr;
logic          rd_we;

// Execute Signals
logic [31:0]   alu_in_a, alu_in_b, alu_out_f;
logic          br_en;

// Memory signals
logic [31:0]   load_data;

// Writeback signals
logic [31:0]   alu_out_f_wb;
load_ops       load_op_wb;
logic          wb_mem_wb, wb_pc_wb;
logic [31:0]   pc_wb;
rvfi_signals_t rvfi_wb;
logic [4:0]    rd_addr_wb;
logic          rd_we_wb;

logic [63:0]   order;

// Always be accepting instructions if not empty
assign instr_ack = ~instr_empty;

always_ff @ (posedge clk) begin
  if (rst) begin
    order <= '0;
  end
  if (instr_ack) begin
    order <= order + 1;
  end
end

// Register barrier for magic dmem
always_ff @ (posedge clk) begin
  alu_out_f_wb <= alu_out_f;
  load_op_wb   <= load_ops'(control_word.mem_op);
  wb_mem_wb    <= control_word.wb_mem;
  wb_pc_wb     <= control_word.wb_pc;
  pc_wb        <= instr.pc + 4;
  rvfi_wb      <= rvfi;
  rd_addr_wb   <= rd_addr;
  rd_we_wb     <= rd_we;
end

always_comb begin
  // Decode Stage
  rd_addr = (control_word.instr_type == s || control_word.instr_type == b) ? 5'b0 : instr[11:7];

  // Execute Stage
  alu_in_a           = (control_word.alu_m1_sel == rs1_out ? rs1_data : instr.pc);
  alu_in_b           = (control_word.alu_m2_sel == rs2_out ? rs2_data : immediate);
  backend_jmp        = control_word.br | control_word.jmp;
  backend_jmp_answer = (br_en & control_word.br) | control_word.jmp;
  backend_jmp_dest   = (immediate + (control_word.ex_pc_sel == pc_rs1 ? rs1_data : instr.pc)) & ~(32'b1);
  backend_jmp_pc     = instr.pc;

  // Memory Stage

  // Mask calculations
  dmem_rmask = 4'b0000;
  dmem_wmask = 4'b0000;
  dmem_wdata = 32'b0;
  dmem_addr  = {alu_out_f[31:2], 2'b0};
  unique case (control_word.mem_op)
    lb, lbu: dmem_rmask = 4'b0001 << (alu_out_f & 2'b11);
    lh, lhu: dmem_rmask = 4'b0011 << (alu_out_f & 2'b10);
    lw:      dmem_rmask = 4'b1111;
    sb: begin
      dmem_wmask = 4'b0001 << (alu_out_f & 2'b11);
      dmem_wdata = (rs2_data << {(alu_out_f & 2'b11), 3'b0});
    end
    sh: begin
      dmem_wmask = 4'b0011 << (alu_out_f & 2'b10);
      dmem_wdata = (rs2_data << {(alu_out_f & 2'b10), 3'b0});
    end
    sw: begin
      dmem_wmask = 4'b1111;
      dmem_wdata = (rs2_data);
    end
    none: begin end
    default: begin
      dmem_rmask = 4'bxxxx;
      dmem_wmask = 4'bxxxx;
      dmem_wdata = 'x;
    end
  endcase

  // Do not change architectural state if ack == 0
  if (instr_ack == 0) begin
    backend_jmp        = '0;
    rd_we              = '0;
    dmem_wmask         = '0;
  end
  else begin
    rd_we = control_word.rd_we;
  end

  // RVFI assignments
  rvfi.valid     = instr_ack;
  rvfi.order     = order;
  rvfi.inst      = instr.instr;
  rvfi.rs1_addr  = instr.instr[19:15];
  rvfi.rs2_addr  = instr.instr[24:20];
  rvfi.rs1_rdata = rs1_data;
  rvfi.rs2_rdata = rs2_data;
  rvfi.rd_addr   = rd_addr;
  rvfi.pc_rdata  = instr.pc;
  rvfi.pc_wdata  = backend_jmp_answer ? backend_jmp_dest : instr.pc + 4;
  rvfi.mem_addr  = alu_out_f;
  rvfi.mem_rmask = dmem_rmask;
  rvfi.mem_wmask = dmem_wmask;
  rvfi.mem_wdata = dmem_wdata;

  // Writeback Stage

  // Get correct load value from memory
  unique case ({alu_out_f_wb[1:0], load_op_wb})
    {2'b00, wb_lbu}: load_data = {24'b0,                dmem_rdata[7:0]};
    {2'b01, wb_lbu}: load_data = {24'b0,                dmem_rdata[15:8]};
    {2'b10, wb_lbu}: load_data = {24'b0,                dmem_rdata[23:16]};
    {2'b11, wb_lbu}: load_data = {24'b0,                dmem_rdata[31:24]};
    {2'b00, wb_lb}:  load_data = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
    {2'b01, wb_lb}:  load_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
    {2'b10, wb_lb}:  load_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
    {2'b11, wb_lb}:  load_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};

    {2'b00, wb_lhu}: load_data = {16'b0,                dmem_rdata[15:0]};
    {2'b10, wb_lhu}: load_data = {16'b0,                dmem_rdata[31:16]};
    {2'b00, wb_lh}:  load_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
    {2'b10, wb_lh}:  load_data = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
    default: load_data = dmem_rdata;
  endcase

  unique case({wb_mem_wb, wb_pc_wb})
    2'b00: rd_wdata = alu_out_f_wb;
    2'b01: rd_wdata = pc_wb;
    2'b10: rd_wdata = load_data;
    default: rd_wdata = 'x;
  endcase

end

// Decode helper modules
magic_regfile magic_regfile0 (
  .clk(clk),
  .rst(rst),

  .rs1_addr(instr.instr[19:15]),
  .rs2_addr(instr.instr[24:20]),
  .rs1_data(rs1_data),
  .rs2_data(rs2_data),

  .rd_we(rd_we_wb),
  .rd_addr(rd_addr_wb),
  .rd_wdata(rd_wdata)
);

immediate immediate0(
  .instr(instr.instr),
  .instr_type(control_word.instr_type),
  .immediate(immediate)
);

control control0(
  .instr(instr.instr),
  .control_word(control_word)
);

// Execute helper modules
magic_alu magic_alu0 (
  .alu_op(control_word.alu_op),
  .alu_bypass(control_word.alu_bypass),
  .alu_in_a(alu_in_a),
  .alu_in_b(alu_in_b),
  .alu_out_f(alu_out_f)
);

branch_check brank_check0 (
  .alu_in_a(alu_in_a),
  .alu_in_b(alu_in_b),
  .br_op(control_word.br_op),
  .br_en(br_en)
);

endmodule
