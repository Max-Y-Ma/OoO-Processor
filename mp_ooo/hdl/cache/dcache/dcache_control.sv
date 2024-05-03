module dcache_control
import cache_types::*;
#(
  parameter WAYS = 4
) (
  input logic       clk, rst,

  // Cache Datapath interface
  input logic  cache_hit,
  input logic  cache_read_request,
  input logic  cache_write_request,

  // UFP Interface
  output logic ufp_resp,

  // DFP Interface
  input logic  dfp_resp,
  output logic dfp_read,
  output logic dfp_write,

  // Chip Select Signals
  output logic tag_array_csb0   [WAYS-1:0],
  output logic data_array_csb0  [WAYS-1:0],
  output logic valid_array_csb0 [WAYS-1:0],

  // SRAM Controls
  output logic write_from_mem,
  output logic write_from_cpu,

  output logic idle,

  // Dirty Bit
  input logic  dirty
);

controller_state_t curr_state;
controller_state_t next_state;

logic cache_request;

always_comb begin
  // Defaults
  next_state     = curr_state;
  write_from_mem = 1'b0;
  write_from_cpu = 1'b0;
  dfp_write      = 1'b0;
  dfp_read       = 1'b0;
  ufp_resp       = 1'b0;
  cache_request  = cache_read_request | cache_write_request;
  idle           = (curr_state == IDLE);

  // Default Chip Select Signals
  for (int i = 0; i < WAYS; i++) begin
    tag_array_csb0[i]   = 1'b1;
    data_array_csb0[i]  = 1'b1;
    valid_array_csb0[i] = 1'b1;
  end

  unique case (curr_state)
    IDLE: begin
      if (cache_request) begin
        /* Assert Chip Select Signals */
        for (int i = 0; i < WAYS; i++) begin
          tag_array_csb0[i]   = 1'b0;
          data_array_csb0[i]  = 1'b0;
          valid_array_csb0[i] = 1'b0;
        end

        next_state = CHECK;
      end
    end
    CHECK: begin
      if (cache_hit) begin
        write_from_cpu = cache_write_request;
        ufp_resp = 1'b1;
        // if (cache_request) begin
        //   next_state = CHECK;
        // end
        // else begin
          next_state = IDLE;
        // end

        /* Assert Chip Select Signals */
        for (int i = 0; i < WAYS; i++) begin
          tag_array_csb0[i]   = 1'b0;
          data_array_csb0[i]  = 1'b0;
          valid_array_csb0[i] = 1'b0;
        end
      end
      else if (dirty) begin
        next_state = WRITEBACK;
      end
      else begin
        next_state = FETCH;
      end
    end
    WRITEBACK: begin
      dfp_write = 1'b1;
      if (dfp_resp) begin
        next_state = FETCH;
      end
      else begin
        next_state = WRITEBACK;
      end
    end
    FETCH: begin
      dfp_read = 1'b1;
      if (dfp_resp) begin
        write_from_mem = 1'b1;
        next_state = FETCH_WAIT;

        /* Assert Chip Select Signals */
        for (int i = 0; i < WAYS; i++) begin
          tag_array_csb0[i]   = 1'b0;
          data_array_csb0[i]  = 1'b0;
          valid_array_csb0[i] = 1'b0;
        end
      end
      else begin
        next_state = FETCH;
      end
    end
    FETCH_WAIT: begin
      /* Assert Chip Select Signals */
      for (int i = 0; i < WAYS; i++) begin
        tag_array_csb0[i]   = 1'b0;
        data_array_csb0[i]  = 1'b0;
        valid_array_csb0[i] = 1'b0;
      end

      next_state = CHECK;
    end
    default: begin end
  endcase
end

// Next state flipflop
always_ff @ (posedge clk) begin
  if (rst) begin
    curr_state <= IDLE;
  end
  else begin
    curr_state <= next_state;
  end
end

endmodule
