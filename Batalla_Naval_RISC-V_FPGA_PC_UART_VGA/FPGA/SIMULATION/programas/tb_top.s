# =====================================================================
# tb_top.s - Programa de prueba del sistema completo (tb_top.sv)
#
# Ejercita cada periferico a traves del bus real:
#   LED = 1, displays = 0x1234, dos tiles de video, envia 'A' por UART
#   y dispara el sonido de impacto. Luego queda en un lazo que:
#     - copia el registro de entradas a LED[14:8] (LED[0] sigue en 1);
#     - si llega un byte por UART, devuelve ese byte + 1.
# =====================================================================
    .text
    .globl _start
_start:
    addi gp, zero, 5
    slli gp, gp, 11              # gp = 0x2800 (RAM)
    addi tp, zero, 1
    slli tp, tp, 16              # tp = 0x1_0000 (perifericos)
    addi sp, gp, 1792            # sp = 0x2F00

    addi t0, zero, 1
    sw   t0, 0x138(tp)           # LED = 0x0001

    addi t0, zero, 0x123
    slli t0, t0, 4
    addi t0, t0, 4               # 0x1234
    sw   t0, 0x130(tp)           # displays

    addi s1, zero, 0x11
    slli s1, s1, 12              # s1 = 0x1_1000 (video)
    addi t0, zero, 0x408
    addi t0, t0, 0x408           # 0x810: simbolo '1' blanco sobre negro
    sw   t0, 0(s1)               # tile 0
    addi t0, zero, 0x103         # impacto con cursor
    sw   t0, 1196(s1)            # tile 299

    addi a0, zero, 0x41          # 'A'
    jal  ra, uart_enviar

    addi t0, zero, 1
    sw   t0, 0x140(tp)           # sonido de impacto

lazo:
    lw   t0, 0x120(tp)           # entradas
    slli t0, t0, 8
    ori  t0, t0, 1
    sw   t0, 0x138(tp)           # LED[14:8] = entradas, LED[0] = 1

    lw   t1, 0x40(tp)            # control UART
    andi t1, t1, 2               # new_rx
    beq  t1, zero, lazo
    lw   a0, 0x48(tp)            # byte recibido
    addi t1, zero, 2
    sw   t1, 0x40(tp)            # limpiar new_rx
    addi a0, a0, 1
    jal  ra, uart_enviar
    jal  zero, lazo

# envia el byte de a0 y espera a que termine
uart_enviar:
    sw   a0, 0x44(tp)            # dato TX
    addi t2, zero, 1
    sw   t2, 0x40(tp)            # send
espera_tx:
    lw   t2, 0x40(tp)
    andi t2, t2, 1
    bne  t2, zero, espera_tx
    jalr zero, 0(ra)
