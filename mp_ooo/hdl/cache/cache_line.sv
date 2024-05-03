module cache_line
import cache_types::*;
(
  input logic clk, rst,

  /* Request Interface */
  output logic [31:0]  bmem_addr,
  output logic         bmem_read,
  output logic         bmem_write,
  output logic [63:0]  bmem_wdata,

  /* Queue interface */
  input logic          bmem_ready,

  /* Response Interface */
  input logic  [31:0]  bmem_raddr,
  input logic  [63:0]  bmem_rdata,
  input logic          bmem_rvalid,

  /* ICache Interface */
  input logic  [31:0]  icache_addr,
  input logic          icache_read,
  input logic          icache_write,
  output logic [255:0] icache_rdata,
  input logic  [255:0] icache_wdata,
  output logic         icache_resp,

  /* DCache Interface */
  input logic [31:0]   dcache_addr,
  input logic          dcache_read,
  input logic          dcache_write,
  output logic [255:0] dcache_rdata,
  input logic  [255:0] dcache_wdata,
  output logic         dcache_resp
);

/* Arbitrate round robin, (TODO: Change this actual dogwater) */
logic arbiter;
logic next_arbiter;

/* Stay in serialize / deserialize for three times */
logic [1:0] serdes_count;
logic [1:0] next_serdes_count;

logic nonsense;
assign nonsense = bmem_raddr[0];

/* Cache States */
cacheline_state_t curr_state;
cacheline_state_t next_state;

/* Cacheline Read Buffer */
logic [255:0]     line_buffer;
logic [255:0]     next_line_buffer;

/* Prefetch Constrol Signals */ 
logic prefetch_req;
logic next_prefetch_req;

logic prefetch_ready;
logic next_prefetch_ready;

logic prefetch_hit;
logic next_prefetch_hit;

/* Prefetch X + 1 Data Signals */
logic [31:0] prefetch_iaddress;
logic [31:0] next_prefetch_iaddress;
logic [255:0] prefetch_line_buffer;       
logic [255:0] next_prefetch_line_buffer;

/* Request Logic */
logic             icache_req;
logic             dcache_req;

/* Next state FF */
always_ff @ (posedge clk) begin
  if (rst) begin
    curr_state   <= LINE_IDLE;
    arbiter      <= '0;
    serdes_count <= '0;

    prefetch_req   <= '0;
    prefetch_ready <= '0;
    prefetch_hit   <= '0;
  end
  else begin
    curr_state   <= next_state;
    arbiter      <= next_arbiter;
    serdes_count <= next_serdes_count;
    line_buffer  <= next_line_buffer;

    prefetch_req         <= next_prefetch_req;
    prefetch_ready       <= next_prefetch_ready;
    prefetch_line_buffer <= next_prefetch_line_buffer;
    prefetch_iaddress    <= next_prefetch_iaddress;
    prefetch_hit         <= next_prefetch_hit;
  end
end

/* Next state / output logic */
always_comb begin
  /* Default Values */
  icache_resp           = '0;
  dcache_resp           = '0;
  bmem_addr             = 'x;
  bmem_read             = '0;
  bmem_write            = '0;
  bmem_wdata            = 'x;
  next_arbiter          = arbiter;
  next_state            = curr_state;
  next_serdes_count     = serdes_count;
  next_line_buffer      = line_buffer;
  icache_rdata          = prefetch_hit ? next_prefetch_line_buffer : next_line_buffer;
  dcache_rdata          = next_line_buffer;

  next_prefetch_req         = prefetch_req;
  next_prefetch_ready       = prefetch_ready;
  next_prefetch_line_buffer = prefetch_line_buffer;
  next_prefetch_iaddress    = prefetch_iaddress;
  next_prefetch_hit         = prefetch_hit;

  /* Cache Request Logic */
  icache_req        = icache_read | icache_write;
  dcache_req        = dcache_read | dcache_write;

  unique case (curr_state)
    LINE_IDLE: begin
      /* Arbitrate Request, arbiter = 1 is icache */
      if (icache_req & (arbiter | ~dcache_req)) begin
        /* Check prefetch buffer for a match*/
        if (prefetch_ready && (icache_addr[31:5] == prefetch_iaddress[31:5])) begin
          /* Buffer will no longer be ready next cycle */
          next_prefetch_ready = 1'b0;
          
          /* Indicate a prefetch hit */
          next_prefetch_hit = 1'b1;

          /* Set arbiter state correctly */
          if (~arbiter) begin
            next_arbiter = 1'b1;
          end

          /* Go to return state */
          next_state        = DESERIALIZE_DONE;
        end else begin
          /* Assert prefetch request + address */
          next_prefetch_req = 1'b1;
          next_prefetch_iaddress = {icache_addr[31:5] + 1'b1, 5'b0};

          /* Buffer will no longer be ready next cycle */
          next_prefetch_ready = 1'b0;

          /* Set arbiter state correctly */
          if (~arbiter) begin
            next_arbiter = 1'b1;
          end
          /* Process request */
          bmem_addr  = icache_addr;
          if (icache_write) begin
            bmem_wdata        = icache_wdata[63:0];
            bmem_write        = icache_write;
            next_serdes_count = 2'b1;
            next_state        = SERIALIZE;
          end
          else begin
            bmem_read  = icache_read;
            next_state = WAIT;
          end
        end
      end
      else if (dcache_req & (~arbiter | ~icache_req)) begin
        /* Set arbiter state correctly */
        if (arbiter) begin
          next_arbiter = 1'b0;
        end
        /* Process request */
        bmem_addr = dcache_addr;
        if (dcache_write) begin
          bmem_write        = dcache_write;
          bmem_wdata        = dcache_wdata[63:0];
          next_serdes_count = 2'b1;
          next_state        = SERIALIZE;
        end
        else begin
          bmem_read  = dcache_read;
          next_state = WAIT;
        end
      end
      else if (prefetch_req) begin
        /* Process request */
        bmem_addr  = prefetch_iaddress;
        bmem_read  = 1'b1;
        next_state = WAIT;

        /* Set arbiter state correctly */
        if (~arbiter) begin
          next_arbiter = 1'b1;
        end

        /* Indicate we are in a prefetch cycle */
        next_prefetch_ready = 1'b1;
      end
    end
    SERIALIZE: begin
      /* Only do a new thing if bmem is ready */
      bmem_write = 1'b1;
      if (arbiter) begin
        bmem_wdata = icache_wdata[(serdes_count*64)+:64];
        bmem_addr  = icache_addr;
      end
      else begin
        bmem_wdata = dcache_wdata[(serdes_count*64)+:64];
        bmem_addr  = dcache_addr;
      end

      if (bmem_ready) begin
        if (serdes_count == 2'b11) begin
          /* Tell cache that memory is ready */
          if (arbiter)
            icache_resp = 1'b1;
          else
            dcache_resp = 1'b1;

          /* Change arbiter state after done with request */
          next_arbiter = ~arbiter;

          /* Reset to IDLE */
          next_serdes_count = '0;
          next_state = LINE_IDLE;
        end
        else begin
          next_serdes_count = serdes_count + 1'b1;
        end
      end
    end
    WAIT: begin
      if (bmem_rvalid) begin
        /* Service prefetch buffer */
        if (arbiter && prefetch_ready) begin
          next_prefetch_line_buffer[63:0] = bmem_rdata;
        end 
        /* Service regular buffer */
        else begin
          next_line_buffer[63:0] = bmem_rdata;
        end

        next_state        = DESERIALIZE;
        next_serdes_count = 2'b1;
      end
    end
    DESERIALIZE: begin
      /* Service prefetch buffer */
      if (arbiter && prefetch_ready) begin
        next_prefetch_line_buffer[(serdes_count*64)+:64] = bmem_rdata;
      end 
      /* Service regular buffer */
      else begin
        next_line_buffer[(serdes_count*64)+:64] = bmem_rdata;
      end

      if (serdes_count == 2'b11) begin
        /* To DONE State */
        next_serdes_count = '0;
        next_state        = DESERIALIZE_DONE;
      end
      else begin
        next_serdes_count = serdes_count + 1'b1;
      end
    end
    DESERIALIZE_DONE: begin
      /* Tell cache that memory is ready */
      if (arbiter) begin
        /* Indicate prefetcher has finished it's fetch */
        if (prefetch_ready && !prefetch_hit) begin
          next_prefetch_req = 1'b0;
        end else begin
          /* Speculatively fetch next line on a hit */
          if (prefetch_hit) begin
            next_prefetch_req = 1'b1;
            next_prefetch_iaddress = {prefetch_iaddress[31:5] + 1'b1, 5'b0};

            /* Buffer will no longer be ready next cycle */
            next_prefetch_ready = 1'b0;
          end

          icache_resp = 1'b1;
        end
      end else begin
        dcache_resp = 1'b1;
      end

      /* Reset prefetch hit signal */
      if (prefetch_hit) begin
        next_prefetch_hit = 1'b0;
      end

      /* Change arbiter state after done with request */
      next_arbiter = ~arbiter;

      next_state = LINE_IDLE;
    end
    default: begin end
  endcase
end

/* Prefetcher Metrics */
integer prefetch_hits;
integer prefetch_misses;
integer num_icache_wait_cycles;
integer num_dcache_wait_cycles;
logic prefetch_req_dff;

logic prefetch_miss_signal;
assign prefetch_miss_signal = ((curr_state == LINE_IDLE) && (icache_req && (arbiter | ~dcache_req)) && prefetch_ready) && (icache_addr[31:5] != prefetch_iaddress[31:5]);

always_ff @ (posedge clk) begin
  if (rst) begin
    prefetch_hits          <= 0;
    prefetch_misses        <= 0;
    num_icache_wait_cycles <= 0;
    num_dcache_wait_cycles <= 0;
    prefetch_req_dff       <= '0;
  end
  else begin
    prefetch_req_dff <= prefetch_req;

    if (prefetch_hit) begin
      prefetch_hits <= prefetch_hits + 1;
    end

    /* Prefetch misses if there is a rising edge on the request line */
    if (prefetch_miss_signal) begin
      prefetch_misses <= prefetch_misses + 1;
    end

    /* Track number of cycles waiting for incoming imem request */
    if (icache_req) begin
      num_icache_wait_cycles <= num_icache_wait_cycles + 1;
    end
    /* Track number of cycles waiting for incoming dmem request */
    else if (dcache_req) begin
      num_dcache_wait_cycles <= num_dcache_wait_cycles + 1;
    end
  end
end

endmodule
