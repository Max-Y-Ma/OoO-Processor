.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 100
    addi x2, x0, 0
    lui x5, 0x70000

_loop:
    addi x2, x2, 1
    sw   x2, 0(x5)
    lw   x2, 0(x5)
    beq  x1, x0, _loop
    beq  x1, x0, _loop
    beq  x1, x0, _loop
    bne x1, x2,  _end
    j            _loop

_end:

    

    # Add your own test cases here!

    slti x0, x0, -256 # this is the magic instruction to end the simulation
