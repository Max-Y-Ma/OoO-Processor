/**
 * Module: decoder
 * File  : decoder.sv
 * Author: Max Ma
 * Date  : March 19, 2024
 *
 * Description:
 * ------------
 * Common instruction decoder to support RV32IM instructions without division 
*/
module decoder
import rv32i_types::*;
import backend_types::*;
(
  // Datapath Signals
  input logic        instr_valid,
  input logic [31:0] inst,

  // Export Control Signals
  output ctrl_sig_t ctrl,
  output metadata_t meta
);

  // Instruction Decode
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] rs1_addr;
  logic [4:0] rs2_addr;
  logic [4:0] rd_addr;
  assign opcode   = inst[6:0];
  assign funct3   = inst[14:12];
  assign funct7   = inst[31:25];
  assign rs1_addr = inst[19:15];
  assign rs2_addr = inst[24:20];
  assign rd_addr  = inst[11:7];

  // Immediate Generation
  logic [31:0] i_imm;
  logic [31:0] s_imm;
  logic [31:0] b_imm;
  logic [31:0] u_imm;
  logic [31:0] j_imm;
  assign i_imm = {{21{inst[31]}}, inst[30:20]};
  assign s_imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
  assign b_imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
  assign u_imm = {inst[31:12], 12'h000};
  assign j_imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};

  // Control Signal Generation
  always_comb begin
    // Default Values
    ctrl.imm        = '0;
    ctrl.op         = '0;
    ctrl.funct3     = '0;
    ctrl.regf_we    = '0;
    ctrl.branch     = '0; 
    ctrl.mem_write  = '0;
    ctrl.mem_read   = '0;
    ctrl.op1_mux    = rs1_out_t;
    ctrl.op2_mux    = rs2_out_t;
    ctrl.target_mux = pc_target;

    meta.euid       = alu;
    meta.ard_addr   = '0;
    meta.ars1_addr  = '0;
    meta.ars2_addr  = '0;
    meta.prd_addr   = '0;
    meta.prs1_addr  = '0;
    meta.prs1_ready = '0;
    meta.prs2_addr  = '0;
    meta.prs1_ready = '0;
    meta.rob_index  = '0;
    meta.cob_index  = '0;

    if (instr_valid) begin
      // Assign Control Signals        
      unique case (opcode)
        /**
          * The Load Upper Immediate (LUI) instruction, copies the 20-bit immediate value to the upper 20
          * bits of the destination register (rd) and resets the lower 12 bits to zero.
          *
          * Syntax:
          * - lui rd, imm
        */
        op_lui: begin
          ctrl.imm       = u_imm;
          ctrl.op        = alu_add;
          ctrl.regf_we   = 1'b1; 
          ctrl.op2_mux   = imm_out_t;

          meta.euid      = alu;
          meta.ard_addr  = rd_addr;
          meta.ars1_addr = '0;
          meta.ars2_addr = '0;
        end
        /**
          * Add Upper Immediate to PC (AUIPC) adds the 20-bit immediate value to the upper 20 bits of the
          * program counter (pc) and stores the result in the destination register (rd).
          *
          * Syntax:
          * - auipc rd, imm
        */
        op_auipc: begin
          ctrl.imm       = u_imm;
          ctrl.op        = alu_add;
          ctrl.regf_we   = 1'b1; 
          ctrl.op1_mux   = pc_out_t;
          ctrl.op2_mux   = imm_out_t;

          meta.euid      = alu;
          meta.ard_addr  = rd_addr;
          meta.ars1_addr = '0;
          meta.ars2_addr = '0;
        end
        /**
          * Jump and Link (JAL) is used to call a subroutine (i.e., function). The return address 
          * (i.e., the PC, which is the address of the instruction following the JAL) is saved in 
          * the destination register.
          * 
          * Syntax:
          * - jal rd, offset
        */
        op_jal: begin
          ctrl.imm       = j_imm;
          ctrl.op        = beq;
          ctrl.regf_we   = 1'b1;
          ctrl.branch    = 1'b1;
          ctrl.op1_mux   = rs1_out_t;
          ctrl.op2_mux   = rs2_out_t;

          meta.euid      = bru;
          meta.ard_addr  = rd_addr;
          meta.ars1_addr = '0;
          meta.ars2_addr = '0;
        end
        /**
          * Jump and Link Register (JALR) is used to invoke a subroutine call (i.e., function/method/procedure).
          * The return address (i.e., the PC, which is the address of the instruction following the JALR) 
          * is saved in the destination register.
          *
          * Syntax:
          * - jalr rd, rs1, offset
        */
        op_jalr: begin
          ctrl.imm        = i_imm;
          ctrl.op         = beq;
          ctrl.regf_we    = 1'b1;
          ctrl.branch     = 1'b1;
          ctrl.op1_mux    = rs1_out_t;
          ctrl.op2_mux    = rs2_out_t;
          ctrl.target_mux = rs1_target;

          meta.euid      = bru;
          meta.ard_addr  = rd_addr;
          meta.ars1_addr = rs1_addr;
          meta.ars2_addr = rs1_addr;
        end
        /**
          * Branch If Equal (BEQ) the contents of source register rs1 is compared with source register rs2, if
          * found equal, the control is transferred to the specified label.
          *
          * Branch If Not Equal (BNE) the contents of source register rs1, is compared with source register
          * rs2 if they are not equal control is transferred to the label as mentioned.
          *
          * Branch If Less Than (BLT) the contents of source register rs1, is compared with contents of
          * source register rs2. If (rs1) is less than (rs2) control is transferred to the label as mentioned.
          *
          * Branch If Less Than Unsigned (BLTU) the contents of source register rs1, is compared with contents of 
          * source register rs2 if (rs1) is less than (rs2) control is transferred to the label as mentioned.
          *
          * Branch If Greater Than or Equal, signed (BGE) the contents of source register rs1, is compared with 
          * contents of source register rs2 if (rs1) is greater than (rs2) control is transferred to the label as mentioned.
          *
          * Branch If Greater Than or Equal, Unsigned (BGEU) the contents of source register rs1, is compared with 
          * contents of source register rs2. If rs1 is greater than or equal to rs2, control is transferred to the label 
          * as mentioned.
          *
          * Syntax: 
          * - beq rs1, rs2, label
          * - bne rs1, rs2, label
          * - blt rs1, rs2, label
          * - bltu rs1, rs2, label
          * - bge rs1, rs2, label
          * - bgeu rs1, rs2, label
        */
        op_br: begin
          ctrl.imm       = b_imm;
          ctrl.op        = funct3;
          ctrl.branch    = 1'b1;
          ctrl.op1_mux   = rs1_out_t;
          ctrl.op2_mux   = rs2_out_t;

          meta.euid      = bru;
          meta.ars1_addr = rs1_addr;
          meta.ars2_addr = rs2_addr;
        end
        /**
          * The Load Byte (LB) instruction, moves a byte from memory to register. The instruction is used
          * for signed integers.
          *
          * The Load Byte, Unsigned (LBU) instruction, moves a byte from memory to register. The instruction
          * is used for unsigned integers.
          *
          * In RISC-V 16-bit numbers are known as half-words and the Load Half-Word signed (LH) instruction, 
          * loads a half-word from memory to register. The instruction is used for signed integers.
          *
          * Load Half-Word Unsigned (LHU) instruction, loads a half-word from memory to register. The
          * instruction is used for unsigned numbers.
          *
          * The Load Word (LW) instruction, moves a word, 32-bit value, from memory to register. The 
          * instruction is used for signed values.
          *
          * Syntax:
          * - lb rd, imm(rs1)
          * - lbu rd, imm(rs1)
          * - lh rd, imm(rs1)
          * - lhu rd, imm(rs1)
          * - lw rd, imm(rs1)
        */
        op_load: begin
          ctrl.imm       = i_imm;
          ctrl.funct3    = funct3;
          ctrl.regf_we   = 1'b1; 
          ctrl.mem_read  = 1'b1;
          ctrl.op1_mux   = rs1_out_t;
          ctrl.op2_mux   = imm_out_t;

          meta.euid      = agu;
          meta.ard_addr  = rd_addr;
          meta.ars1_addr = rs1_addr;
          meta.ars2_addr = '0;
        end
        /**
          * Store Byte (SB) instruction, stores 8-bit values from a register to memory.
          * 
          * Store Half-word (SH) instruction, stores 16-bit values from a register to memory
          * 
          * Store Word (SW) instruction, stores 32-bit values from a register to memory
          *
          * Syntax:
          * - sb rs2, offset(rs1)
          * - sh rs2, offset(rs1)
          * - sw rs2, offset(rs1)
        */
        op_store: begin
          ctrl.imm       = s_imm;
          ctrl.funct3    = funct3;
          ctrl.mem_write = 1'b1;
          ctrl.op1_mux   = rs1_out_t;
          ctrl.op2_mux   = imm_out_t;

          meta.euid      = agu;
          meta.ars1_addr = rs1_addr;
          meta.ars2_addr = rs2_addr;
        end
        /**
          * Add Immediate (ADDI) adds content of the source registers rs1, immediate data (imm) and store
          * the result in the destination register (rd).
          *
          * Set Less than Immediate (SLTI) compares contents of register (rs1) and Immediate data (imm)
          * and sets value of comparison in (rd) register.
          *
          * Set Less Than Immediate Unsigned (SLTIU) does comparison between register contents (rs1)
          * and Immediate data (imm) and sets value of comparison in (rd) register.
          *
          * Exclusive-OR Immediate (XORI) performs bit-wise binary operation between register contents
          * (rs1) and Immediate data (imm) and stores in (rd) register
          *
          * OR Immediate (ORI) performs binary operation between register (rs1) and Immediate data (imm)
          * and stores in (rd) register
          *
          * AND Immediate (ANDI) performs binary operation between contents of register (rs1) and immediate
          * data (imm) and stores in (rd) register.
          *
          * Shift Logically Left Immediate (SLLI) performs logical left on the value in register (rs1) by
          * the shift amount held in the register (imm) and stores in (rd) register.
          *
          * Shift Logically Right Immediate (SRLI) performs logical Right on the value in register (rs1)
          * by the shift amount held in the register (imm) and stores in (rd) register.
          *
          * A Shift Right Logical Immediate (SRLI) of one position moves each bit to the Right by one.
          * The most significant bit is replaced by a zero bit and the least significant bit is discarded.
          *
          * Syntax:
          * - addi rd, rs1, imm
          * - slti rd, rs1, imm
          * - sltiu rd, rs1, imm
          * - xori rd, rs1, imm
          * - ori rd, rs1, imm
          * - andi rd, rs1, imm
          * - slli rd, rs1, imm
          * - srli rd, rs1, imm
          * - srai rd, rs1, imm
        */
        op_imm: begin
          ctrl.imm       = i_imm;
          ctrl.regf_we   = 1'b1; 
          ctrl.op1_mux   = rs1_out_t;
          ctrl.op2_mux   = imm_out_t;

          meta.ard_addr  = rd_addr;
          meta.ars1_addr = rs1_addr;
          meta.ars2_addr = '0;

          // Op-Specific Control Signals
          meta.euid = alu;
          unique case (funct3) 
            addi : ctrl.op = alu_add;
            slli : ctrl.op = alu_sll;
            slti : begin
              meta.euid = cmp;
              ctrl.op = blt;
            end
            sltiu : begin
              meta.euid = cmp;
              ctrl.op = bltu;
            end
            xori : ctrl.op = alu_xor;
            sri  : ctrl.op = (funct7 == 7'h20) ? alu_sra : alu_srl;
            ori  : ctrl.op = alu_or;
            andi : ctrl.op = alu_and;
          endcase
        end
        /**
          * Addition (ADD) adds the contents of two registers and stores the result in another register.
          *
          * Subtraction (SUB) subtracts contents of one register from another and stores the result in another register.
          *
          * Shift Logical Left (SLL) performs logical left on the value in register (rs1) by the shift amount
          * held in the register (rs2) and stores in (rd) register.
          *
          * Set Less Than (SLT) perform the signed and unsigned comparison between (rs1) and (rs2) and
          * stores the result of the comparison in (rd).
          *
          * Set Less Than Unsigned (SLTU) perform the signed and unsigned comparison between (rs1) and
          * (rs2) and stores the result of the comparison in (rd).
          *
          * XOR performs bit-wise binary Exclusive-OR operation on the source register operands.
          *
          * Shift Logically Right (SRL) performs logical Right on the value in register (rs1) by the shift
          * amount held in the register (rs2) and stores in (rd) register.
          *
          * Set Less Than Unsigned (SLTU) perform the signed and unsigned comparison between (rs1) and
          * (rs2) and stores the result in (rd).
          *
          * OR directive performs bit-wise logical OR operation between contents of register (rs1) and contents
          * of register (rs2) and stores in (rd) register.
          *
          * AND directive performs bit-wise logical AND operation between contents of register (rs1) and contents
          * of register (rs2) and stores in (rd) register.
          *
          * MUL calculates the product of the multiplier in source register 1 (rs1) and multiplicand in source 
          * register 2 (rs2), with the resulting product being stored in destination register (rd).
          *
          * Multiply signed and return upper bits (MULH) calculates the product of signed values in
          * source registers (rs1) and (rs2) and stores result in the specified destination register (rd).
          *
          * Multiply Unsigned and return upper bits (MULHU) calculates the product of two unsigned
          * values in source registers rs1 and rs2. The resulting value is placed in the specified destination
          * register (rd).
          *
          * Multiply Signed-Unsigned and return upper bits (MULHSU) calculates the product of a
          * signed value in source register rs1 with an unsigned value in source register rs2 
          * and the resulting product is stored in destination register, rd.
          *
          * Syntax:
          * - add rd, rs1, rs2
          * - sub rd, rs1, rs2
          * - sll rd, rs1, rs2
          * - slt rd, rs1, rs2
          * - sltu rd, rs1, rs2
          * - xor rd, rs1, rs2
          * - srl rd, rs1, rs2
          * - sltu rd, rs1, rs2
          * - or rd, rs1, rs2
          * - and rd, rs1, rs2
          * - mul rd, rs1, rs2
          * - mulh rd, rs1, rs2
          * - mulhu rd, rs1, rs2
          * - mulhsu rd, rs1, rs2
        */
        op_reg: begin
          ctrl.imm       = '0;
          ctrl.regf_we   = 1'b1;
          ctrl.funct3    = funct3;
          ctrl.op1_mux   = rs1_out_t;
          ctrl.op2_mux   = rs2_out_t;

          meta.ard_addr  = rd_addr;
          meta.ars1_addr = rs1_addr;
          meta.ars2_addr = rs2_addr;

          // Op-Specific Control Signals
          meta.euid = alu;
          unique case (funct3)
            addr : begin
              if (funct7 == 7'h01) begin
                meta.euid = mul;
                ctrl.op = ss_mul;
              end 
              else begin
                ctrl.op = (funct7 == 7'h20) ? alu_sub : alu_add;
              end
            end
            sllr : begin
              if (funct7 == 7'h01) begin
                meta.euid = mul;
                ctrl.op = ss_mul;
              end 
              else begin
                ctrl.op = alu_sll;
              end
            end
            sltr : begin
              if (funct7 == 7'h01) begin
                meta.euid = mul;
                ctrl.op = su_mul;
              end 
              else begin
                meta.euid = cmp;
                ctrl.op = blt;
              end
            end
            sltru : begin
              if (funct7 == 7'h01) begin
                meta.euid = mul;
                ctrl.op = uu_mul;
              end 
              else begin
                meta.euid = cmp;
                ctrl.op = bltu;
              end
            end
            xorr : begin
              if (funct7 == 7'h01) begin
                meta.euid = div;
                ctrl.op = ss_div;
              end 
              else begin
                ctrl.op = alu_xor;
              end
            end
            srr  : begin
              if (funct7 == 7'h01) begin
                meta.euid = div;
                ctrl.op = uu_div;
              end 
              else begin
                ctrl.op = (funct7 == 7'h20) ? alu_sra : alu_srl;
              end
            end
            orr  : begin
              if (funct7 == 7'h01) begin
                meta.euid = div;
                ctrl.op = ss_rem;
              end 
              else begin
                ctrl.op = alu_or;
              end
            end
            andr : begin
              if (funct7 == 7'h01) begin
                meta.euid = div;
                ctrl.op = uu_rem;
              end 
              else begin
                ctrl.op = alu_and;
              end
            end
          endcase
        end
        default : begin
        end
      endcase
    end
  end

endmodule : decoder