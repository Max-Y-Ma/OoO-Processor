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
  virtual fifo_itf #(.DTYPE(fifo_type_t)) fifo_if;
  uvm_event event_reset;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("SPECIFIC_DRIVER", "Created SPECIFIC_DRIVER!", UVM_MEDIUM)
    // Get Reset Event Handle
    if (!uvm_config_db #(uvm_event)::get(this, "", "event_reset", event_reset)) begin
      `uvm_fatal("SPECIFIC_DRIVER", "Reset Event not defined! Simulation aborted!");
    end
    // Assign Interface Handle from Configuration Database
    if (!uvm_config_db #(virtual fifo_itf #(.DTYPE(fifo_type_t)))::get(this, "", "fifo_itf", fifo_if)) begin
      `uvm_fatal("SPECIFIC_DRIVER", "DUT Interface not defined! Simulation aborted!");
    end
  endfunction : build_phase

  // Drive DUT Specific Reset Stimulus
  task do_reset();
    @(fifo_if.drv_cb);
    fifo_if.drv_cb.rst <= 1'b0;
    @(fifo_if.drv_cb);
    fifo_if.drv_cb.rst <= 1'b1;
    @(fifo_if.drv_cb);
    fifo_if.drv_cb.rst <= 1'b0;
    event_reset.trigger();
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
      @(fifo_if.drv_cb);
      fifo_if.drv_cb.ren <= txn.read_write[1];
      fifo_if.drv_cb.wen <= txn.read_write[0];
      fifo_if.drv_cb.wdata <= txn.wdata;

      // Finish Driving Signals
      seq_item_port.item_done();
    end
  endtask : run_phase 
endclass : specific_driver

class specific_monitor extends uvm_monitor;
  `uvm_component_utils(specific_monitor)

  // Custom DUT Interface
  virtual fifo_itf #(.DTYPE(fifo_type_t)) fifo_if;
  uvm_event event_reset;

  // Analysis Port
  uvm_analysis_port #(generic_item) aport;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    aport = new("aport", this);
    `uvm_info("SPECIFIC_MONITOR", "Created SPECIFIC_MONITOR!", UVM_MEDIUM)
    // Get Reset Event Handle
    if (!uvm_config_db #(uvm_event)::get(this, "", "event_reset", event_reset)) begin
      `uvm_fatal("SPECIFIC_DRIVER", "Reset Event not defined! Simulation aborted!");
    end
    // Assign Interface Handle from Configuration Database
    if (!uvm_config_db #(virtual fifo_itf #(.DTYPE(fifo_type_t)))::get(this, "", "fifo_itf", fifo_if)) begin
      `uvm_fatal("SPECIFIC_MONITOR", "DUT Interface not defined! Simulation aborted!");
    end
  endfunction : build_phase

  function sample(generic_item generic_itm);
    generic_itm.txn.clk = fifo_if.mon_cb.clk;
    generic_itm.txn.rst = fifo_if.mon_cb.rst;
    generic_itm.txn.read_write = {fifo_if.mon_cb.ren, fifo_if.mon_cb.wen};
    generic_itm.txn.wdata = fifo_if.mon_cb.wdata;
    generic_itm.txn.full = fifo_if.mon_cb.full;
    generic_itm.txn.empty = fifo_if.mon_cb.empty;
    generic_itm.txn.rdata = fifo_if.mon_cb.rdata;

    // Send Complete Transaction to Analysis Port
    aport.write(generic_itm);
  endfunction : sample

  task run_phase(uvm_phase phase);
    // Handles
    generic_item generic_itm = new();

    // Wait for initial reset signal
    event_reset.wait_trigger();
    sample(generic_itm);

    forever begin
      // Monitor DUT Signals
      @(fifo_if.mon_cb);
      sample(generic_itm);
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