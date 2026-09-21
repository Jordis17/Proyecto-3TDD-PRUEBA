"""Prueba autoverificable del programa del juego (batalla_naval.s).

Juega dos partidas completas sobre el simulador de instrucciones
(iss.py), haciendo de Jugador 1 (botones) y de Jugador 2 (tramas UART),
y revisa: colocacion concurrente, rechazos, tramas basura, disparos,
turnos, disparos repetidos, privacidad en VGA, hundidos, victoria,
resumen final y BTN_RST.

Uso:
    python3 prueba_juego.py ../../FPGA/DESIGN/programa.mem [carpeta]
Si se indica una carpeta, guarda ahi imagenes de la pantalla.
"""
import sys
from iss import Sistema, Error
from pantalla import dibujar
FIG = sys.argv[2] if len(sys.argv) > 2 else None
def foto(nombre):
    if FIG: dibujar(s.vmem, f'{FIG}/{nombre}.png')

ARR, ABA, IZQ, DER, SEL, OK, RST = 1, 2, 4, 8, 16, 32, 64
fallos = 0
def chequear(nombre, cond, extra=''):
    global fallos
    print(('PASS ' if cond else 'FAIL ') + nombre + (f'  [{extra}]' if extra else ''))
    if not cond: fallos += 1

def celda(s, j, f, c): return s.ram_w(0x2000 + j * 256 + (f * 8 + c) * 4)
def tile(s, f, c): return s.vmem[f * 20 + c]
def texto(s, fila, c0, n):
    t = ''
    m = {0: ' ', 24: ':'}
    for i in range(n):
        code = (tile(s, fila, c0 + i) >> 3) & 31
        if 1 <= code <= 10: t += str(code - 1)
        elif code in m: t += m[code]
        else: t += 'ABCFGIJLNORTU'[code - 11] if 11 <= code <= 23 else '?'
    return t

s = Sistema(sys.argv[1])
s.correr(200000)
r = s.esperar_linea('#C')
chequear('al arrancar envia #C', r == '#C' and s.sin_lineas_nuevas(), s.lineas)
chequear('LED de colocacion (LD0)', s.leds == 1)
chequear('HUD fase COLOCAR', texto(s, 1, 1, 7) == 'COLOCAR', texto(s, 1, 1, 7))
chequear('HUD victorias J1:00 J2:00', texto(s, 0, 1, 11) == 'J1:00 J2:00', texto(s, 0, 1, 11))
chequear('displays en 0000', s.displays == 0)

# ---- colocacion concurrente ----
s.pc_envia('#P000H')                       # J2 barco 0 en fila 0, H
s.presionar(OK)                            # J1 barco 0 en (0,0) H, mientras llega la trama
r = s.esperar_linea('#A0')
chequear('J2 barco 0 aceptado', r == '#A0', r)
chequear('J1 barco 0 colocado en (0,0)-(0,3)', all(celda(s, 0, 0, c) == 1 for c in range(4)) and celda(s, 0, 0, 4) == 0)

s.pc_envia('#P100V')                       # traslapa con el barco 0 en (0,0)
r = s.esperar_linea('#X12'); chequear('J2 traslape -> #X12', r == '#X12', r)
s.pc_envia('#P167V')                       # barco de 3 desde fila 6 vertical: se sale
r = s.esperar_linea('#X11'); chequear('J2 fuera del tablero -> #X11', r == '#X11', r)
s.pc_envia('#P055H')                       # barco 0 otra vez
r = s.esperar_linea('#X03'); chequear('J2 barco repetido -> #X03', r == '#X03', r)

# basura y tramas malformadas: ninguna respuesta ni cambio de estado
antes = list(s.ram[:128])
s.pc_envia('hola\r\n#Q12#P9#P08xH#D33#P3#P0')   # termina con una trama incompleta
s.pc_envia('#P1')                          # otra trama incompleta
s.correr(40 * 4340 + 50000)
chequear('basura no genera respuesta', s.sin_lineas_nuevas(), s.lineas[s.leidas:])
chequear('basura no cambia los tableros', s.ram[:128] == antes)
s.pc_envia('#P120H')                       # trama valida tras la basura
r = s.esperar_linea('#A1'); chequear('trama valida despues de basura -> #A1', r == '#A1', r)

# J1: intenta el barco 1 encima del barco 0 (invalido) y luego lo baja
nson = len(s.sonidos)
s.presionar(OK)
chequear('J1 colocacion invalida suena (evento 4)', s.sonidos[nson:] == [(s.sonidos[-1][0], 4)] if len(s.sonidos) > nson else False)
chequear('J1 invalida no escribe el tablero', celda(s, 0, 0, 0) == 1 and celda(s, 0, 1, 0) == 0)
s.entradas ^= SEL; s.correr(30000)        # switch: vertical
s.presionar(ABA); s.presionar(ABA)         # fila 2
foto('1_colocacion_vista_previa')
s.presionar(OK)                            # barco 1 vertical (2,0)-(4,0)
chequear('J1 barco 1 vertical en (2,0)-(4,0)', [celda(s, 0, f, 0) for f in range(2, 5)] == [2, 2, 2] and celda(s, 0, 5, 0) == 0)
s.entradas ^= SEL; s.correr(30000)        # horizontal
for _ in range(7): s.presionar(DER)        # columna 7 (tope)
chequear('cursor no pasa de la columna 7', s.ram_w(0x2244) == 7)
s.presionar(OK)                            # barco 2 en (2,7) H: se sale
chequear('J1 barco que se sale: rechazado', s.sonidos[-1][1] == 4 and s.ram_w(0x220C) == 3)
s.presionar(IZQ); s.presionar(OK)          # (2,6)-(2,7)
chequear('J1 barco 2 en (2,6)-(2,7)', celda(s, 0, 2, 6) == 3 and celda(s, 0, 2, 7) == 3)
chequear('J1 termino: mascara 7', s.ram_w(0x220C) == 7)
chequear('aun en colocacion (falta J2)', s.ram_w(0x2220) == 0)

s.pc_envia('#P240H')
r = s.esperar_linea('#A2'); chequear('J2 barco 2 aceptado', r == '#A2', r)
r1 = s.esperar_linea('#B'); r2 = s.esperar_linea('#T1')
chequear('inicio de batalla: #B y #T1', (r1, r2) == ('#B', '#T1'), (r1, r2))
chequear('LED de batalla (LD1)', s.leds == 2)
foto('2_inicio_batalla')
chequear('HUD BATALLA y TURNO J1', texto(s, 1, 1, 7) == 'BATALLA' and texto(s, 14, 1, 8) == 'TURNO J1', texto(s, 14, 1, 8))

# privacidad: la vista del J1 sobre el tablero J2 no muestra barcos
priv = all((tile(s, 5 + f, 11 + c) & 7) == 1 for f in range(8) for c in range(8))
chequear('tablero rival en VGA: solo agua (barcos ocultos)', priv)
chequear('tablero propio en VGA: barco en gris', tile(s, 5, 1) & 7 == 2)

# J2 dispara fuera de turno: se descarta
s.pc_envia('#D00'); s.correr(8 * 4340)
chequear('#D fuera de turno se descarta', s.sin_lineas_nuevas() and celda(s, 0, 0, 0) == 1)

# ---- batalla: J1 hunde los barcos de J2; J2 falla ----
objetivos = [(0, 0), (0, 1), (0, 2), (0, 3), (2, 0), (2, 1), (2, 2), (4, 0), (4, 1)]
disparos_j2 = [(7, 7), (7, 6), (7, 5), (7, 4), (6, 7), (6, 6), (6, 5), (6, 4)]
cur = [0, 0]
def mover_a(f, c):
    while cur[0] < f: s.presionar(ABA); cur[0] += 1
    while cur[0] > f: s.presionar(ARR); cur[0] -= 1
    while cur[1] < c: s.presionar(DER); cur[1] += 1
    while cur[1] > c: s.presionar(IZQ); cur[1] -= 1

resultados = []
for k, (f, c) in enumerate(objetivos):
    mover_a(f, c)
    s.presionar(OK)
    r = s.esperar_linea('#E'); resultados.append(r)
    if k == len(objetivos) - 1: break
    t = s.esperar_linea('#T2')
    if k == 0:
        chequear('cursor visible solo en turno J1', all((tile(s, 5 + a, 11 + b) >> 8) & 1 == 0 for a in range(8) for b in range(8)))
        # disparo del J1 fuera de su turno: no hace nada
        s.presionar(OK)
        chequear('OK del J1 en turno del J2 no dispara', s.ram_w(0x2228) == 1)
    fj, cj = disparos_j2[k]
    s.pc_envia(f'#D{fj}{cj}')
    r = s.esperar_linea('#R')
    chequear(f'J2 dispara ({fj},{cj}): fallo', r == f'#R{fj}{cj}F', r)
    if k == 1:
        s.esperar_linea('#T1')
        mover_a(0, 1); s.presionar(OK)     # J1 repite (0,1): se ignora
        chequear('J1 repite casilla: se ignora y sigue su turno', s.ram_w(0x2224) == 0 and s.ram_w(0x2228) == 2)
        continue
    s.esperar_linea('#T1')
    if k == 5:
        foto('3_batalla_avanzada')

esperado = ['#E00I', '#E01I', '#E02I', '#E03H', '#E20I', '#E21I', '#E22H', '#E40I', '#E41H']
chequear('resultados de disparos del J1 (#E)', resultados == esperado, resultados)
fin = s.esperar_linea('#F')
chequear('resumen final #F: gana J1, 09 y 08 disparos, 3 y 0 hundidos', fin == '#F1090830', fin)
chequear('fase fin y LED LD2', s.ram_w(0x2220) == 2 and s.leds == 4)
chequear('victorias 01-00 en displays', s.displays == 0x0100, hex(s.displays))
chequear('HUD FIN, GANA J1 y J1:01', texto(s, 1, 1, 3) == 'FIN' and texto(s, 14, 1, 7) == 'GANA J1' and texto(s, 0, 1, 11) == 'J1:01 J2:00')
chequear('ultimo sonido: victoria', s.sonidos[-1][1] == 5)
foto('4_fin_gana_j1')
son = [e for _, e in s.sonidos]
chequear('sonidos de impacto (1) y hundido (3) durante la partida', 1 in son and 3 in son)

# en fin de partida no se acepta nada
s.pc_envia('#D55'); s.presionar(OK); s.correr(8 * 4340)
chequear('en fin de partida se ignoran disparos', s.sin_lineas_nuevas())

# ---- BTN_RST: nueva partida conservando victorias ----
s.presionar(RST, mantener=200000)
r = s.esperar_linea('#C')
chequear('BTN_RST: nueva colocacion y #C', r == '#C' and s.ram_w(0x2220) == 0 and s.leds == 1)
chequear('BTN_RST conserva victorias', s.ram_w(0x2F00) == 1 and s.displays == 0x0100)
chequear('BTN_RST limpia los tableros', all(v == 0 for v in s.ram[:128]))

# ---- partida 2: gana el J2 y se prueba el disparo repetido del J2 ----
for t in ('#P000H', '#P110H', '#P220H'):
    s.pc_envia(t); s.esperar_linea('#A')
cur[:] = [0, 0]
s.presionar(OK); s.presionar(ABA); s.presionar(OK); s.presionar(ABA); s.presionar(OK)
s.esperar_linea('#B'); s.esperar_linea('#T1')
objetivos_j2 = [(0, 0), (0, 1), (0, 2), (0, 3), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1)]
j1_agua = [(7, c) for c in range(8)] + [(6, 0)]
ok_rep = False
for k, (f, c) in enumerate(objetivos_j2):
    mover_a(*j1_agua[k]); s.presionar(OK)
    s.esperar_linea('#E'); s.esperar_linea('#T2')
    if k == 3:
        s.pc_envia('#D00')                 # repetido
        r = s.esperar_linea('#N')
        ok_rep = (r == '#N00')
    s.pc_envia(f'#D{f}{c}')
    r = s.esperar_linea('#R')
    if k < 8: s.esperar_linea('#T1')
chequear('J2 repite casilla: #N00 y conserva el turno', ok_rep)
fin = s.esperar_linea('#F')
chequear('partida 2: gana J2 con resumen #F2090903', fin == '#F2090903', fin)
chequear('victorias 01-01 en displays y HUD', s.displays == 0x0101 and texto(s, 0, 1, 11) == 'J1:01 J2:01', hex(s.displays))

chequear('ningun byte perdido en recepcion', s.rx_perdidos == 0, s.rx_perdidos)
print(f'instrucciones ejecutadas: {s.ciclo}')
print('RESULTADO: PASS' if fallos == 0 else f'RESULTADO: FAIL ({fallos} errores)')
