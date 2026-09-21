# =====================================================================
# tb_bus.s - Programa de prueba del bus de datos (tb_cpu_bus.sv)
#
# Escribe y lee en cada region del mapa de memoria usando los registros
# base de la convencion (gp = 0x2800, tp = 0x1_0000). Cada valor leido
# se guarda como firma en la RAM desde 0x2100 (s0). Los perifericos del
# testbench devuelven el valor escrito XOR una marca propia, asi que la
# firma demuestra que la lectura vino del destino correcto.
# =====================================================================
    .text
    .globl _start
_start:
    addi gp, zero, 5
    slli gp, gp, 11          # gp = 0x2800
    addi tp, zero, 1
    slli tp, tp, 16          # tp = 0x1_0000
    addi s0, gp, -1792       # s0 = 0x2100, firmas

    # ---- RAM: primera y ultima palabra ----
    addi t0, zero, 0x11
    sw   t0, -2048(gp)       # 0x2000
    addi t0, zero, 0x22
    sw   t0, 2044(gp)        # 0x2FFC
    lw   t1, -2048(gp)
    sw   t1, 0(s0)           # 1  -> 0x11
    lw   t1, 2044(gp)
    sw   t1, 4(s0)           # 2  -> 0x22

    # ---- UART: registros 0, 1 y 2 ----
    addi t0, zero, 0x31
    sw   t0, 0x40(tp)
    addi t0, zero, 0x32
    sw   t0, 0x44(tp)
    addi t0, zero, 0x33
    sw   t0, 0x48(tp)
    lw   t1, 0x40(tp)
    sw   t1, 8(s0)           # 3  -> 0x10000031
    lw   t1, 0x44(tp)
    sw   t1, 12(s0)          # 4  -> 0x10000032
    lw   t1, 0x48(tp)
    sw   t1, 16(s0)          # 5  -> 0x10000033

    # ---- entradas ----
    addi t0, zero, 0x41
    sw   t0, 0x120(tp)
    lw   t1, 0x120(tp)
    sw   t1, 20(s0)          # 6  -> 0x20000041

    # ---- displays (0x130) y LED (0x138, 0x13C) ----
    addi t0, zero, 0x51
    sw   t0, 0x130(tp)
    addi t0, zero, 0x61
    sw   t0, 0x138(tp)
    addi t0, zero, 0x62
    sw   t0, 0x13C(tp)
    lw   t1, 0x130(tp)
    sw   t1, 24(s0)          # 7  -> 0x30000051
    lw   t1, 0x138(tp)
    sw   t1, 28(s0)          # 8  -> 0x40000061
    lw   t1, 0x13C(tp)
    sw   t1, 32(s0)          # 9  -> 0x40000062

    # ---- buzzer ----
    addi t0, zero, 0x71
    sw   t0, 0x140(tp)
    lw   t1, 0x140(tp)
    sw   t1, 36(s0)          # 10 -> 0x50000071

    # ---- video: primer y ultimo tile de la ventana ----
    addi s1, zero, 0x11
    slli s1, s1, 12          # s1 = 0x1_1000
    addi t0, zero, 0x81
    sw   t0, 0(s1)
    addi t0, zero, 0x82
    sw   t0, 2044(s1)        # 0x1_17FC
    lw   t1, 0(s1)
    sw   t1, 40(s0)          # 11 -> 0x81
    lw   t1, 2044(s1)
    sw   t1, 44(s0)          # 12 -> 0x82

    # ---- direcciones sin asignar ----
    addi t0, zero, 0x99
    sw   t0, 0x100(tp)       # 0x1_0100: no debe llegar a nadie
    lw   t1, 0x100(tp)
    sw   t1, 48(s0)          # 13 -> 0
    addi s2, zero, 3
    slli s2, s2, 12          # 0x3000, justo despues de la RAM
    lw   t1, 0(s2)
    sw   t1, 52(s0)          # 14 -> 0
    addi s3, s1, 2047
    lw   t1, 1(s3)           # 0x1_1800, justo despues del video
    sw   t1, 56(s0)          # 15 -> 0

fin:
    jal  zero, fin
