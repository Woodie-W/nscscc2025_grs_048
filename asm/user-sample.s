.set     noreorder
.set     noat
.globl   __start
.section text

__start:
    .text

find_max:
    lui      $a0, 0x8040
    lw       $v0, 0($a0)
    lui      $a1, 0x8070
    ori      $v1, $zero, 1
    lw       $t0, 4($a0)
    addiu    $a0, $a0, 8
    addiu    $a1, $a1, 8

L1: 
    lw       $t1, 0($a0)
    beq      $t0, $v0, S1
    addiu    $a0, $a0, 8

L2: 
    lw       $t0, -4($a0)
    bne      $t1, $v0, L1
    beq      $a1, $a0, S2
    j        L1
    addiu    $v1, $v1, 1
    
S1:
    j        L2
    addiu    $v1, $v1, 1
    
S2:
    j        Done_f
    ori      $zero, $zero, 0

Done_f:
    sw       $v1, -8($a1)
    jr       $ra
    ori      $zero, $zero, 0