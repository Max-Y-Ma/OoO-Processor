class frontend_test extends uvm_test;
  `uvm_component_utils(frontend_test)

  generic_env env;
  specific_sequence seq;

  function new(string name, uvm_component parent);
      super.new(name, parent);
  endfunction : new

  // Build Components and Setup Config Database
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = generic_env::type_id::create("env", this);
    seq = specific_sequence::type_id::create("seq", this);
  endfunction : build_phase

  // Start Sequence
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("FRONTEND_TEST", "Running FRONTEND_TEST!", UVM_MEDIUM)
    seq.start(env.agent.sequencer);
    phase.drop_objection(this);
    `uvm_info("FRONTEND_TEST", "FRONTEND_TEST Successful!", UVM_MEDIUM)
  endtask : run_phase

endclass : frontend_test
