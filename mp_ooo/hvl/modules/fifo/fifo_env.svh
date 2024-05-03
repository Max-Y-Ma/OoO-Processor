class specific_coverage extends uvm_subscriber #(generic_item);
  `uvm_component_utils(specific_coverage)

  // Analysis Port
  uvm_analysis_port #(generic_item) aport;

  // Custom Covergroup
  covergroup fifo_cg with function sample(specific_txn txn);
    // At Least 1 Read and 1 Write
    fifo_read : coverpoint txn.read_write[1] {
      bins read = {1};
    }
    
    fifo_write : coverpoint txn.read_write[0] {
      bins write = {1};
    }
    
    // The FIFO has been full
    fifo_full : coverpoint txn.full {
      bins full = {1};
    }

    // The FIFO has been empty
    fifo_empty : coverpoint txn.empty {
      bins empty = {1};
    }
  endgroup : fifo_cg

  function new(string name, uvm_component parent);
    super.new(name, parent);
    fifo_cg = new();
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    aport = new("aport", this);
  endfunction : build_phase

  // Sample data
  virtual function void write(generic_item t);
    fifo_cg.sample(t.txn);
  endfunction : write

endclass : specific_coverage

class specific_scoreboard extends uvm_subscriber #(generic_item);
  `uvm_component_utils(specific_scoreboard)

  // Analysis Port
  uvm_analysis_port #(generic_item) aport;

  // Create Golden Reference Model
  fifo_golden golden;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    golden = new();
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    aport = new("aport", this);
  endfunction : build_phase

  // Check Incoming Transaction with Golden Model
  function void write(generic_item t);
    golden.check(t.txn);
  endfunction : write

endclass : specific_scoreboard

class generic_env extends uvm_env;
  `uvm_component_utils(generic_env)

  generic_agent agent;
  specific_coverage coverage;
  specific_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = generic_agent::type_id::create("agent", this);
    coverage = specific_coverage::type_id::create("coverage", this);
    scoreboard = specific_scoreboard::type_id::create("scoreboard", this);
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.aport.connect(coverage.analysis_export);
    agent.aport.connect(scoreboard.analysis_export);
  endfunction : connect_phase

endclass : generic_env