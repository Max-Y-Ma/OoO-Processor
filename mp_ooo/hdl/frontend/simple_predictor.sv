module simple_predictor
#(
  parameter SET_IDX = (8)
)
(
  input logic              clk,

  input logic        backend_jmp,
  input logic        backend_jmp_answer,
  input logic [31:0] backend_pc,

  input logic [31:0] pc,
  //input logic [31:0] ghr,
  //input logic [31:0] backend_ghr,
  output logic       guess_jmp,

  input logic [1:0]  backend_2bsat,
  output logic [1:0] guess_2bsat

);

logic [1:0] guess_counter;
logic [1:0] new_counter;
logic [2:0] counter_array_dout;
//logic new_counter_low, new_counter_high, guess_counter_low, guess_counter_high;

logic [31:0] gshare_fetch, gshare_backend;

logic [SET_IDX:0] rst_counter;
logic [SET_IDX-1:0] waddr;

always_comb begin
  //gshare_fetch = (pc >> 2) ^ ghr;
  //gshare_backend = (backend_pc >> 2) ^ backend_ghr;
  gshare_fetch = (pc >> 2);
  gshare_backend = (backend_pc >> 2);
end

/* Two bit saturating predictor */
always_comb begin
  /* Update counter based on backend answer */
  if (backend_jmp_answer) begin
    if (backend_2bsat != 2'b11) begin
      new_counter = backend_2bsat + 1'b1;
    end else begin
      new_counter = backend_2bsat;
    end
  end else begin
    if (backend_2bsat != 2'b00) begin
      new_counter = backend_2bsat - 1'b1;
    end else begin
      new_counter = backend_2bsat;
    end
  end

  /* Generate new guess based on guess_counter */
  if (counter_array_dout[2]) begin
    guess_counter = counter_array_dout[1:0];
  end else begin
    guess_counter = 2'b10;
  end
  
  guess_jmp = guess_counter[1] ? 1'b1 : 1'b0;
  
  guess_2bsat = guess_counter;

  //guess_counter = {~guess_counter_high, guess_counter_low};

  //new_counter_low = new_counter[0];
  //new_counter_high = ~new_counter[1];

end

/* One bit predictor */
//always_comb begin
//  /* Update counter based on backend answer */
//  if (backend_jmp_answer) begin
//    if (curr_counter == 2'b00) begin
//      new_counter = curr_counter + 1'b1;
//    end else begin
//      new_counter = curr_counter;
//    end
//  end else begin
//    if (curr_counter == 2'b01) begin
//      new_counter = curr_counter - 1'b1;
//    end else begin
//      new_counter = curr_counter;
//    end
//  end
//
//  /* Generate new guess based on guess_counter */
//  guess_jmp = guess_counter[0] ? 1'b1 : 1'b0;
//end

//bim_array #(.SET_IDX(SET_IDX), .WIDTH(2)) bim_array0 (
//  .clk(clk),
//  .rst(rst),
//  .bim_raddr0(gshare_fetch[SET_IDX-1:0]),
//  .bim_rdata0(guess_counter),
//  .bim_raddr1(gshare_backend[SET_IDX-1:0]),
//  .bim_rdata1(curr_counter),
//  .bim_we(backend_jmp),
//  .bim_waddr(gshare_backend[SET_IDX-1:0]),
//  .bim_wdata(new_counter)
//);

//always_comb begin
//  if (|rst_counter) begin
//    waddr = rst_counter;
//  end else begin
//    waddr = gshare_backend[SET_IDX-1:0];
//  end
//end
//
//always_ff @ (posedge clk) begin
//  if (rst) begin
//    rst_counter <= '0;
//  end else if (~rst_counter[SET_IDX]) begin
//    rst_counter <= rst_counter + 1'b1;
//  end
//end

counter_array counter_array0 (
  .clk0(clk),
  .csb0(~backend_jmp),
  .addr0(gshare_backend[SET_IDX-1:0]),
  .din0({1'b1, new_counter}),

  .clk1(clk),
  .csb1(1'b0),
  .addr1(gshare_fetch[SET_IDX-1:0]),
  .dout1(counter_array_dout)
);

endmodule
