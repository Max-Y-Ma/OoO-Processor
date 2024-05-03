.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 4  # x1 <= 4
    nop
    nop             # nops in between to prevent hazard
    mul x1, x1, x1  # x1 <= 16
    nop
    addi x2, x1, 4  # x2 <= 20

    # Add your own test cases here!

    slti x0, x0, -256 # this is the magic instruction to end the simulation
