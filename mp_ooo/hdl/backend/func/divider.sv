module divider
import backend_types::*;
import rv32i_types::*;
#(
  parameter NUM_DIV_STAGES = 32
)
(
  input logic clk, rst,

  /* EBR Branch Bus */
  brb_itf.req          brif,

  /* Request interface */
  input  issue_stage_t istage,
  input  logic [31:0]  div_a, div_b,
  input  logic         ivalid,
  output logic         iready,

  /* Reply interface */
  output issue_stage_t ostage,
  output logic [31:0]  oresult,
  output logic         ovalid,
  input  logic         oready
);


  /* Synopsys Configuration Parameters */
  localparam NUM_CYCLES   = 16;
  localparam UNSIGNED_DIV = 0;
  localparam SIGNED_DIV   = 1;
  localparam SYNCH_RST    = 1;

  /* Divider EBR Flush */
  logic div_flush;
  assign div_flush = brif.broadcast & (ostage.meta.branch_mask[brif.tag]) & brif.kill;
  
  /* Divider Signals */
  logic [31:0] udiv_quo, sdiv_quo;
  logic [31:0] udiv_rem, sdiv_rem;
  logic udiv_exception, sdiv_exception;  // Not Supported
  logic udiv_valid, sdiv_valid;

  /* Output signals */
  logic div_stall;
  logic div_valid;

  // Divider Execution Logic (Needed Because Non-Pipelined)
  logic div_exec;
  always_ff @(posedge clk) begin
    if (rst | div_flush) begin
      div_exec <= 1'b0;
    end else begin
      if (ivalid) begin
        div_exec <= 1'b1;
      end else if (div_valid) begin
        div_exec <= 1'b0;
      end
    end
  end

  /* Request & Reply interface assignments */
  assign div_stall = (~oready & ovalid) | div_exec;
  assign iready    = ~(div_stall) & ~ivalid;
  assign div_valid = (udiv_valid | sdiv_valid) & div_exec & ~ivalid;

  /* Assert output valid until we recieve an oready signal from CDB arbiter */
  always_ff @(posedge clk) begin
    if (rst | oready | div_flush) begin
      ovalid <= 1'b0;
    end else if (div_valid) begin
      ovalid <= 1'b1;
    end
  end

  always_ff @ (posedge clk) begin
    if (rst) begin
      ostage  <= '0;
    end
    else if (~div_stall) begin
      ostage <= istage;

      /* BRB tag update */
      if (brif.broadcast) begin
        if (istage.meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            ostage.meta.branch_mask[brif.tag] <= 1'b0;
          end
        end
      end
    end
    else begin
      /* BRB tag update */
      if (brif.broadcast) begin
        if (ostage.meta.branch_mask[brif.tag]) begin
          if (brif.clean) begin
            ostage.meta.branch_mask[brif.tag] <= 1'b0;
          end
        end
      end
    end
  end

  DW_div_seq #(
    .a_width(32),
    .b_width(32),
    .tc_mode(UNSIGNED_DIV),
    .num_cyc(NUM_CYCLES),
    .rst_mode(SYNCH_RST)
  ) udivider0 (
    .clk(clk),
    .rst_n(~rst & ~div_flush),
    .hold(~div_exec),
    .start(ivalid),
    .a(div_a),
    .b(div_b),
    .complete(udiv_valid),
    .divide_by_0(udiv_exception),
    .quotient(udiv_quo),
    .remainder(udiv_rem)
  );

  DW_div_seq #(
    .a_width(32),
    .b_width(32),
    .tc_mode(SIGNED_DIV),
    .num_cyc(NUM_CYCLES),
    .rst_mode(SYNCH_RST)
  ) sdivider0 (
    .clk(clk),
    .rst_n(~rst & ~div_flush),
    .hold(~div_exec),
    .start(ivalid),
    .a(div_a),
    .b(div_b),
    .complete(sdiv_valid),
    .divide_by_0(sdiv_exception),
    .quotient(sdiv_quo),
    .remainder(sdiv_rem)
  );

  /* Result Calculations */
  always_comb begin
    unique case (ostage.ctrl.op)
      {1'b0, ss_div}: oresult = sdiv_quo;
      {1'b0, uu_div}: oresult = udiv_quo;
      {1'b0, ss_rem}: oresult = sdiv_rem;
      {1'b0, uu_rem}: oresult = udiv_rem;
      default:        oresult = 'x;
    endcase
  end
endmodule
