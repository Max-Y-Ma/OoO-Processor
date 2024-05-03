module plru
import cache_types::*;
#(
  parameter WAYS = 4,
  localparam PLRU_HEIGHT = $clog2(WAYS)-1,
  localparam PLRU_SIZE   = WAYS-1,
  localparam PLRU_IDX    = $clog2(PLRU_SIZE),
  localparam LEAF_START  = ((unsigned'(WAYS) >> 1'b1) - 1'b1),
  localparam WAYS_IDX    = $clog2(WAYS)
)
(
  input  logic clk, rst, evict_update,
  input  logic [3:0] set_addr,
  input  logic [WAYS-1:0] cache_hit_vector,
  output logic [WAYS-1:0] evict_candidate
);

generate
  logic [PLRU_SIZE-1:0] plru_state;
  logic [PLRU_SIZE-1:0] plru_new_state;

  /* Generate regular LRU eviction algorithm */
  if (WAYS == 2) begin
    /* Determine next state, which is the least recently used */
    logic cache_index;
    always_comb begin
      // One Hot Encoder
      cache_index = '0;
      for (int i = 0; i < WAYS; i++) begin
        if (cache_hit_vector[i]) begin
          cache_index = (WAYS-1)'(unsigned'(i));
        end
      end

      plru_new_state = ~cache_index;
    end

    /* The candidate to evict is the least recently used */
    always_comb begin
      evict_candidate = '0;
      for (int i = 0; i < WAYS; i++) begin
        if (plru_state == (WAYS-1)'(unsigned'(i))) begin
          evict_candidate[i] = 1'b1;
        end
      end
    end
  end

  /* Generate PLRU eviction algorithm */
  else begin
    logic [PLRU_IDX-1:0]              plru_index;
    logic [WAYS_IDX-1:0]              evict_index;
    logic [WAYS_IDX-1:0]              evict_index_start;
    logic [$clog2(PLRU_HEIGHT+1):0]   evict_height;

    logic [PLRU_IDX-1:0]              update_index;
    logic [PLRU_IDX-1:0]              update_upper;
    logic [PLRU_IDX-1:0]              update_lower;
    logic [$clog2(PLRU_HEIGHT+1):0]   update_height;

    logic [WAYS_IDX-1:0]              cache_index;

    always_comb begin
      // Default Values
      plru_new_state  = plru_state;
      update_height   = '0;
      update_index    = '0;
      update_lower    = '0;
      update_upper    = unsigned'(WAYS[PLRU_IDX:1]);
      cache_index     = '0;

      plru_index      = '0;
      evict_height    = '0;
      evict_index     = '0;
      evict_index_start = '0;
      evict_candidate = '0;

      // One Hot Encoder
      for (int i = 0; i < WAYS; i++) begin
        if (cache_hit_vector[i]) begin
          cache_index = WAYS_IDX'(unsigned'(i));
        end
      end

      // Traverse tree to update
      while (update_height <= unsigned'(PLRU_HEIGHT[PLRU_IDX-1:0])) begin
        // Check whether in bin or not and calculate new bin
        if (update_lower <= cache_index && cache_index < update_upper) begin
          plru_new_state[unsigned'(PLRU_SIZE-1)-update_index] = 1'b0;
          update_index = (update_index << 1'b1) + 2'h1;
          update_upper = (update_upper >> 1'b1);
        end
        else begin
          plru_new_state[unsigned'(PLRU_SIZE-1)-update_index] = 1'b1;
          update_index = (update_index << 1'b1) + 2'h2;
          update_lower = update_upper;
          update_upper = update_lower + PLRU_IDX'(WAYS / ((update_height+1'b1) << 2'h2));
        end

        update_height = update_height + 1'b1;
      end

      // Given PLRU state, give eviction candidate
      while (evict_height < unsigned'(PLRU_HEIGHT[PLRU_IDX-1:0])) begin
        if (~plru_state[unsigned'(PLRU_SIZE-1)-plru_index]) begin
          plru_index = (plru_index << 1'b1) + 2'h2;
        end
        else begin
          plru_index = (plru_index << 1'b1) + 2'h1;
        end
        evict_height = evict_height + 1'b1;
      end
      evict_index_start = (plru_index - PLRU_IDX'(LEAF_START)) << 1'b1;
      evict_index = evict_index_start + (plru_state[unsigned'(PLRU_SIZE-1)-plru_index] ? 1'b0 : 1'b1);

      // Decoder for evict index to one hot evict candidate
      for (int i = 0; i < WAYS; i++) begin
        if (evict_index == WAYS_IDX'(unsigned'(i))) begin
          evict_candidate[i] = 1'b1;
        end
      end
    end
  end
endgenerate

ff_array #(.WIDTH(WAYS-1)) plru_array (
  .clk0       (clk),
  .rst0       (rst),
  .csb0       (1'b0),
  .web0       (evict_update),
  .addr0      (set_addr),
  .din0       (plru_new_state),
  .dout0      (plru_state)
);

endmodule : plru
