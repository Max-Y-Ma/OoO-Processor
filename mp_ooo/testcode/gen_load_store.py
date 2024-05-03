import random

def reset_reg_instr(reg_num):
  return f"xor x{reg_num}, x{reg_num}, x{reg_num}\n"

def reg_load_val(reg_num, reg_val):
  val_upper = reg_val >> 12
  val_lower = reg_val & 0x7FF
  lui_instr = f"lui x{reg_num}, {val_upper}\n"
  add_instr = f"addi x{reg_num}, x{reg_num}, {val_lower}\n"
  return lui_instr + add_instr

def __main__():
  f = open("bible.s", "w")

  # Add headers and stuff to the top
  f.write('''bible.s:
.align 4
.section .text
.globl _start
_start:\n
''')

  num_tests       = 10
  num_load_store  = 10000

  for i in range(num_tests):
    store_instrs = ["sw", "sb", "sh"]
    load_instrs = ["lb", "lh", "lw", "lbu", "lhu"]

    # Generate random registers
    rand_rs1 = random.randint(0, 31)
    rand_rs2 = abs(31 - rand_rs1)
    rand_rd  = random.randint(0, 31)

    # Generate Random reg address into the register
    f.write(reset_reg_instr(rand_rs1))
    rand_addr = random.randint(0x70000000, 0x80000000)

    # Reset mem address to 0
    f.write(reg_load_val(rand_rs1, rand_addr & (~3)))
    f.write(reg_load_val(rand_rs2, 0))
    rand_offset = random.randint(0, 2**11 - 1) & (~3)
    f.write(f'sw  x{rand_rs2}, {rand_offset & (~3)}(x{rand_rs1})\n')
    f.write('# RESET DONE\n')

    for j in range(num_load_store):
      rand_store_load = random.randint(0, 1)
      # Generate random immediate offset
      rand_offset_offset = random.randint(0, 3)

      if (rand_store_load == 0):
        rand_store_val = random.randint(0, (2**32 - 1))
        f.write(reg_load_val(rand_rs2, rand_store_val))
        # Stores
        rand_store_choice = random.randint(0, 2)
        if (rand_store_choice == 0):
          f.write(f'sb  x{rand_rs2}, {rand_offset + rand_offset_offset}(x{rand_rs1})\n')
        elif (rand_store_choice == 1):
          f.write(f'sh  x{rand_rs2}, {(rand_offset + rand_offset_offset) & (~1)}(x{rand_rs1})\n')
        else:
          f.write(f'sw  x{rand_rs2}, {(rand_offset + rand_offset_offset) & (~3)}(x{rand_rs1})\n')
      else:
        # Loads
        rand_load_choice = random.randint(0, 2)
        if (rand_load_choice == 0):
          f.write(f'lb  x{rand_rs2}, {(rand_offset + rand_offset_offset)}(x{rand_rs1})\n')
          f.write(f'lbu x{rand_rs2}, {(rand_offset + rand_offset_offset)}(x{rand_rs1})\n')
        elif (rand_load_choice == 1):
          f.write(f'lh  x{rand_rs2}, {(rand_offset + rand_offset_offset) & (~1)}(x{rand_rs1})\n')
          f.write(f'lhu x{rand_rs2}, {(rand_offset + rand_offset_offset) & (~1)}(x{rand_rs1})\n')
        else:
          f.write(f'lw  x{rand_rs2}, {(rand_offset + rand_offset_offset) & (~3)}(x{rand_rs1})\n')

    # Add new line for readability
    f.write('\n\n')

  # Footer for Program
  f.write('''

slti x0, x0, -256 # this is the magic instruction to end the simulation

.section ".tohost"
.globl tohost
tohost: .dword 0
.section ".fromhost"
.globl fromhost
fromhost: .dword 0
''')


  f.close()

if __name__ == "__main__":
  __main__()

