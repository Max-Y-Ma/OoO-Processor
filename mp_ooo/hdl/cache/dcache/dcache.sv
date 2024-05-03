module dcache
import cache_types::*;
#(
  parameter  WAYS            = 4,
  parameter  SETS            = 16,
  localparam SET_BITS        = $clog2(SETS),
  localparam CACHELINE_BYTES = 32,
  localparam CACHELINE_BITS  = $clog2(CACHELINE_BYTES),
  localparam TAG_BITS        = 32 - SET_BITS - CACHELINE_BITS
) (
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);

    /* Cache Control Signals */
    logic             cache_read_request;
    logic             cache_write_request;
    logic             write_from_cpu;
    logic             write_from_mem;

    logic             idle;
    logic             dirty;

    logic             cache_hit;
    logic [WAYS-1:0]  cache_hit_vector;


    logic             evict_update;
    logic [WAYS-1:0]  evict_candidate;

    // Cache Arrays    
    logic              tag_array_csb0    [WAYS-1:0];
    logic [TAG_BITS:0] tag_array_dout0   [WAYS-1:0];
    logic              tag_array_web0    [WAYS-1:0];

    logic              data_array_csb0   [WAYS-1:0];
    logic [255:0]      data_array_dout0  [WAYS-1:0];
    logic [255:0]      data_array_din0   [WAYS-1:0];
    logic              data_array_web0   [WAYS-1:0];
    logic [31:0]       data_array_wmask  [WAYS-1:0];

    logic              dirty_array_web0  [WAYS-1:0];
    logic              dirty_array_din0  [WAYS-1:0];

    logic              valid_array_csb0  [WAYS-1:0];
    logic              valid_array_din0  [WAYS-1:0];
    logic              valid_array_dout0 [WAYS-1:0];
    logic              valid_array_web0  [WAYS-1:0];

    /* UFP Address partition and register */
    logic [31:0]               ufp_addr_reg;
    logic [3:0]                ufp_rmask_reg;
    logic [3:0]                ufp_wmask_reg;
    logic [31:0]               ufp_wdata_reg;
    logic [TAG_BITS-1:0]       tag_val;
    logic [SET_BITS-1:0]       set_addr;
    logic [CACHELINE_BITS-1:0] block_offset;

    assign tag_val      = ufp_addr_reg[31:SET_BITS+CACHELINE_BITS];
    assign block_offset = ufp_addr_reg[CACHELINE_BITS-1:0];

    assign set_addr     = idle ? ufp_addr[SET_BITS+CACHELINE_BITS-1:CACHELINE_BITS] 
                               : ufp_addr_reg[SET_BITS+CACHELINE_BITS-1:CACHELINE_BITS];

    /* Register signals because we're not pipelined yet */
    always_ff @ (posedge clk) begin
      if (rst) begin
        ufp_addr_reg  <= '0;
        ufp_wmask_reg <= '0;
        ufp_rmask_reg <= '0;
        ufp_wdata_reg <= '0;
      end
      else if (idle) begin
        ufp_addr_reg  <= ufp_addr;
        ufp_wmask_reg <= ufp_wmask;
        ufp_rmask_reg <= ufp_rmask;
        ufp_wdata_reg <= ufp_wdata;
      end
    end

    always_comb begin
      // DRAM signals
      dfp_wdata = 'x;
      for (int i = 0; i < WAYS; i++) begin
        if (evict_candidate[i]) begin
          dfp_wdata = data_array_dout0[i];
        end 
      end

      // By default use address from CPU
      dfp_addr = {ufp_addr_reg[31:CACHELINE_BITS], 5'b0};

      // Cache Request Logic
      if (idle) begin
        cache_read_request  = |ufp_rmask;
        cache_write_request = |ufp_wmask;
      end
      else begin
        cache_read_request  = |ufp_rmask_reg;
        cache_write_request = |ufp_wmask_reg;
      end

      // Writeback logic
      dirty = 1'b0;

      // Calculate hit vector and data output
      ufp_rdata       = 32'b0;
      for (int i = 0; i < WAYS; i++) begin

        // Don't write unless memory or cpu writing
        tag_array_web0[i]     = 1'b1;
        data_array_web0[i]    = 1'b1;
        data_array_wmask[i]   = 32'b0;
        data_array_din0[i]    = 256'b0;
        valid_array_din0[i]   = 1'b0;
        valid_array_web0[i]   = 1'b1;
        dirty_array_din0[i]   = 1'b0;

        // Checks tag hits
        cache_hit_vector[i] = 1'b0;
        if (tag_array_dout0[i][TAG_BITS-1:0] == tag_val) begin
          // Mark as hit and set the cpu rdata correctly
          cache_hit_vector[i] = valid_array_dout0[i];
          ufp_rdata = data_array_dout0[i][({block_offset, 3'b0})+:32];

          // Write to cache if doing a store and there is a hit
          if (write_from_cpu) begin
            tag_array_web0[i]   = 1'b0;
            data_array_web0[i]  = 1'b0;
            data_array_din0[i]  = 256'b0 | (ufp_wdata_reg << ({block_offset, 3'b0}));
            data_array_wmask[i] = 32'b0 | ufp_wmask_reg << (block_offset);

            // Mark Array as valid and dirty during a write from cpu
            valid_array_din0[i] = 1'b1;
            valid_array_web0[i] = 1'b0;
            dirty_array_din0[i] = 1'b1;
            dirty_array_web0[i] = 1'b0;
          end
        end
        // Write to cache after writeback completes
        // Only overwrite the eviction candidate
        if (write_from_mem && evict_candidate[i] == 1'b1) begin
          cache_hit_vector[i] = 1'b1;
          tag_array_web0[i]  = 1'b0;
          data_array_web0[i] = 1'b0;
          data_array_wmask[i] = ~32'b0;
          data_array_din0[i] = dfp_rdata;

          // Mark data from memory as clean and valid
          valid_array_din0[i] = 1'b1;
          valid_array_web0[i] = 1'b0;
          dirty_array_din0[i] = 1'b0;
          dirty_array_web0[i] = 1'b0;
        end

        // Dirty bit write back logic
        // Set the dfp_addr correctly for writeback
        if (evict_candidate[i] & valid_array_dout0[i] & tag_array_dout0[i][TAG_BITS]) begin
          dirty = 1'b1;
          if (dfp_write) begin
            dfp_addr = {tag_array_dout0[i][TAG_BITS-1:0], set_addr, 5'b0};
          end
        end
      end

      // Cache Hit/WB and Data Logic and
      cache_hit       = |cache_hit_vector;

      // Update eviction logic when cache is replying
      evict_update = ~ufp_resp;
    end

    generate for (genvar i = 0; i < WAYS; i++) begin : arrays
        mp_dcache_data_array data_array (
            .clk0       (clk),
            .csb0       (data_array_csb0[i]),
            .web0       (data_array_web0[i]),
            .wmask0     (data_array_wmask[i]),
            .addr0      (set_addr),
            .din0       (data_array_din0[i]),
            .dout0      (data_array_dout0[i])
        );
        mp_dcache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (tag_array_csb0[i]),
            .web0       (tag_array_web0[i]),
            .addr0      (set_addr),
            .din0       ({dirty_array_din0[i], tag_val}),
            .dout0      (tag_array_dout0[i])
        );
        ff_array #(.WIDTH(1)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (valid_array_csb0[i]),
            .web0       (valid_array_web0[i]),
            .addr0      (set_addr),
            .din0       (valid_array_din0[i]),
            .dout0      (valid_array_dout0[i])
        );
    end endgenerate

    dcache_control #(.WAYS(WAYS)) cache_control0(.*);
    plru    #(.WAYS(WAYS)) plru0(.*);

endmodule
