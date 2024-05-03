typedef uvm_sequencer #(generic_item) generic_sequencer;

class specific_sequence extends uvm_sequence #(generic_item);
  `uvm_object_utils(specific_sequence)

  function new(string name = "");
    super.new(name);
  endfunction : new

  task body;
    generic_item blueprint, generic_itm;
    blueprint = new();

    repeat(`NUM_TESTS) begin
      // Send Randomized Transaction to Sequencer
      blueprint.txn.randomize();
      generic_itm = blueprint;
      start_item(generic_itm);
      finish_item(generic_itm);
    end
  endtask : body
endclass : specific_sequence

class specific_driver extends uvm_driver #(generic_item);
  `uvm_component_utils(specific_driver)

  // Custom DUT Interface
  virtual frontend_itf frontend_if;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("SPECIFIC_DRIVER", "Created SPECIFIC_DRIVER!", UVM_MEDIUM)
    // Assign Interface Handle from Configuration Database
    if (!uvm_config_db #(virtual frontend_itf)::get(this, "", "frontend_itf", frontend_if)) begin
      `uvm_fatal("SPECIFIC_DRIVER", "DUT Interface not defined! Simulation aborted!");
    end
  endfunction : build_phase

  // Drive DUT Specific Reset Stimulus
  task do_reset();
    @(frontend_if.drv_cb);
    frontend_if.drv_cb.rst <= 1'b0;
    @(frontend_if.drv_cb);
    frontend_if.drv_cb.rst <= 1'b1;
    @(frontend_if.drv_cb);
    frontend_if.drv_cb.rst <= 1'b0;
  endtask

  task run_phase(uvm_phase phase);
    // Handles
    generic_item generic_itm;
    specific_txn txn;

    // Drive Reset Signal to DUT
    do_reset();

    forever begin
      // Get Randomized Transaction from Sequencer
      seq_item_port.get_next_item(generic_itm);
      txn = generic_itm.txn;

      // Drive DUT Signals
      @(frontend_if.drv_cb);
      frontend_if.drv_cb.stall <= txn.stall;
      frontend_if.drv_cb.imem_resp <= txn.imem_resp;
      frontend_if.drv_cb.br_jump <= txn.br_jump;
      frontend_if.drv_cb.br_jump_addr <= txn.br_jump_addr;

      // Finish Driving Signals
      seq_item_port.item_done();
    end
  endtask : run_phase 
endclass : specific_driver

class specific_monitor extends uvm_monitor;
  `uvm_component_utils(specific_monitor)

  // Custom DUT Interface
  virtual frontend_itf frontend_if;

  // Analysis Port
  uvm_analysis_port #(generic_item) aport;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    aport = new("aport", this);
    `uvm_info("SPECIFIC_MONITOR", "Created SPECIFIC_MONITOR!", UVM_MEDIUM)
    // Assign Interface Handle from Configuration Database
    if (!uvm_config_db #(virtual frontend_itf)::get(this, "", "frontend_itf", frontend_if)) begin
      `uvm_fatal("SPECIFIC_MONITOR", "DUT Interface not defined! Simulation aborted!");
    end
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    // Handles
    specific_txn txn;
    generic_item generic_itm;

    // Wait for initial reset signal
    @(frontend_if.mon_cb iff frontend_if.mon_cb.rst);
    generic_itm = new(); // Write reset transaction to match dut
    generic_itm.txn.clk = frontend_if.mon_cb.clk;
    generic_itm.txn.rst = frontend_if.mon_cb.rst;
    generic_itm.txn.stall = frontend_if.mon_cb.stall;
    generic_itm.txn.imem_resp = frontend_if.mon_cb.imem_resp;
    generic_itm.txn.br_jump = frontend_if.mon_cb.br_jump;
    generic_itm.txn.br_jump_addr = frontend_if.mon_cb.br_jump_addr;
    generic_itm.txn.instr_valid = frontend_if.mon_cb.instr_valid;
    generic_itm.txn.imem_addr = frontend_if.mon_cb.imem_addr;
    generic_itm.txn.imem_rmask = frontend_if.mon_cb.imem_rmask;
    aport.write(generic_itm); // Write reset transaction to match dut
    @(frontend_if.mon_cb); // Wait for Driver to finish reset and start sending transactions,
    // Max will fix this using system verilog events, 
    // he sucks at coding so the issue popped up sooner rather than later.

    forever begin
      generic_itm = new();
      txn = generic_itm.txn;

      // Monitor DUT Signals
      @(frontend_if.mon_cb);
      txn.clk = frontend_if.mon_cb.clk;
      txn.rst = frontend_if.mon_cb.rst;
      txn.stall = frontend_if.mon_cb.stall;
      txn.imem_resp = frontend_if.mon_cb.imem_resp;
      txn.br_jump = frontend_if.mon_cb.br_jump;
      txn.br_jump_addr = frontend_if.mon_cb.br_jump_addr;
      txn.instr_valid = frontend_if.mon_cb.instr_valid;
      txn.imem_addr = frontend_if.mon_cb.imem_addr;
      txn.imem_rmask = frontend_if.mon_cb.imem_rmask;

      // Send Complete Transaction to Analysis Port
      aport.write(generic_itm);
    end
  endtask : run_phase
endclass : specific_monitor

class generic_agent extends uvm_agent;
  `uvm_component_utils(generic_agent)

  // Analysis port
  uvm_analysis_port #(generic_item) aport;

  generic_sequencer sequencer;
  specific_driver driver;
  specific_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    aport = new("aport", this);
    sequencer = generic_sequencer::type_id::create("sequencer", this);
    driver = specific_driver::type_id::create("driver", this);
    monitor = specific_monitor::type_id::create("monitor", this);
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect Analysis Port to Monitor
    monitor.aport.connect(aport);
    // Connect Driver and Sequencer
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction : connect_phase
endclass : generic_agent
