class specific_txn;
  /* Define Constrained Random Data */

  //Random stall weighted towards no stall
  rand bit stall;
  constraint stall_weight {
    stall dist {0 := 99, 1 := 1};
  }

  //Random branch and addr weighted for empirical branch data
  rand bit br_jump;
  rand bit[31:0] br_jump_addr;
  constraint br_jump_weight {
    br_jump dist {0 := 5, 1 := 1};
  }
  constraint br_jump_addr_align {
    br_jump_addr[1:0] == 2'b00;
  }

  rand bit imem_resp;
  constraint imem_resp_high {
    imem_resp == 1'b1;
  };

  /* Define Common Transaction Data */
  logic clk, rst, stall, instr_valid;

  logic [31:0] imem_addr;
  logic [3:0] imem_rmask;

  /* Define Common Transaction Functions */
  function bit do_compare(specific_txn rhs);
    return 1'b0; //compare func not written
  endfunction : do_compare

  function string convert2string();
    return $sformatf("br_jump = %0d, br_jump_addr = %0d, rst = %0d, stall = %0d, imem_resp = %0d, instr_valid = %0d, imem_addr = %0d, imem_rmask = %0d", br_jump, br_jump_addr, rst, stall, imem_resp, instr_valid, imem_addr, imem_rmask);
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
