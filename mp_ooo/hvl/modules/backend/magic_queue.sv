module magic_queue 
import backend_types::*;
# (
  parameter MEMFILE = "memory.lst",
  parameter RESET_VEC = 'h60000000,
  parameter DEPTH = 32
) (
  input  logic    clk,
  input  logic    rst,
  input  logic    wen,
  input  logic    ren,
  input  iqueue_t wdata,
  output iqueue_t rdata,
  output logic    full,
  output logic    empty
);

  logic [31:0] internal_memory_array [logic [31:2]];
  logic [31:2] address = '0;

  // Load program into memory with the first address
  always_ff @(posedge clk iff rst) begin
    internal_memory_array.delete();
    $readmemh(MEMFILE, internal_memory_array);
    internal_memory_array.first(address);
  end

  // Enqueue new instruction on every clock cycle
  iqueue_t internal_queue [$:DEPTH];
  always_ff @(posedge clk) begin
    if (address != '0) begin
      internal_queue.push_back({{address, 2'b00}, internal_memory_array[address]});
      internal_memory_array.next(address);
    end
  end

  // Handle queue requests
  always_ff @(posedge clk) begin
    full <= (internal_queue.size() == DEPTH);
    empty <= (internal_queue.size() == '0);
    
    if (rst) begin
      internal_queue.delete();
    end else begin
      if (wen && ~full) begin
        internal_queue.push_back(wdata);
      end
      if (ren && ~empty) begin
        internal_queue.pop_front();
      end
    end
  end

  // Model Combination Read
  always_ff @(posedge clk) begin
    rdata <= internal_queue[0];
  end

endmodule : magic_queue