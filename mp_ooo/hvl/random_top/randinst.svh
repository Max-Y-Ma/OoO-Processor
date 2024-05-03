// This class generates random valid RISC-V instructions to test your
// RISC-V cores.

class RandInst;
  // You will increment this number as you generate more random instruction
  // types. Once finished, NUM_TYPES should be 9, for each opcode type in
  // rv32i_opcode.
  localparam NUM_TYPES = 8;

  // You'll need this type to randomly generate variants of certain
  // instructions that have the funct7 field.
  typedef enum bit [6:0] {
    base         = 7'b0000000,
    variant      = 7'b0100000,
    mult_variant = 7'b0000001
  } funct7_t;

  // Various ways RISC-V instruction words can be interpreted.
  // See page 104, Chapter 19 RV32/64G Instruction Set Listings
  // of the RISC-V v2.2 spec.
  typedef union packed {
    bit [31:0] word;

    struct packed {
      bit [11:0] i_imm;
      bit [4:0] rs1;
      bit [2:0] funct3;
      bit [4:0] rd;
      rv32i_op_t opcode;
    } i_type;

    struct packed {
      bit [6:0] funct7;
      bit [4:0] rs2;
      bit [4:0] rs1;
      bit [2:0] funct3;
      bit [4:0] rd;
      rv32i_op_t opcode;
    } r_type;

    struct packed {
      bit [11:5] imm_s_top;
      bit [4:0]  rs2;
      bit [4:0]  rs1;
      bit [2:0]  funct3;
      bit [4:0]  imm_s_bot;
      rv32i_op_t opcode;
    } s_type;

    struct packed {
      bit [11:5] imm_b_top;
      bit [4:0]  rs2;
      bit [4:0]  rs1;
      bit [2:0]  funct3;
      bit [4:0]  imm_b_bot;
      rv32i_op_t opcode;
    } b_type;

    struct packed {
      bit [31:12] imm;
      bit [4:0]  rd;
      rv32i_op_t opcode;
    } j_type;

  } instr_t;

  rand instr_t instr;
  rand bit [NUM_TYPES-1:0] instr_type;
  rand bit [2:0] rand_funct3;
  rand bit [6:0] rand_funct7;

  rand bit [31:0] rand_load_access;

  rand bit [4:0] rand_imem_delay;
  //rand bit [4:0] rand_dmem_delay;

  //constraint rand_imem_delay_t { rand_imem_delay inside {5'd0, 5'd1}; }

  constraint rand_load_access_t { rand_load_access[1:0] == 2'b00; rand_load_access[9:8] == 2'b00; rand_load_access[17:16] == 2'b00; rand_load_access[25:24] == 2'b00; }

  // Make sure we have an even distribution of instruction types.
   constraint solve_order_c { solve instr_type before instr; }

  // Hint/TODO: you will need another solve_order constraint for funct3
  // to get 100% coverage with 500 calls to .randomize().
  constraint solve_order_funct3_c { solve rand_funct3 before rand_funct7; }

  // Pick one of the instruction types.
  constraint instr_type_c {
    $countones(instr_type) == 1; // Ensures one-hot.
  }

  // Constraints for actually generating instructions, given the type.
  // Again, see the instruction set listings to see the valid set of
  // instructions, and constrain to meet it. Refer to ../pkg/types.sv
  // to see the typedef enums.

  constraint instr_c {
    // Reg-imm instructions
    instr_type[0] -> {
      instr.i_type.opcode == op_imm;

      // Implies syntax: if funct3 is sr, then funct7 must be
      // one of two possibilities.
      instr.r_type.funct3 == sri -> {
        instr.r_type.funct7 inside {base, variant};
      }

      // This if syntax is equivalent to the implies syntax above
      // but also supports an else { ... } clause.
      if (instr.r_type.funct3 == slli) {
        instr.r_type.funct7 == base;
      }
    }

    // Reg-reg instructions
    instr_type[1] -> {
      instr.i_type.opcode == op_reg;
      instr.r_type.funct3 inside {addr, sllr, sltr, sltru, xorr, srr, orr, andr};

      // Adjust Funct7 for M and I extension variants
      if (instr.r_type.funct3 inside {addr} ) {
        instr.r_type.funct7 inside {base, variant, mult_variant};
      } else if (instr.r_type.funct3 inside {sllr, sltr, sltru}) {
        instr.r_type.funct7 inside {base, mult_variant};
      } else {
        instr.r_type.funct7 == base;
      }
    }

    // LUI instruction
    instr_type[2] -> {
      instr.j_type.opcode == op_lui;
    }

    // AUIPC instruction
    instr_type[3] -> {
      instr.j_type.opcode == op_auipc;
    }

    // Branch instructions
    instr_type[4] -> {
      instr.j_type.opcode == op_jal;
      instr.j_type.imm == 20'd8;
      instr.j_type.imm[21] == 1'b0;
    }
    
    //instr_type[5] -> {
    // instr.i_type.opcode == op_jalr;
      // instr.i_type.funct3 == 3'b000;
      // instr.i_type.i_imm[1:0] == 2'b00;
      // instr.i_type.i_imm != '0;
      //instr.i_type.i_imm[2] == 1'b1;
      //instr.i_type.rs1 == 5'b00000;
    // }
    
    instr_type[5] -> {
      instr.b_type.opcode == op_br;
      instr.b_type.funct3 inside {beq, bne, blt, bge, bltu, bgeu};
      instr.b_type.imm_b_bot == 5'd8;
      instr.b_type.imm_b_top == '0;
      // instr.b_type.imm_b_bot != '0;
      // instr.b_type.imm_b_bot[1:0] == 2'b00;
    }

    // Store instructions -- these are easy to constrain!
    instr_type[6] -> {
      instr.s_type.opcode == op_store;
      instr.s_type.funct3 inside {sw, sb, sh};

      // Constraint rs1 equal to x0
      instr.s_type.rs1 == '0;

      // Constraint immediate to 2-byte or 4-byte alignment
      (instr.s_type.funct3 == sw) -> {
        instr.s_type.imm_s_bot[1:0] == 2'b00;
      }

      (instr.s_type.funct3 == sh) -> {
        instr.s_type.imm_s_bot[1:0] inside {2'b00, 2'b10};
      }
    }
    
    // Load instructions
    instr_type[7] -> {
      instr.i_type.opcode == op_load;
      instr.i_type.funct3 inside {lb, lh, lw, lbu, lhu};

      // Constraint rs1 equal to x0
      instr.i_type.rs1 == '0;

      // Constraint immediate to 2-byte or 4-byte alignment
      (instr.i_type.funct3 == lw) -> {
        instr.i_type.i_imm[1:0] == 2'b00;
      }

      (instr.i_type.funct3 == lh || instr.i_type.funct3 == lhu) -> {
        instr.i_type.i_imm[1:0] inside {2'b00, 2'b10};
      }
    }
  }

  `include "../../hvl/random_top/instr_cg.svh"

  // Constructor, make sure we construct the covergroup.
  function new();
    instr_cg = new();
  endfunction : new

  // Whenever randomize() is called, sample the covergroup. This assumes
  // that every time you generate a random instruction, you send it into
  // the CPU.
  function void post_randomize();
    instr_cg.sample(this.instr);
  endfunction : post_randomize

  // A nice part of writing constraints is that we get constraint checking
  // for free -- this function will check if a bit vector is a valid RISC-V
  // instruction (assuming you have written all the relevant constraints).
  function bit verify_valid_instr(instr_t inp);
    bit valid = 1'b0;
    this.instr = inp;
    for (int i = 0; i < NUM_TYPES; ++i) begin
      this.instr_type = 1 << i;
      if (this.randomize(null)) begin
        valid = 1'b1;
        break;
      end
    end
    return valid;
  endfunction : verify_valid_instr
endclass : RandInst
