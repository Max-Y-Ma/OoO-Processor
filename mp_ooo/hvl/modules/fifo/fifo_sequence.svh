class specific_txn #(type DTYPE = fifo_type_t);
  /* Define Constrained Random Data */

  // Bit Vector to Indicate Reads or Writes, Respectively 
  rand bit[1:0] read_write;

  // Random Write Data of Parameterizable Type
  rand DTYPE wdata;

  // Reads and Writes are Mutually Exclusive
  constraint read_or_write {
    $countones(read_write) == 1;
  }

  /* Define Common Transaction Data */
  logic clk, rst, full, empty;
  DTYPE rdata;

  /* Define Common Transaction Functions */
  function bit do_compare(specific_txn rhs);
    return ((read_write == rhs.read_write) && (wdata == rhs.wdata));
  endfunction : do_compare

  function string convert2string();
    return $sformatf("read_write = %0d, wdata = %0d, rst = %0d, full = %0d, empty = %0d, rdata = %0d", read_write, wdata, rst, full, empty, rdata);
  endfunction : convert2string

endclass : specific_txn

class generic_item extends uvm_sequence_item;
  `uvm_object_utils(generic_item)

  specific_txn txn;

  function new(string name = "");
    super.new(name);
    txn = new();
  endfunction : new

  virtual function void do_copy(uvm_object rhs);
    generic_item RHS;
    if (!$cast(RHS, rhs)) begin
      uvm_report_error("do_copy:", "Cast Failed");
      return;
    end
    super.do_copy(rhs);
    txn = RHS.txn;
  endfunction : do_copy

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    generic_item RHS;
    if (!$cast(RHS, rhs)) begin
      uvm_report_error("do_compare:", "Cast Failed");
      return 0;
    end
    return (super.do_compare(rhs, comparer) && (txn.do_compare(RHS.txn)));
  endfunction : do_compare

  virtual function string convert2string();
    string s;
    s = {super.convert2string(), txn.convert2string()};
    return s;
  endfunction : convert2string

endclass : generic_item
