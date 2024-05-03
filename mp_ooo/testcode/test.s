test.s:
.align 4
.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 4  # x1 <= 4
    addi x2, x0, 4  # x2 <= 4
    nop
    nop
    nop
    nop
    nop
    beq  x1, x2, label
    nop
    nop
    nop
    nop
    nop
  label:
    nop
    nop
    nop
    nop
    nop
    beq  x1, x2, label2
    nop
    nop
    nop
    nop
    nop
  label2:
    auipc x3, 0 
    sw    x3, 0(x3)
    lw    x5, 0(x3)

    # Add your own test cases here!

    slti x0, x0, -256 # this is the magic instruction to end the simulation
