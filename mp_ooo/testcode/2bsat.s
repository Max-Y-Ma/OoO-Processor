.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 0
    addi x2, x0, 0
    addi x3, x0, 0
    addi x4, x0, 0
    addi x3, x3, 1
    lui x1, 1

_loop:
    addi x2, x2, 1
    bne x3, x4, _break
    bne x1, x2, _loop

    # Add your own test cases here!
    slti x0, x0, -256 # this is the magic instruction to end the simulation

_break:
  addi x4, x4, 1
  jal x5, _loop
