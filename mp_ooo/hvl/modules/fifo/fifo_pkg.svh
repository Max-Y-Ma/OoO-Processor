// Top UVM Test Package
`include "fifo_config.svh"

package fifo_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef struct packed {
    logic [31:0] a, b;
  } fifo_type_t;

  `include "fifo_sequence.svh"
  `include "fifo_golden.svh"
  `include "fifo_agent.svh"
  `include "fifo_env.svh"
  `include "fifo_test.svh"
endpackage : fifo_pkg