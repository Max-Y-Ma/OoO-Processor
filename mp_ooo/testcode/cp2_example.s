.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi    x1, x0, 4       # x1 <= 4
    addi    x3, x1, 8       # x3 <= x1 + 8
    lui     x2, 2           # x2 <= (2 << 'd12)
    auipc   x7, 8           # X <= PC + (8 << 'd12)

    # Test Writing to x0, should not write
    lui     x0, 5           # x0 <= 5
    
    # Test immediate operand instructions
    addi    x2, x1, 0x123   # x2 <= x1 + 0x123 
    slti    x3, x2, 0x123   # x3 <= (x2 < 0x123)
    sltiu   x4, x3, 0x123   # x4 <= (x3 < 0x123)
    xori    x5, x4, 0x123   # x5 <= x4 ^ 0x123
    ori 	  x6, x5, 0x123   # x6 <= x5 | 0x123
    andi    x7, x6, 0x123   # x7 <= x6 & 0x123
    slli    x8, x7, 0xF     # x8 <= x7 << 0xF
    srli    x9, x8, 0xF     # x9 <= x8 >> 0xF
    srai    x10, x9, 0xF    # x10 <= x9 >>> 0xF
    
    # Test register operand instructions
    add 	x11, x10, x9
    add 	x12, x11, x10
    sub 	x13, x12, x11
    sub 	x14, x13, x12
    sll 	x15, x14, x13
    sll 	x16, x15, x14
    slt 	x17, x16, x15
    slt 	x18, x17, x16
    sltu  x19, x18, x17
    sltu  x20, x19, x18
    xor 	x21, x20, x19
    xor 	x22, x21, x20
    srl 	x23, x22, x21
    srl 	x24, x23, x22
    sra 	x25, x24, x23
    sra 	x26, x25, x24
    or  	x27, x26, x25
    or  	x28, x27, x26
    and 	x29, x28, x27
    and 	x30, x29, x28
    and 	x31, x30, x29

    mul	    x11, x10, x9
    mul	    x12, x11, x10
    mul	    x13, x12, x11
    mulh	  x14, x13, x12
    mulh    x15, x14, x13
    mulh	  x16, x15, x14
    mulhsu	x17, x16, x15
    mulhsu	x18, x17, x16
    mulhsu  x19, x18, x17
    mulhu   x20, x19, x18
    mulhu	  x21, x20, x19
    mulhu	  x22, x21, x20
    mul	    x23, x22, x21
    add	    x24, x23, x22
    mul	    x25, x24, x23
    add	    x26, x25, x24
    mul	    x27, x26, x25
    add	    x28, x27, x26
    mul	    x29, x28, x27
    add	    x30, x29, x28
    mul	    x31, x30, x29
    
    # Test load/store instructions
    # Load the RAM address into x7
    lui     x2, 0x89ABD
    lui     x7, 0x70000

    # Test four x byte stores
    sb      x2, 0(x7)
    sb      x2, 1(x7)
    sb      x2, 2(x7)
    sb      x2, 3(x7)

    # Load them back as a word
    lw	    x3, 0(x7)

    # Test two x halfword stores
    lui     x2, 0x12345
    sh      x2, 0(x7)
    sh      x2, 2(x7)

    # Load them back as a word
    lw	    x3, 0(x7)

    #Create a new test value 0x89ABCDEF
    lui     x2, 0x89ABD

    # Store it into RAM  
    sw      x2, 0(x7)

    # Load them back as a word
    lw      x3, 0(x7)

    # Test signed halfword loads
    lh      x2, 0(x7)
    lh      x2, 2(x7)

    # Test signed byte loads
    lb      x2, 0(x7)
    lb      x2, 1(x7)
    lb      x2, 2(x7)
    lb      x2, 3(x7)

    # Test unsigned halfword loads
    lhu     x2, 0(x7)
    lhu     x2, 2(x7)

    # Test unsigned byte loads
    lbu     x2, 0(x7)
    lbu     x2, 1(x7)
    lbu     x2, 2(x7)
    lbu     x2, 3(x7)

    # Load Hazards
    lui     x1, 0x70000
    lw      x2, 0(x1)
    and     x3, x2, x2
    lh      x4, 0(x1)
    and     x5, x4, x4
    lb      x6, 0(x1)
    and     x7, x6, x6

    # Consecutive Load/Stores Hazards
    lui     x7, 0x70000
    sw      x7, 0(x7)
    sw      x7, 0(x7)
    sw      x7, 0(x7)
    lw      x7, 0(x7)
    lw      x7, 0(x7)
    lw      x7, 0(x7)

    # Edge Case: From Bubble Sort Example
    sw	   x15, 36(x7)
    li	   x15, 64
    sw	   x15, 32(x7)
    li	   x15, 34
    sw	   x15, 28(x7)
    li	   x15, 25
    sw	   x15, 24(x7)
    li	   x15, 22

    # Test branch/jump instructions
    jal     x4, tmp0
    ori 	x3, x3, 1
tmp0:	
    ori 	x3, x3, 2
    ori 	x3, x3, 4

    auipc   x5, 0
    addi    x5, x5, 16
    jalr    x6, 0(x5)
    addi 	x5, x5, 2
    addi 	x5, x5, 4   # Should Branch Here

    # Testing conditional branches
    lui     x7, 0x70000
    addi 	  x2, x0, 0x2
    addi    x3, x0, 0x4
    addi    x4, x0, 0x4
    # Test conditionals branches not taken
    beq     x2, x3, tmp1
    ori     x5, x5, 2 
tmp1:	
    bne     x3, x4, tmp2     
    ori     x5, x5, 2 
tmp2:	
    blt     x3, x4, tmp3 
    ori     x5, x5, 4 
tmp3:	
    bge     x2, x4, tmp4 
    ori     x5, x5, 8 
tmp4:	
    bltu 	x3, x4, tmp5 
    ori     x5, x5, 0x20 
tmp5:	
    bgeu 	x2, x4, tmp6         
    ori     x5, x5, 0x20 
tmp6:
    # Test conditionals branches that are taken
    addi 	x2, x0, 0x2
    addi    x3, x0, 0x4
    addi    x4, x0, 0x4
    beq	    x3, x4, tmp11 
    ori     x5, x5, 0x01 
tmp11:
    nop
    nop
    nop
    nop
    nop
    bne	    x2, x3, tmp12
    nop
    nop
    nop
    nop
    nop
    ori     x5, x5, 0x02 
tmp12:
    nop
    nop
    nop
    nop
    nop
    blt	    x2, x3, tmp13
    nop
    nop
    nop
    nop
    nop
    ori     x5, x5, 0x04 
tmp13:
    nop
    nop
    nop
    nop
    nop
    bge	    x3, x4, tmp14 
    nop
    nop
    nop
    nop
    nop
    ori     x5, x5, 0x08 
tmp14:
    nop
    nop
    nop
    nop
    nop
    bltu	x2, x3, tmp15
    nop
    nop
    nop
    nop
    nop
    ori     x5, x5, 0x10  
tmp15:
    nop
    nop
    nop
    nop
    nop
    bgeu	x3, x4, tmp16 
    nop
    nop
    nop
    nop
    nop
    ori     x5, x5, 0x20  
tmp16:
    
    slti x0, x0, -256 # this is the magic instruction to end the simulation
