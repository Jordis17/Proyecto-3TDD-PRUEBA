# =====================================================================
# tb_cpu.s - Programa de prueba del procesador (tb_riscv_core.sv)
#
# Cada prueba deja su resultado en t0 y lo guarda en la RAM de firmas,
# que empieza en 0x2000 (s0 avanza 4 bytes por prueba). El testbench
# compara cada palabra con el valor esperado.
#
# Solo usa las instrucciones del subconjunto implementado.
# =====================================================================
    .text
    .globl _start
_start:
    addi s0, zero, 1
    slli s0, s0, 13          # s0 = 0x2000, puntero de firmas

    # ---- inmediatas y aritmetica ----
    addi t0, zero, 5         # 1  addi positivo            -> 5
    sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, -3        # 2  addi negativo            -> 0xFFFFFFFD
    sw   t0, 0(s0)
    addi s0, s0, 4
    addi a0, zero, 5         # a0 = 5
    addi a1, zero, -3        # a1 = -3
    add  t0, a0, a1          # 3  add                      -> 2
    sw   t0, 0(s0)
    addi s0, s0, 4
    sub  t0, a0, a1          # 4  sub                      -> 8
    sw   t0, 0(s0)
    addi s0, s0, 4

    # ---- logicas ----
    addi a2, zero, 0xF0
    addi a3, zero, 0x3C
    and  t0, a2, a3          # 5  and                      -> 0x30
    sw   t0, 0(s0)
    addi s0, s0, 4
    or   t0, a2, a3          # 6  or                       -> 0xFC
    sw   t0, 0(s0)
    addi s0, s0, 4
    xor  t0, a2, a3          # 7  xor                      -> 0xCC
    sw   t0, 0(s0)
    addi s0, s0, 4
    andi t0, a2, 0x3C        # 8  andi                     -> 0x30
    sw   t0, 0(s0)
    addi s0, s0, 4
    ori  t0, a2, 0x0F        # 9  ori                      -> 0xFF
    sw   t0, 0(s0)
    addi s0, s0, 4
    xori t0, a2, -1          # 10 xori (not)               -> 0xFFFFFF0F
    sw   t0, 0(s0)
    addi s0, s0, 4

    # ---- desplazamientos ----
    addi a4, zero, 1
    addi a5, zero, 31
    sll  t0, a4, a5          # 11 sll 31                   -> 0x80000000
    sw   t0, 0(s0)
    addi s0, s0, 4
    add  a6, t0, zero        # a6 = 0x80000000
    slli t0, a4, 4           # 12 slli                     -> 0x10
    sw   t0, 0(s0)
    addi s0, s0, 4
    srl  t0, a6, a5          # 13 srl 31                   -> 1
    sw   t0, 0(s0)
    addi s0, s0, 4
    srli t0, a6, 4           # 14 srli                     -> 0x08000000
    sw   t0, 0(s0)
    addi s0, s0, 4
    sra  t0, a6, a5          # 15 sra 31                   -> 0xFFFFFFFF
    sw   t0, 0(s0)
    addi s0, s0, 4
    srai t0, a6, 4           # 16 srai                     -> 0xF8000000
    sw   t0, 0(s0)
    addi s0, s0, 4
    addi a7, zero, 33
    sll  t0, a4, a7          # 17 sll usa solo 5 bits (33) -> 2
    sw   t0, 0(s0)
    addi s0, s0, 4
    slli t0, a4, 0           # 18 slli por 0               -> 1
    sw   t0, 0(s0)
    addi s0, s0, 4

    # ---- comparaciones ----
    slt  t0, a1, a0          # 19 slt -3 < 5               -> 1
    sw   t0, 0(s0)
    addi s0, s0, 4
    slt  t0, a0, a1          # 20 slt 5 < -3               -> 0
    sw   t0, 0(s0)
    addi s0, s0, 4
    sltu t0, a1, a0          # 21 sltu 0xFFFFFFFD < 5      -> 0
    sw   t0, 0(s0)
    addi s0, s0, 4
    sltu t0, a0, a1          # 22 sltu 5 < 0xFFFFFFFD      -> 1
    sw   t0, 0(s0)
    addi s0, s0, 4
    slti t0, a1, -2          # 23 slti -3 < -2             -> 1
    sw   t0, 0(s0)
    addi s0, s0, 4
    slti t0, a0, 5           # 24 slti 5 < 5               -> 0
    sw   t0, 0(s0)
    addi s0, s0, 4
    sltiu t0, a0, 6          # 25 sltiu 5 < 6              -> 1
    sw   t0, 0(s0)
    addi s0, s0, 4
    sltiu t0, a0, -1         # 26 sltiu 5 < 0xFFFFFFFF     -> 1
    sw   t0, 0(s0)
    addi s0, s0, 4
    sltiu t0, zero, 1        # 27 sltiu (seqz de 0)        -> 1
    sw   t0, 0(s0)
    addi s0, s0, 4
    slt  t0, a6, a4          # 28 slt 0x80000000 < 1       -> 1
    sw   t0, 0(s0)
    addi s0, s0, 4

    # ---- x0 ----
    addi zero, zero, 7       # escribir x0 no tiene efecto
    add  t0, zero, zero      # 29 x0 sigue en 0            -> 0
    sw   t0, 0(s0)
    addi s0, s0, 4

    # ---- lw / sw ----
    addi s1, zero, 1
    slli s1, s1, 13
    addi s1, s1, 0x400       # s1 = 0x2400, zona libre de la RAM
    sw   a6, 0(s1)
    sw   a1, 4(s1)
    lw   t0, 0(s1)           # 30 lw desplazamiento 0      -> 0x80000000
    sw   t0, 0(s0)
    addi s0, s0, 4
    addi s2, s1, 8
    lw   t0, -4(s2)          # 31 lw desplazamiento -4     -> 0xFFFFFFFD
    sw   t0, 0(s0)
    addi s0, s0, 4

    # ---- saltos condicionales (1 = salto tomado) ----
    addi t0, zero, 1
    beq  a0, a0, 1f          # 32 beq iguales              -> 1
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    beq  a0, a1, 1f          # 33 beq distintos            -> 0
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    bne  a0, a1, 1f          # 34 bne distintos            -> 1
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    bne  a0, a0, 1f          # 35 bne iguales              -> 0
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    blt  a1, a0, 1f          # 36 blt -3 < 5               -> 1
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    blt  a0, a1, 1f          # 37 blt 5 < -3               -> 0
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    blt  a6, a4, 1f          # 38 blt 0x80000000 < 1 (desborda la resta) -> 1
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    bge  a0, a1, 1f          # 39 bge 5 >= -3              -> 1
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    bge  a1, a0, 1f          # 40 bge -3 >= 5              -> 0
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    bge  a0, a0, 1f          # 41 bge 5 >= 5               -> 1
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4
    addi t0, zero, 1
    bge  a4, a6, 1f          # 42 bge 1 >= 0x80000000      -> 1
    addi t0, zero, 0
1:  sw   t0, 0(s0)
    addi s0, s0, 4

    # ---- salto hacia atras (lazo de 5 vueltas) ----
    addi t0, zero, 0
    addi t1, zero, 5
2:  addi t0, t0, 1
    blt  t0, t1, 2b          # 43 blt hacia atras          -> 5
    sw   t0, 0(s0)
    addi s0, s0, 4

    # ---- jal: enlace y salto ----
    jal  ra, 3f              # ra = direccion de la siguiente instruccion
    addi t2, zero, 99        # nunca se ejecuta
3:  jal  t1, 4f              # t1 = direccion de 4f
4:  sub  t0, t1, ra          # 44 jal: diferencia de enlaces -> 8
    sw   t0, 0(s0)
    addi s0, s0, 4

    # ---- jal + jalr: llamada y retorno ----
    addi t0, zero, 0
    jal  ra, subrutina
    addi t0, t0, 10          # se ejecuta al volver
    sw   t0, 0(s0)           # 45 llamada y retorno        -> 11
    addi s0, s0, 4

    # ---- jalr limpia el bit 0 ----
    addi t0, zero, 0
    jal  ra, subrutina_impar
    addi t0, t0, 10
    sw   t0, 0(s0)           # 46 jalr con destino impar   -> 11
    addi s0, s0, 4

    # ---- fin: lazo infinito, el testbench detecta que el PC no cambia ----
fin:
    jal  zero, fin

subrutina:
    addi t0, t0, 1
    jalr zero, 0(ra)

subrutina_impar:
    addi t0, t0, 1
    jalr zero, 1(ra)         # ra + 1 es impar; el bit 0 se descarta
