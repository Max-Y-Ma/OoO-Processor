//-----------------------------------------------------------------------------
// Title         : random_tb
// Project       : ECE 411 mp_verif
//-----------------------------------------------------------------------------
// File          : random_tb.sv
// Author        : ECE 411 Course Staff
//-----------------------------------------------------------------------------
// IMPORTANT: If you don't change the random seed, every time you do a `make run`
// you will run the /same/ random test. SystemVerilog calls this "random stability",
// and it's to ensure you can reproduce errors as you try to fix the DUT. Make sure
// to change the random seed or run more instructions if you want more extensive
// coverage.
//------------------------------------------------------------------------------
module random_magic_tb
import rv32i_types::*;
(
  mem_itf.mem itf_i,
  mem_itf.mem itf_d
);

  localparam NUM_CYCLES = 50000000;

  `include "../../hvl/random_top/randinst.svh"
  //`include "../../hvl/randdmem.svh"

  RandInst gen = new();
  //randdmem rand_dmem = new();
  

  // Do a bunch of LUIs to get useful register state.
  task init_register_state();
    for (int i = 0; i < 32; ++i) begin
      //@(posedge itf_i.clk iff itf_i.rmask);
      gen.randomize() with {
        instr.j_type.opcode == op_lui;
        instr.j_type.rd == i[4:0];
      };

      // Your code here: package these memory interactions into a task.
      itf_i.rdata <= gen.instr.word;
      itf_i.resp <= 1'b1;
      @(posedge itf_i.clk iff itf_i.rmask);
      //@(posedge itf_i.clk) itf_i.resp <= 1'b0;
    end
  endtask : init_register_state

      logic [4:0] ii;
      logic [4:0] iii;
  // Note that this memory model is not consistent! It ignores
  // writes and always reads out a random, valid instruction.
  task run_random_instrs();

    repeat (NUM_CYCLES) begin
      @(posedge itf_i.clk iff (itf_i.rmask));

      gen.randomize();
      itf_d.resp <= 1'b1;

      if (itf_d.rmask) begin
        itf_d.rdata <= gen.rand_load_access;
      end
      //if (itf_i.read && itf_i.write) begin
      //  $error("Simultaneous read and write to memory model!");
      //end
      

      //gen.randomize();
      //for (ii=5'd0;ii<gen.rand_imem_delay;ii = ii+1'b1) begin
      //  @(posedge itf_i.clk);
      //end
      //@(posedge itf_i.clk) 
  
      // Always read out a valid instruction.
      if (itf_i.rmask) begin
        //gen.randomize();
        itf_i.rdata <= gen.instr.word;
      end
      //if (itf_d.rmask) begin
      //  itf_d.rdata <= gen.rand_load_access;
      //end
      //if (itf_d.wmask) begin
       // itf_d.resp <= 1'b1;
      //end


      // If it's a write, do nothing and just respond.

      itf_i.resp <= 1'b1;
      //@(posedge itf_i.clk) itf_i.resp <= 1'b0;
    end
  endtask : run_random_instrs
  
  logic was_read;

  //task random_dmem();
  //  repeat (NUM_CYCLES) begin
  //    @(posedge itf_d.clk iff (itf_d.rmask || itf_d.wmask));

  //    rand_dmem.randomize();
  //    if (itf_d.rmask) begin
  //      was_read = 1'b1;
  //    end else begin
  //      was_read = 1'b0;
  //    end


  //    for (iii=5'd0;iii<rand_dmem.rand_dmem_delay;iii=iii+1'b1) begin
  //      @(posedge itf_d.clk);
  //    end

  //    if (was_read) itf_d.rdata <= rand_dmem.rand_load_access;
  //    else itf_d.rdata <= 'x;
  //    itf_d.resp <= 1'b1;
  //    @(posedge itf_d.clk) itf_d.resp <= 1'b0;
  //  end
  //endtask : random_dmem

  // A single initial block ensures random stability.
  initial begin

    // Wait for reset.
    @(posedge itf_i.clk iff itf_i.rst == 1'b0);

    // Get some useful state into the processor by loading in a bunch of state.
    init_register_state();

    // Run!
    //fork
    //begin
      run_random_instrs();
    //end
    //begin
      //random_dmem();
    //end
    //join_any
    // Finish up
    $display("Random testbench finished!");
    $finish;
  end

endmodule : random_magic_tb
