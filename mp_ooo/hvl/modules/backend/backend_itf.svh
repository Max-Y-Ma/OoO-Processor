interface backend_itf (input bit clk);
  import backend_types::*;

  logic rst, full;
  logic iqueue_ren;
  logic iqueue_empty;
  iqueue_t iqueue_rdata;

  clocking cb @(posedge clk);
    input iqueue_ren;
    output rst, iqueue_empty, iqueue_rdata;
  endclocking : cb
  
endinterface : backend_itf