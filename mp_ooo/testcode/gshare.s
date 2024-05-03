.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    # addi x1, x0, 10
    addi x2, x0, 0
    addi x4, x0, 4
    addi x7, x0, 3
    lui x1, 1

    # want not take, not take, not take, take, take, take (something that would fail on simple 2bsat)
_loop:
    addi x2, x2, 1
    
    addi x3, x3, 1
    bge x3, x4, _top

    bge x1, x2, _loop

    # Add your own test cases here!
    slti x0, x0, -256 # this is the magic instruction to end the simulation

_top:
    addi x6, x6, 1
    beq x6, x7, _restart
    jal x5, _loop

_restart:
    addi x3, x0, 0
    addi x6, x0, 0
    jal x5, _loop
