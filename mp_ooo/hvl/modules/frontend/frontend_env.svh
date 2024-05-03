class specific_coverage extends uvm_subscriber #(generic_item);
  `uvm_component_utils(specific_coverage)

  // Analysis Port
  uvm_analysis_port #(generic_item) aport;

  // Custom Covergroup
  covergroup frontend_cg with function sample(specific_txn txn);
    // At Least 1 branch
    frontend_branch : coverpoint txn.br_jump {
      bins branch = {1};
    }

    // At Least 1 stall
    frontend_stall : coverpoint txn.stall {
      bins stall = {1};
    }
    
    // At least 1 invalid instruction
    frontend_invalid: coverpoint txn.instr_valid {
      bins invalid = {0};
    }

  endgroup : frontend_cg

  function new(string name, uvm_component parent);
    super.new(name, parent);
    frontend_cg = new();
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    aport = new("aport", this);
  endfunction : build_phase

  // Sample data
  virtual function void write(generic_item t);
    frontend_cg.sample(t.txn);
  endfunction : write

endclass : specific_coverage

class specific_scoreboard extends uvm_subscriber #(generic_item);
  `uvm_component_utils(specific_scoreboard)

  // Analysis Port
  uvm_analysis_port #(generic_item) aport;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    aport = new("aport", this);
  endfunction : build_phase

  // Check Incoming Transaction with Golden Model
  logic [31:0] pc;
  logic [3:0] imem_rmask;
  logic instr_valid;

  function void write(generic_item t);
    specific_txn txn = t.txn;

    `uvm_info("SCOREBOARD", $sformatf("Imem Addr %0d", txn.imem_addr), UVM_MEDIUM)
  
    imem_rmask = 4'b1111;

    if (txn.rst) begin
      pc = 32'h60000000;
      instr_valid = 0;
    end else if (txn.br_jump) begin
      pc = txn.br_jump_addr;
      instr_valid = 0;
    end else if (~txn.stall & txn.imem_resp) begin
      pc = pc + 4;
      instr_valid = 1;
    end else begin
      instr_valid = 1;
    end

    // Assertion Checker
    assert_imem_addr : assert(pc == txn.imem_addr)
    else $fatal("[ASSERTION ERROR] Incorrect imem_addr! pc = %0d, imem_addr = %0d",pc, txn.imem_addr);

    assert_valid : assert(instr_valid == txn.instr_valid)
    else $fatal("[ASSERTION ERROR] Incorrect Valid Bit! golden_valid = %0d, instr_valid = %0d", instr_valid, txn.instr_valid);

    assert_rmask : assert(imem_rmask == txn.imem_rmask)
    else $fatal("[ASSERTION ERROR] Incorrect rmask! golden_rmask = %0d, imem_rmask = %0d", imem_rmask, txn.imem_rmask);

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
