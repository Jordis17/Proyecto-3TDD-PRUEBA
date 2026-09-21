# =====================================================================
# batalla_naval.s - Programa del juego Batalla Naval (RV32I)
# EL3313 Taller de Diseno Digital - Proyecto 3
#
# Todo el control del juego vive aqui: colocacion de barcos de ambos
# jugadores, turnos, disparos, barcos hundidos, victoria y reinicio.
# Los perifericos solo hacen entrada/salida.
#
# Referencias del planteamiento:
#   seccion 7   mapa de memoria y registros de perifericos
#   seccion 8   organizacion de la RAM (una palabra por casilla)
#   seccion 9   pantalla de 20 x 15 tiles
#   seccion 10  protocolo UART
#   seccion 11  convencion de registros y llamadas
#
# Convencion: gp = 0x2800 (base de RAM) y tp = 0x1_0000 (base de
# perifericos) se cargan al inicio y no se modifican. Argumentos en
# a0-a7, resultado en a0; t0-t6 temporales; s0-s11 se preservan en la
# pila. Solo se usan instrucciones del subconjunto implementado; no se
# usan li con valores grandes, la, call ni lui.
#
# Ensamblar con RARS, configuracion de memoria "Compact, Text at
# Address 0", y exportar .text como texto hexadecimal (programa.mem).
# =====================================================================

# ---- variables en RAM, desplazamiento respecto a gp (planteamiento 8.3) ----
    .eqv TAB_J1,     -2048      # 0x2000 tablero J1, 64 palabras
    .eqv TAB_J2,     -1792      # 0x2100 tablero J2
    .eqv REST_J1,    -1536      # 0x2200 casillas restantes barcos 0-2 de J1
    .eqv COLOC_J1,   -1524      # 0x220C mascara de barcos colocados de J1
    .eqv REST_J2,    -1520      # 0x2210
    .eqv COLOC_J2,   -1508      # 0x221C
    .eqv FASE,       -1504      # 0x2220 0 colocacion, 1 batalla, 2 fin
    .eqv TURNO,      -1500      # 0x2224 0 = J1, 1 = J2
    .eqv DISP_J1,    -1496      # 0x2228 disparos validos (J2 en +4)
    .eqv HUND_J1,    -1488      # 0x2230 barcos hundidos POR J1 (J2 en +4)
    .eqv GANADOR,    -1480      # 0x2238
    .eqv CUR_F,      -1472      # 0x2240 cursor del J1: fila
    .eqv CUR_C,      -1468      # 0x2244 columna
    .eqv CUR_OR,     -1464      # 0x2248 orientacion (0 H, 1 V)
    .eqv CUR_BARCO,  -1460      # 0x224C barco que coloca el J1
    .eqv ENT_ANT,    -1456      # 0x2250 lectura anterior de entradas
    .eqv RX_CNT,     -1408      # 0x2280 caracteres recibidos de la trama
    .eqv RX_LEN,     -1404      # 0x2284 largo esperado
    .eqv RX_BUF,     -1400      # 0x2288 campos de la trama, uno por palabra
    .eqv VIC_J1,      1792      # 0x2F00 victorias acumuladas J1
    .eqv VIC_J2,      1796      # 0x2F04 victorias acumuladas J2

# ---- perifericos, desplazamiento respecto a tp (planteamiento 7) ----
    .eqv UART_CTRL,  0x40
    .eqv UART_TX,    0x44
    .eqv UART_RX,    0x48
    .eqv ENTRADAS,   0x120
    .eqv DISPLAYS,   0x130
    .eqv LEDS,       0x138
    .eqv BUZZER,     0x140

# ---- bits del registro de entradas ----
    .eqv B_ARRIBA,   0x01
    .eqv B_ABAJO,    0x02
    .eqv B_IZQ,      0x04
    .eqv B_DER,      0x08
    .eqv B_SEL,      0x10
    .eqv B_OK,       0x20
    .eqv B_RST,      0x40

# ---- sonidos ----
    .eqv SND_IMPACTO,  1
    .eqv SND_FALLO,    2
    .eqv SND_HUNDIDO,  3
    .eqv SND_INVALIDA, 4
    .eqv SND_VICTORIA, 5

# ---- simbolos de la pantalla (codigo del digito d = d + 1) ----
    .eqv S_A, 11
    .eqv S_B, 12
    .eqv S_C, 13
    .eqv S_F, 14
    .eqv S_G, 15
    .eqv S_I, 16
    .eqv S_J, 17
    .eqv S_L, 18
    .eqv S_N, 19
    .eqv S_O, 20
    .eqv S_R, 21
    .eqv S_T, 22
    .eqv S_U, 23
    .eqv S_DOSP, 24

# ---- colores de la paleta ----
    .eqv C_AGUA,     1
    .eqv C_BARCO,    2
    .eqv C_IMPACTO,  3
    .eqv C_FALLO,    4
    .eqv C_BLANCO,   4
    .eqv C_PREVIA,   5
    .eqv C_AMARILLO, 6

# ---- caracteres ASCII del protocolo ----
    .eqv A_NUMERAL,  35         # '#'
    .eqv A_CERO,     48         # '0'
    .eqv A_UNO,      49         # '1'
    .eqv A_NL,       10         # '\n'
    .eqv A_A,        65
    .eqv A_B,        66
    .eqv A_C,        67
    .eqv A_D,        68
    .eqv A_E,        69
    .eqv A_F,        70
    .eqv A_H,        72
    .eqv A_I,        73
    .eqv A_N,        78
    .eqv A_P,        80
    .eqv A_R,        82
    .eqv A_T,        84
    .eqv A_V,        86
    .eqv A_X,        88

    .text
# =====================================================================
# Arranque (solo despues del reinicio general)
# =====================================================================
inicio:
    addi gp, zero, 5
    slli gp, gp, 11             # gp = 0x0000_2800
    addi tp, zero, 1
    slli tp, tp, 16             # tp = 0x0001_0000
    sw   zero, VIC_J1(gp)       # victorias en 0 solo aqui
    sw   zero, VIC_J2(gp)

# =====================================================================
# Nueva partida: al arrancar y con BTN_RST. Conserva las victorias.
# Se llega con un salto (no es una llamada), por eso reinicia la pila.
# =====================================================================
nueva_partida:
    addi sp, gp, 1792           # sp = 0x2F00

    # limpiar 0x2000-0x22FF
    addi t0, gp, TAB_J1
    addi t1, gp, -1280          # 0x2300
np_limpiar_ram:
    sw   zero, 0(t0)
    addi t0, t0, 4
    bne  t0, t1, np_limpiar_ram

    # casillas restantes de cada barco: 4, 3, 2
    addi t0, zero, 4
    sw   t0, REST_J1(gp)
    sw   t0, REST_J2(gp)
    addi t0, zero, 3
    sw   t0, -1532(gp)          # REST_J1 + 4
    sw   t0, -1516(gp)          # REST_J2 + 4
    addi t0, zero, 2
    sw   t0, -1528(gp)          # REST_J1 + 8
    sw   t0, -1512(gp)          # REST_J2 + 8

    # limpiar la memoria de video (512 palabras)
    addi t0, zero, 0x11
    slli t0, t0, 12             # 0x1_1000
    addi t1, t0, 2047
    addi t1, t1, 1              # 0x1_1800
np_limpiar_video:
    sw   zero, 0(t0)
    addi t0, t0, 4
    bne  t0, t1, np_limpiar_video

    jal  ra, dibujar_hud_fijo
    addi a0, zero, 0
    jal  ra, texto_fase
    jal  ra, mostrar_victorias
    jal  ra, dibujar_tablero_j1
    jal  ra, dibujar_tablero_j2

    addi t0, zero, 1
    sw   t0, LEDS(tp)           # LD0: colocacion

    addi a6, zero, A_C          # #C: comienza la colocacion
    addi a7, zero, 0
    jal  ra, enviar_trama

    lw   t0, ENTRADAS(tp)       # BTN_RST que sigue presionado no cuenta
    sw   t0, ENT_ANT(gp)

# =====================================================================
# Lazo principal: nunca espera a un jugador (planteamiento 11.4)
# =====================================================================
lazo:
    jal  ra, leer_pulsaciones
    add  s0, a0, zero
    andi t0, s0, B_RST
    beqz t0, lazo_uart
    j    nueva_partida

lazo_uart:
    jal  ra, uart_recibir       # 0 nada, 1 trama #P, 2 trama #D
    addi t0, zero, 1
    bne  a0, t0, lazo_uart_d
    jal  ra, atender_colocacion_j2
    j    lazo_fase
lazo_uart_d:
    addi t0, zero, 2
    bne  a0, t0, lazo_fase
    jal  ra, atender_disparo_j2

lazo_fase:
    lw   t0, FASE(gp)
    bnez t0, lazo_batalla

    # colocacion
    beqz s0, lazo_ambos
    add  a0, s0, zero
    jal  ra, atender_j1_colocacion
lazo_ambos:
    lw   t0, COLOC_J1(gp)
    lw   t1, COLOC_J2(gp)
    and  t0, t0, t1
    addi t1, zero, 7
    bne  t0, t1, lazo
    jal  ra, iniciar_batalla
    j    lazo

lazo_batalla:
    addi t1, zero, 1
    bne  t0, t1, lazo           # fase 2: solo se espera BTN_RST
    lw   t0, TURNO(gp)
    bnez t0, lazo
    beqz s0, lazo
    add  a0, s0, zero
    jal  ra, atender_j1_batalla
    j    lazo

# =====================================================================
# Entradas
# =====================================================================

# leer_pulsaciones: a0 = pulsaciones nuevas. Botones: cambio de 0 a 1.
# BTN_SEL es un switch: cuenta cualquier cambio de posicion.
leer_pulsaciones:
    lw   t0, ENTRADAS(tp)
    lw   t1, ENT_ANT(gp)
    sw   t0, ENT_ANT(gp)
    xori t2, t1, -1
    and  t2, t0, t2             # bits que pasaron de 0 a 1
    andi t2, t2, 0x6F           # sin el bit de SEL
    xor  t3, t0, t1
    andi t3, t3, B_SEL          # cambio del switch
    or   a0, t2, t3
    ret

# =====================================================================
# Colocacion
# =====================================================================

# atender_j1_colocacion: a0 = pulsaciones. Mueve el cursor, rota con
# SEL y confirma con OK el barco CUR_BARCO.
atender_j1_colocacion:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    add  s0, a0, zero
    lw   t0, COLOC_J1(gp)
    addi t1, zero, 7
    beq  t0, t1, ac_fin         # ya coloco los tres

    lw   t0, CUR_F(gp)
    lw   t1, CUR_C(gp)
    andi t2, s0, B_ARRIBA
    beqz t2, ac_abajo
    beqz t0, ac_abajo
    addi t0, t0, -1
ac_abajo:
    andi t2, s0, B_ABAJO
    beqz t2, ac_izq
    slti t3, t0, 7
    beqz t3, ac_izq
    addi t0, t0, 1
ac_izq:
    andi t2, s0, B_IZQ
    beqz t2, ac_der
    beqz t1, ac_der
    addi t1, t1, -1
ac_der:
    andi t2, s0, B_DER
    beqz t2, ac_guardar
    slti t3, t1, 7
    beqz t3, ac_guardar
    addi t1, t1, 1
ac_guardar:
    sw   t0, CUR_F(gp)
    sw   t1, CUR_C(gp)
    andi t2, s0, B_SEL
    beqz t2, ac_ok
    lw   t3, CUR_OR(gp)
    xori t3, t3, 1
    sw   t3, CUR_OR(gp)

ac_ok:
    andi t2, s0, B_OK
    beqz t2, ac_dibujar
    addi a0, zero, 0
    lw   a1, CUR_BARCO(gp)
    lw   a2, CUR_F(gp)
    lw   a3, CUR_C(gp)
    lw   a4, CUR_OR(gp)
    jal  ra, validar_colocacion
    beqz a0, ac_valida
    addi t0, zero, SND_INVALIDA
    sw   t0, BUZZER(tp)
    j    ac_dibujar
ac_valida:
    addi a0, zero, 0
    lw   a1, CUR_BARCO(gp)
    lw   a2, CUR_F(gp)
    lw   a3, CUR_C(gp)
    lw   a4, CUR_OR(gp)
    jal  ra, colocar_barco
    lw   t0, CUR_BARCO(gp)
    addi t0, t0, 1
    sw   t0, CUR_BARCO(gp)

ac_dibujar:
    jal  ra, dibujar_tablero_j1
ac_fin:
    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# atender_colocacion_j2: trama #P completa en RX_BUF (barco, fila,
# columna, orientacion). Responde #A b o #X b motivo.
atender_colocacion_j2:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    lw   t0, FASE(gp)
    bnez t0, acj2_fin           # fuera de fase: se descarta
    addi a0, zero, 1
    lw   a1, RX_BUF(gp)
    lw   a2, -1396(gp)          # RX_BUF + 4
    lw   a3, -1392(gp)          # RX_BUF + 8
    lw   a4, -1388(gp)          # RX_BUF + 12
    jal  ra, validar_colocacion
    add  s0, a0, zero
    lw   a1, RX_BUF(gp)
    addi a1, a1, A_CERO
    bnez s0, acj2_rechazo
    addi a0, zero, 1
    lw   a1, RX_BUF(gp)
    lw   a2, -1396(gp)
    lw   a3, -1392(gp)
    lw   a4, -1388(gp)
    jal  ra, colocar_barco
    lw   a1, RX_BUF(gp)
    addi a1, a1, A_CERO
    addi a6, zero, A_A          # #A b
    addi a7, zero, 1
    jal  ra, enviar_trama
    j    acj2_fin
acj2_rechazo:
    addi a2, s0, A_CERO         # #X b motivo
    addi a6, zero, A_X
    addi a7, zero, 2
    jal  ra, enviar_trama
acj2_fin:
    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# validar_colocacion: a0 jugador, a1 barco, a2 fila, a3 columna,
# a4 orientacion (0 H, 1 V). Devuelve a0: 0 valida, 1 fuera del
# tablero, 2 traslape, 3 barco ya colocado.
validar_colocacion:
    addi sp, sp, -28
    sw   ra, 24(sp)
    sw   s0, 20(sp)
    sw   s1, 16(sp)
    sw   s2, 12(sp)
    sw   s3, 8(sp)
    sw   s4, 4(sp)
    sw   s5, 0(sp)
    add  s0, a0, zero
    add  s1, a1, zero
    add  s2, a2, zero
    add  s3, a3, zero
    add  s4, a4, zero

    slli t0, s0, 4              # mascara de colocados del jugador
    add  t0, t0, gp
    lw   t1, COLOC_J1(t0)
    addi t2, zero, 1
    sll  t2, t2, s1
    and  t2, t1, t2
    addi a0, zero, 3
    bnez t2, vc_fin

    addi s5, zero, 4
    sub  s5, s5, s1             # largo = 4 - barco
    add  t0, s3, s5             # ultima casilla: inicio + largo - 1
    beqz s4, vc_extremo
    add  t0, s2, s5
vc_extremo:
    addi t0, t0, -1
    slti t1, t0, 8
    addi a0, zero, 1
    beqz t1, vc_fin

vc_lazo:
    add  a0, s0, zero
    add  a1, s2, zero
    add  a2, s3, zero
    jal  ra, celda_dir
    lw   t0, 0(a0)
    andi t0, t0, 3
    addi a0, zero, 2
    bnez t0, vc_fin
    beqz s4, vc_horizontal
    addi s2, s2, 1
    j    vc_siguiente
vc_horizontal:
    addi s3, s3, 1
vc_siguiente:
    addi s5, s5, -1
    bnez s5, vc_lazo
    addi a0, zero, 0

vc_fin:
    lw   s5, 0(sp)
    lw   s4, 4(sp)
    lw   s3, 8(sp)
    lw   s2, 12(sp)
    lw   s1, 16(sp)
    lw   s0, 20(sp)
    lw   ra, 24(sp)
    addi sp, sp, 28
    ret

# colocar_barco: mismos argumentos que validar_colocacion, ya validados.
# Escribe barco + 1 en cada casilla y marca el barco como colocado.
colocar_barco:
    addi sp, sp, -28
    sw   ra, 24(sp)
    sw   s0, 20(sp)
    sw   s1, 16(sp)
    sw   s2, 12(sp)
    sw   s3, 8(sp)
    sw   s4, 4(sp)
    sw   s5, 0(sp)
    add  s0, a0, zero
    add  s1, a1, zero
    add  s2, a2, zero
    add  s3, a3, zero
    add  s4, a4, zero
    addi s5, zero, 4
    sub  s5, s5, s1
cb_lazo:
    add  a0, s0, zero
    add  a1, s2, zero
    add  a2, s3, zero
    jal  ra, celda_dir
    addi t0, s1, 1
    sw   t0, 0(a0)
    beqz s4, cb_horizontal
    addi s2, s2, 1
    j    cb_siguiente
cb_horizontal:
    addi s3, s3, 1
cb_siguiente:
    addi s5, s5, -1
    bnez s5, cb_lazo

    slli t0, s0, 4
    add  t0, t0, gp
    lw   t1, COLOC_J1(t0)
    addi t2, zero, 1
    sll  t2, t2, s1
    or   t1, t1, t2
    sw   t1, COLOC_J1(t0)

    lw   s5, 0(sp)
    lw   s4, 4(sp)
    lw   s3, 8(sp)
    lw   s2, 12(sp)
    lw   s1, 16(sp)
    lw   s0, 20(sp)
    lw   ra, 24(sp)
    addi sp, sp, 28
    ret

# celda_dir: a0 jugador, a1 fila, a2 columna -> a0 direccion de la
# casilla: 0x2000 + jugador * 256 + (fila * 8 + columna) * 4.
celda_dir:
    slli t0, a0, 8
    slli t1, a1, 3
    add  t1, t1, a2
    slli t1, t1, 2
    add  t0, t0, t1
    add  t0, t0, gp
    addi a0, t0, TAB_J1
    ret

# =====================================================================
# Batalla
# =====================================================================

# iniciar_batalla: ambos jugadores tienen sus tres barcos.
iniciar_batalla:
    addi sp, sp, -4
    sw   ra, 0(sp)
    addi t0, zero, 1
    sw   t0, FASE(gp)
    sw   zero, TURNO(gp)
    sw   zero, CUR_F(gp)
    sw   zero, CUR_C(gp)
    addi t0, zero, 2
    sw   t0, LEDS(tp)           # LD1: batalla
    addi a0, zero, 1
    jal  ra, texto_fase
    addi a0, zero, 0            # TURNO J1
    addi a1, zero, 0
    jal  ra, texto_mensaje
    jal  ra, dibujar_tablero_j1
    jal  ra, dibujar_tablero_j2
    addi a6, zero, A_B          # #B
    addi a7, zero, 0
    jal  ra, enviar_trama
    addi a6, zero, A_T          # #T1
    addi a7, zero, 1
    addi a1, zero, A_UNO
    jal  ra, enviar_trama
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

# atender_j1_batalla: a0 = pulsaciones, solo en turno del J1.
atender_j1_batalla:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    add  s0, a0, zero
    lw   t0, CUR_F(gp)
    lw   t1, CUR_C(gp)
    andi t2, s0, B_ARRIBA
    beqz t2, ab_abajo
    beqz t0, ab_abajo
    addi t0, t0, -1
ab_abajo:
    andi t2, s0, B_ABAJO
    beqz t2, ab_izq
    slti t3, t0, 7
    beqz t3, ab_izq
    addi t0, t0, 1
ab_izq:
    andi t2, s0, B_IZQ
    beqz t2, ab_der
    beqz t1, ab_der
    addi t1, t1, -1
ab_der:
    andi t2, s0, B_DER
    beqz t2, ab_guardar
    slti t3, t1, 7
    beqz t3, ab_guardar
    addi t1, t1, 1
ab_guardar:
    sw   t0, CUR_F(gp)
    sw   t1, CUR_C(gp)

    andi t2, s0, B_OK
    beqz t2, ab_dibujar
    addi a0, zero, 0
    lw   a1, CUR_F(gp)
    lw   a2, CUR_C(gp)
    jal  ra, procesar_disparo
    beqz a0, ab_dibujar         # casilla repetida: se ignora
    add  a3, a0, zero
    addi a0, zero, 0
    lw   a1, CUR_F(gp)
    lw   a2, CUR_C(gp)
    jal  ra, resultado_disparo
ab_dibujar:
    jal  ra, dibujar_tablero_j2
    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# atender_disparo_j2: trama #D completa (fila, columna en RX_BUF).
atender_disparo_j2:
    addi sp, sp, -4
    sw   ra, 0(sp)
    lw   t0, FASE(gp)
    addi t1, zero, 1
    bne  t0, t1, adj2_fin       # fuera de fase: se descarta
    lw   t0, TURNO(gp)
    bne  t0, t1, adj2_fin       # no es turno del J2: se descarta
    addi a0, zero, 1
    lw   a1, RX_BUF(gp)
    lw   a2, -1396(gp)
    jal  ra, procesar_disparo
    bnez a0, adj2_valido
    addi a6, zero, A_N          # #N f c: repetido, conserva el turno
    addi a7, zero, 2
    lw   a1, RX_BUF(gp)
    addi a1, a1, A_CERO
    lw   a2, -1396(gp)
    addi a2, a2, A_CERO
    jal  ra, enviar_trama
    j    adj2_fin
adj2_valido:
    add  a3, a0, zero
    addi a0, zero, 1
    lw   a1, RX_BUF(gp)
    lw   a2, -1396(gp)
    jal  ra, resultado_disparo
adj2_fin:
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

# procesar_disparo: a0 jugador que dispara, a1 fila, a2 columna.
# Devuelve a0: 0 repetido, 1 fallo, 2 impacto, 3 hundido; a1 = barco.
procesar_disparo:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    add  s0, a0, zero
    xori a0, s0, 1              # tablero del rival
    jal  ra, celda_dir
    lw   t0, 0(a0)
    andi t1, t0, 4
    beqz t1, pd_nuevo
    addi a0, zero, 0            # ya disparada
    j    pd_fin
pd_nuevo:
    ori  t2, t0, 4
    sw   t2, 0(a0)
    slli t2, s0, 2              # disparos del tirador + 1
    add  t2, t2, gp
    lw   t3, DISP_J1(t2)
    addi t3, t3, 1
    sw   t3, DISP_J1(t2)
    andi t1, t0, 3
    bnez t1, pd_impacto
    addi a0, zero, 1            # fallo
    j    pd_fin
pd_impacto:
    addi a1, t1, -1             # barco
    xori t4, s0, 1
    slli t4, t4, 4
    slli t5, a1, 2
    add  t4, t4, t5
    add  t4, t4, gp
    lw   t6, REST_J1(t4)        # casillas restantes del barco rival
    addi t6, t6, -1
    sw   t6, REST_J1(t4)
    addi a0, zero, 2
    bnez t6, pd_fin
    slli t2, s0, 2              # hundidos por el tirador + 1
    add  t2, t2, gp
    lw   t3, HUND_J1(t2)
    addi t3, t3, 1
    sw   t3, HUND_J1(t2)
    addi a0, zero, 3
pd_fin:
    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# resultado_disparo: a0 tirador, a1 fila, a2 columna, a3 resultado
# (1 fallo, 2 impacto, 3 hundido). Sonido, pantalla, UART y cambio de
# turno o fin de partida.
resultado_disparo:
    addi sp, sp, -20
    sw   ra, 16(sp)
    sw   s0, 12(sp)
    sw   s1, 8(sp)
    sw   s2, 4(sp)
    sw   s3, 0(sp)
    add  s0, a0, zero
    add  s1, a1, zero
    add  s2, a2, zero
    add  s3, a3, zero

    # sonido y letra del resultado para la trama
    addi t0, zero, 1
    bne  s3, t0, rd_no_fallo
    addi t1, zero, SND_FALLO
    addi a3, zero, A_F
    j    rd_sonar
rd_no_fallo:
    addi t0, zero, 2
    bne  s3, t0, rd_hundido
    addi t1, zero, SND_IMPACTO
    addi a3, zero, A_I
    j    rd_sonar
rd_hundido:
    addi t1, zero, SND_HUNDIDO
    addi a3, zero, A_H
rd_sonar:
    sw   t1, BUZZER(tp)

    # #R (disparo del J2) o #E (disparo del J1 recibido por el J2)
    addi a6, zero, A_E
    beqz s0, rd_trama
    addi a6, zero, A_R
rd_trama:
    addi a7, zero, 3
    addi a1, s1, A_CERO
    addi a2, s2, A_CERO
    jal  ra, enviar_trama

    beqz s0, rd_dibujar_j2
    jal  ra, dibujar_tablero_j1
    j    rd_victoria
rd_dibujar_j2:
    jal  ra, dibujar_tablero_j2

rd_victoria:
    slli t0, s0, 2
    add  t0, t0, gp
    lw   t1, HUND_J1(t0)
    addi t2, zero, 3
    bne  t1, t2, rd_cambio_turno
    add  a0, s0, zero
    jal  ra, fin_partida
    j    rd_fin

rd_cambio_turno:
    xori t0, s0, 1
    sw   t0, TURNO(gp)
    addi a0, zero, 0            # TURNO Jx
    add  a1, t0, zero
    jal  ra, texto_mensaje
    lw   t0, TURNO(gp)
    addi a1, t0, A_UNO          # #T1 o #T2
    addi a6, zero, A_T
    addi a7, zero, 1
    jal  ra, enviar_trama
    jal  ra, dibujar_tablero_j2
rd_fin:
    lw   s3, 0(sp)
    lw   s2, 4(sp)
    lw   s1, 8(sp)
    lw   s0, 12(sp)
    lw   ra, 16(sp)
    addi sp, sp, 20
    ret

# fin_partida: a0 = ganador (0 J1, 1 J2).
fin_partida:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    add  s0, a0, zero
    addi t0, zero, 2
    sw   t0, FASE(gp)
    sw   s0, GANADOR(gp)
    slli t0, s0, 2              # victorias + 1, maximo 99
    add  t0, t0, gp
    lw   t1, VIC_J1(t0)
    slti t2, t1, 99
    beqz t2, fp_sin_suma
    addi t1, t1, 1
    sw   t1, VIC_J1(t0)
fp_sin_suma:
    addi t0, zero, 4
    sw   t0, LEDS(tp)           # LD2: resultado
    addi t0, zero, SND_VICTORIA
    sw   t0, BUZZER(tp)
    addi a0, zero, 2
    jal  ra, texto_fase
    addi a0, zero, 1            # GANA Jx
    add  a1, s0, zero
    jal  ra, texto_mensaje
    jal  ra, mostrar_victorias
    jal  ra, dibujar_tablero_j2 # quita el cursor

    # #F g d1d1 d2d2 h1 h2
    addi a0, zero, A_NUMERAL
    jal  ra, enviar_car
    addi a0, zero, A_F
    jal  ra, enviar_car
    addi a0, s0, A_UNO
    jal  ra, enviar_car
    lw   a0, DISP_J1(gp)
    jal  ra, enviar_decimal
    lw   a0, -1492(gp)          # DISP_J2
    jal  ra, enviar_decimal
    lw   a0, HUND_J1(gp)
    addi a0, a0, A_CERO
    jal  ra, enviar_car
    lw   a0, -1484(gp)          # HUND_J2
    addi a0, a0, A_CERO
    jal  ra, enviar_car
    addi a0, zero, A_NL
    jal  ra, enviar_car

    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# =====================================================================
# UART
# =====================================================================

# enviar_car: a0 = byte. Espera a que el transmisor este libre, carga
# el dato y lanza el envio. Solo usa a0 y t0.
enviar_car:
    lw   t0, UART_CTRL(tp)
    andi t0, t0, 1
    bnez t0, enviar_car
    sw   a0, UART_TX(tp)
    addi t0, zero, 1
    sw   t0, UART_CTRL(tp)
    ret

# enviar_trama: a6 = letra de tipo, a7 = cantidad de campos (0-5),
# a1-a5 = campos ya en ASCII. Envia '#', tipo, campos y '\n'.
enviar_trama:
    addi sp, sp, -4
    sw   ra, 0(sp)
    addi a0, zero, A_NUMERAL
    jal  ra, enviar_car
    add  a0, a6, zero
    jal  ra, enviar_car
et_campo:
    beqz a7, et_fin
    add  a0, a1, zero
    jal  ra, enviar_car
    add  a1, a2, zero           # correr los campos
    add  a2, a3, zero
    add  a3, a4, zero
    add  a4, a5, zero
    addi a7, a7, -1
    j    et_campo
et_fin:
    addi a0, zero, A_NL
    jal  ra, enviar_car
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

# enviar_decimal: a0 = numero 0-99, se envia como dos digitos ASCII.
enviar_decimal:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    jal  ra, a_decimal
    add  s0, a1, zero
    addi a0, a0, A_CERO
    jal  ra, enviar_car
    addi a0, s0, A_CERO
    jal  ra, enviar_car
    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# uart_recibir: lee un byte si llego y lo pasa al receptor de tramas
# (planteamiento 10.6). Devuelve a0: 0 nada, 1 trama #P completa,
# 2 trama #D completa. Los campos quedan en RX_BUF como numeros
# (orientacion: H = 0, V = 1). Cualquier byte que no calce descarta la
# trama en curso sin tocar el estado del juego.
uart_recibir:
    lw   t0, UART_CTRL(tp)
    andi t0, t0, 2              # new_rx
    beqz t0, ur_nada
    lw   t1, UART_RX(tp)
    andi t1, t1, 0xFF
    addi t0, zero, 2
    sw   t0, UART_CTRL(tp)      # limpiar new_rx

    addi t0, zero, A_NUMERAL    # '#' siempre empieza una trama nueva
    bne  t1, t0, ur_no_inicio
    addi t0, zero, 1
    sw   t0, RX_CNT(gp)
    j    ur_nada

ur_no_inicio:
    lw   t3, RX_CNT(gp)         # caracteres recibidos, incluido '#'
    beqz t3, ur_nada            # fuera de trama: basura
    addi t0, zero, 1
    bne  t3, t0, ur_campo

    # segundo caracter: tipo
    addi t0, zero, A_P
    bne  t1, t0, ur_tipo_d
    addi t4, zero, 6
    j    ur_tipo_ok
ur_tipo_d:
    addi t0, zero, A_D
    bne  t1, t0, ur_descartar
    addi t4, zero, 4
ur_tipo_ok:
    sw   t4, RX_LEN(gp)
    addi t3, t3, 1
    sw   t3, RX_CNT(gp)
    j    ur_nada

ur_campo:
    lw   t4, RX_LEN(gp)
    addi t5, t1, -48            # valor si es un digito
    addi t0, zero, 6
    bne  t4, t0, ur_num8        # #D: fila y columna 0-7
    addi t0, zero, 2
    bne  t3, t0, ur_p_no_barco
    sltiu t0, t5, 3             # barco 0-2
    beqz t0, ur_descartar
    j    ur_guardar
ur_p_no_barco:
    addi t0, zero, 5
    bne  t3, t0, ur_num8
    addi t0, zero, A_H          # orientacion
    addi t5, zero, 0
    beq  t1, t0, ur_guardar
    addi t0, zero, A_V
    addi t5, zero, 1
    beq  t1, t0, ur_guardar
    j    ur_descartar
ur_num8:
    sltiu t0, t5, 8
    beqz t0, ur_descartar

ur_guardar:
    addi t0, t3, -2             # campo = posicion - 2
    slli t0, t0, 2
    add  t0, t0, gp
    sw   t5, RX_BUF(t0)
    addi t3, t3, 1
    sw   t3, RX_CNT(gp)
    bne  t3, t4, ur_nada
    sw   zero, RX_CNT(gp)       # trama completa
    addi a0, zero, 1
    addi t0, zero, 6
    beq  t4, t0, ur_fin
    addi a0, zero, 2
    ret
ur_descartar:
    sw   zero, RX_CNT(gp)
ur_nada:
    addi a0, zero, 0
ur_fin:
    ret

# =====================================================================
# Pantalla (planteamiento 9)
# =====================================================================

# tile_dir: a0 fila, a1 columna -> a0 direccion del tile.
tile_dir:
    slli t0, a0, 4
    slli t1, a0, 2
    add  t0, t0, t1             # fila * 20
    add  t0, t0, a1
    slli t0, t0, 2
    addi t1, zero, 0x11
    slli t1, t1, 12
    add  a0, t0, t1
    ret

# simbolo: a0 = indice del tile, a1 = codigo, a2 = color del simbolo.
# Escribe el simbolo sobre fondo negro y deja a0 en el tile siguiente.
simbolo:
    slli t0, a0, 2
    addi t1, zero, 0x11
    slli t1, t1, 12
    add  t0, t0, t1
    slli t2, a2, 9
    slli t3, a1, 3
    or   t2, t2, t3
    sw   t2, 0(t0)
    addi a0, a0, 1
    ret

# limpiar_tiles: a0 = primer indice, a1 = cantidad.
limpiar_tiles:
    slli t0, a0, 2
    addi t1, zero, 0x11
    slli t1, t1, 12
    add  t0, t0, t1
lt_lazo:
    sw   zero, 0(t0)
    addi t0, t0, 4
    addi a1, a1, -1
    bnez a1, lt_lazo
    ret

# dibujar_hud_fijo: "J1:" y "J2:" (fila 0), titulos de los tableros
# (fila 3), numeros de columna (fila 4) y de fila (columnas 0 y 10).
dibujar_hud_fijo:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    addi a2, zero, C_BLANCO

    addi a0, zero, 1            # fila 0: J1:
    addi a1, zero, S_J
    jal  ra, simbolo
    addi a1, zero, 2
    jal  ra, simbolo
    addi a1, zero, S_DOSP
    jal  ra, simbolo
    addi a0, zero, 7            # J2:
    addi a1, zero, S_J
    jal  ra, simbolo
    addi a1, zero, 3
    jal  ra, simbolo
    addi a1, zero, S_DOSP
    jal  ra, simbolo

    addi a0, zero, 61           # fila 3: J1 sobre el tablero propio
    addi a1, zero, S_J
    jal  ra, simbolo
    addi a1, zero, 2
    jal  ra, simbolo
    addi a0, zero, 71           # J2 sobre el tablero rival
    addi a1, zero, S_J
    jal  ra, simbolo
    addi a1, zero, 3
    jal  ra, simbolo

    addi s0, zero, 0            # numeros de 0 a 7
hf_lazo:
    addi a0, s0, 81             # fila 4, columnas 1-8
    addi a1, s0, 1
    jal  ra, simbolo
    addi a0, s0, 91             # fila 4, columnas 11-18
    addi a1, s0, 1
    jal  ra, simbolo
    slli t0, s0, 4              # filas 5-12: indice 100 + 20 f
    slli t1, s0, 2
    add  t0, t0, t1
    addi a0, t0, 100            # columna 0
    addi a1, s0, 1
    jal  ra, simbolo
    addi a0, a0, 9              # columna 10
    addi a1, s0, 1
    jal  ra, simbolo
    addi s0, s0, 1
    addi t0, zero, 8
    bne  s0, t0, hf_lazo

    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# texto_fase: a0 = fase. Fila 1: COLOCAR, BATALLA o FIN en amarillo.
texto_fase:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    add  s0, a0, zero
    addi a0, zero, 21
    addi a1, zero, 7
    jal  ra, limpiar_tiles
    addi a0, zero, 21
    addi a2, zero, C_AMARILLO
    beqz s0, tf_colocar
    addi t0, zero, 1
    beq  s0, t0, tf_batalla
    addi a1, zero, S_F          # FIN
    jal  ra, simbolo
    addi a1, zero, S_I
    jal  ra, simbolo
    addi a1, zero, S_N
    jal  ra, simbolo
    j    tf_fin
tf_colocar:
    addi a1, zero, S_C
    jal  ra, simbolo
    addi a1, zero, S_O
    jal  ra, simbolo
    addi a1, zero, S_L
    jal  ra, simbolo
    addi a1, zero, S_O
    jal  ra, simbolo
    addi a1, zero, S_C
    jal  ra, simbolo
    addi a1, zero, S_A
    jal  ra, simbolo
    addi a1, zero, S_R
    jal  ra, simbolo
    j    tf_fin
tf_batalla:
    addi a1, zero, S_B
    jal  ra, simbolo
    addi a1, zero, S_A
    jal  ra, simbolo
    addi a1, zero, S_T
    jal  ra, simbolo
    addi a1, zero, S_A
    jal  ra, simbolo
    addi a1, zero, S_L
    jal  ra, simbolo
    addi a1, zero, S_L
    jal  ra, simbolo
    addi a1, zero, S_A
    jal  ra, simbolo
tf_fin:
    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# texto_mensaje: a0 = 0 "TURNO" / 1 "GANA", a1 = jugador (0 J1, 1 J2).
# Fila 14, desde la columna 1.
texto_mensaje:
    addi sp, sp, -12
    sw   ra, 8(sp)
    sw   s0, 4(sp)
    sw   s1, 0(sp)
    add  s0, a0, zero
    add  s1, a1, zero
    addi a0, zero, 281
    addi a1, zero, 8
    jal  ra, limpiar_tiles
    addi a0, zero, 281
    addi a2, zero, C_BLANCO
    bnez s0, tm_gana
    addi a1, zero, S_T
    jal  ra, simbolo
    addi a1, zero, S_U
    jal  ra, simbolo
    addi a1, zero, S_R
    jal  ra, simbolo
    addi a1, zero, S_N
    jal  ra, simbolo
    addi a1, zero, S_O
    jal  ra, simbolo
    j    tm_jugador
tm_gana:
    addi a1, zero, S_G
    jal  ra, simbolo
    addi a1, zero, S_A
    jal  ra, simbolo
    addi a1, zero, S_N
    jal  ra, simbolo
    addi a1, zero, S_A
    jal  ra, simbolo
tm_jugador:
    addi a0, a0, 1              # un espacio
    addi a1, zero, S_J
    jal  ra, simbolo
    addi a1, s1, 2              # digito 1 o 2
    jal  ra, simbolo
    lw   s1, 0(sp)
    lw   s0, 4(sp)
    lw   ra, 8(sp)
    addi sp, sp, 12
    ret

# mostrar_victorias: displays (J1 en [15:8], J2 en [7:0], BCD) y fila 0
# de la pantalla (tiles 4-5 para J1 y 10-11 para J2).
mostrar_victorias:
    addi sp, sp, -12
    sw   ra, 8(sp)
    sw   s0, 4(sp)
    sw   s1, 0(sp)
    lw   a0, VIC_J1(gp)
    jal  ra, a_decimal
    slli s0, a0, 12             # decenas J1 en [15:12]
    slli t0, a1, 8
    or   s0, s0, t0             # unidades J1 en [11:8]
    add  s1, a1, zero
    addi a1, a0, 1
    addi a0, zero, 4
    addi a2, zero, C_BLANCO
    jal  ra, simbolo
    addi a1, s1, 1
    jal  ra, simbolo

    lw   a0, VIC_J2(gp)
    jal  ra, a_decimal
    slli t0, a0, 4
    or   s0, s0, t0             # decenas J2 en [7:4]
    or   s0, s0, a1             # unidades J2 en [3:0]
    add  s1, a1, zero
    addi a1, a0, 1
    addi a0, zero, 10
    addi a2, zero, C_BLANCO
    jal  ra, simbolo
    addi a1, s1, 1
    jal  ra, simbolo
    sw   s0, DISPLAYS(tp)
    lw   s1, 0(sp)
    lw   s0, 4(sp)
    lw   ra, 8(sp)
    addi sp, sp, 12
    ret

# a_decimal: a0 = numero 0-99 -> a0 decenas, a1 unidades.
# El procesador no divide: restas sucesivas de 10.
a_decimal:
    add  a1, a0, zero
    addi a0, zero, 0
ad_lazo:
    slti t0, a1, 10
    bnez t0, ad_fin
    addi a1, a1, -10
    addi a0, a0, 1
    j    ad_lazo
ad_fin:
    ret

# color_propio: a0 = casilla -> a0 color para su dueno.
color_propio:
    andi t0, a0, 4
    andi t1, a0, 3
    beqz t0, cp_sin_disparo
    addi a0, zero, C_FALLO
    beqz t1, cp_fin
    addi a0, zero, C_IMPACTO
    ret
cp_sin_disparo:
    addi a0, zero, C_AGUA
    beqz t1, cp_fin
    addi a0, zero, C_BARCO
cp_fin:
    ret

# color_rival: a0 = casilla -> a0 color visto por el rival: nunca
# muestra un barco no descubierto.
color_rival:
    andi t0, a0, 4
    andi t1, a0, 3
    addi a0, zero, C_AGUA
    beqz t0, cr_fin
    addi a0, zero, C_FALLO
    beqz t1, cr_fin
    addi a0, zero, C_IMPACTO
cr_fin:
    ret

# dibujar_tablero_j1: tablero propio del J1 (izquierda) con sus barcos
# y los disparos recibidos. Durante su colocacion agrega la vista
# previa del barco actual (verde) con el cursor en la primera casilla.
# Recorre la RAM y la memoria de video con punteros para que el
# redibujado sea corto y el lazo principal vuelva pronto a leer el UART.
dibujar_tablero_j1:
    addi sp, sp, -20
    sw   ra, 16(sp)
    sw   s0, 12(sp)
    sw   s1, 8(sp)
    sw   s2, 4(sp)
    sw   s3, 0(sp)
    addi s0, gp, TAB_J1         # puntero a la casilla (0,0) del J1
    addi a0, zero, 5
    addi a1, zero, 1
    jal  ra, tile_dir
    add  s1, a0, zero           # puntero al tile (5,1)
    addi s2, zero, 8            # filas restantes
dj1_fila:
    addi s3, zero, 8            # columnas restantes
dj1_col:
    lw   a0, 0(s0)
    jal  ra, color_propio
    sw   a0, 0(s1)
    addi s0, s0, 4
    addi s1, s1, 4
    addi s3, s3, -1
    bnez s3, dj1_col
    addi s1, s1, 48             # siguiente fila de tiles: 12 tiles mas
    addi s2, s2, -1
    bnez s2, dj1_fila

    # vista previa: solo en colocacion y si faltan barcos del J1
    lw   t0, FASE(gp)
    bnez t0, dj1_fin
    lw   t0, COLOC_J1(gp)
    addi t1, zero, 7
    beq  t0, t1, dj1_fin
    lw   s0, CUR_F(gp)
    lw   s1, CUR_C(gp)
    lw   t0, CUR_BARCO(gp)
    addi s2, zero, 4
    sub  s2, s2, t0             # largo del barco
    addi s3, zero, 0x105        # primera casilla: verde con cursor
dj1_previa:
    slti t0, s0, 8
    beqz t0, dj1_fin            # se sale del tablero: no se dibuja
    slti t0, s1, 8
    beqz t0, dj1_fin
    addi a0, s0, 5
    addi a1, s1, 1
    jal  ra, tile_dir
    sw   s3, 0(a0)
    addi s3, zero, C_PREVIA
    lw   t0, CUR_OR(gp)
    beqz t0, dj1_prev_h
    addi s0, s0, 1
    j    dj1_prev_sig
dj1_prev_h:
    addi s1, s1, 1
dj1_prev_sig:
    addi s2, s2, -1
    bnez s2, dj1_previa
dj1_fin:
    lw   s3, 0(sp)
    lw   s2, 4(sp)
    lw   s1, 8(sp)
    lw   s0, 12(sp)
    lw   ra, 16(sp)
    addi sp, sp, 20
    ret

# dibujar_tablero_j2: vista del J1 sobre el tablero del J2 (derecha):
# solo agua, impactos y fallos. En su turno de batalla muestra el
# cursor del J1.
dibujar_tablero_j2:
    addi sp, sp, -20
    sw   ra, 16(sp)
    sw   s0, 12(sp)
    sw   s1, 8(sp)
    sw   s2, 4(sp)
    sw   s3, 0(sp)
    addi s0, gp, TAB_J2         # puntero a la casilla (0,0) del J2
    addi a0, zero, 5
    addi a1, zero, 11
    jal  ra, tile_dir
    add  s1, a0, zero           # puntero al tile (5,11)
    addi s2, zero, 8
dj2_fila:
    addi s3, zero, 8
dj2_col:
    lw   a0, 0(s0)
    jal  ra, color_rival
    sw   a0, 0(s1)
    addi s0, s0, 4
    addi s1, s1, 4
    addi s3, s3, -1
    bnez s3, dj2_col
    addi s1, s1, 48
    addi s2, s2, -1
    bnez s2, dj2_fila

    lw   t0, FASE(gp)
    addi t1, zero, 1
    bne  t0, t1, dj2_fin
    lw   t0, TURNO(gp)
    bnez t0, dj2_fin
    lw   a0, CUR_F(gp)
    addi a0, a0, 5
    lw   a1, CUR_C(gp)
    addi a1, a1, 11
    jal  ra, tile_dir
    lw   t0, 0(a0)
    ori  t0, t0, 0x100          # marco del cursor
    sw   t0, 0(a0)
dj2_fin:
    lw   s3, 0(sp)
    lw   s2, 4(sp)
    lw   s1, 8(sp)
    lw   s0, 12(sp)
    lw   ra, 16(sp)
    addi sp, sp, 20
    ret
