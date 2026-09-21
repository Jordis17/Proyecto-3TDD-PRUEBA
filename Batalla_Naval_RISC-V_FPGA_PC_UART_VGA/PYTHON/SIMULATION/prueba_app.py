"""Prueba autoverificable de la aplicacion del Jugador 2.

1. Pruebas unitarias del protocolo y de la validacion de entradas.
2. Partida completa: la logica de la aplicacion (ClienteJ2) juega contra
   el programa real de la FPGA (programa.mem) ejecutado en el simulador
   de instrucciones de ASSEMBLY/SIMULATION, que ademas hace de Jugador 1.

Uso:
    python3 prueba_app.py ../../FPGA/DESIGN/programa.mem
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, '..', 'DESIGN'))
sys.path.insert(0, os.path.join(AQUI, '..', '..', 'ASSEMBLY', 'SIMULATION'))

from protocolo import interpretar, leer_casilla, leer_colocacion   # noqa: E402
from cliente import ClienteJ2, BARCO, IMPACTO, FALLO, AGUA          # noqa: E402
from iss import Sistema                                               # noqa: E402

fallos = 0


def chequear(nombre, cond, extra=''):
    global fallos
    print(('PASS ' if cond else 'FAIL ') + nombre + (f'  [{extra}]' if extra else ''))
    if not cond:
        fallos += 1


# ---------------- 1. unitarias ----------------
chequear('interpreta #A1', interpretar('#A1') == ('A', {'barco': 1}))
chequear('interpreta #X02', interpretar('#X02') == ('X', {'barco': 0, 'motivo': 2}))
chequear('interpreta #E34H', interpretar('#E34H') == ('E', {'fila': 3, 'col': 4, 'res': 'H'}))
chequear('interpreta #F1090830', interpretar('#F1090830')[1]['disparos_j1'] == 9)
for mala in ['', 'hola', '#', '#Z', '#A3', '#X05', '#T3', '#E88F', '#E12Q', '#F12', '#C1']:
    chequear(f'rechaza la linea {mala!r}', interpretar(mala) is None)
chequear('casilla "3 4"', leer_casilla('3 4') == ((3, 4), None))
chequear('casilla "3,4"', leer_casilla('3,4') == ((3, 4), None))
for mala in ['8 1', '1 9', 'a b', '345', '', '-1 2']:
    chequear(f'casilla invalida {mala!r}', leer_casilla(mala)[0] is None)
chequear('colocacion "3 4 h"', leer_colocacion('3 4 h') == ((3, 4, 'H'), None))
for mala in ['3 4', '3 4 X', '8 0 H', '34HV', 'HHH']:
    chequear(f'colocacion invalida {mala!r}', leer_colocacion(mala)[0] is None)

# ---------------- 2. partida contra el programa real ----------------
s = Sistema(sys.argv[1])
app = ClienteJ2()
enviadas = []


def atender(ciclos=0):
    """Corre la FPGA y entrega a la app las lineas nuevas."""
    s.correr(ciclos)
    while not s.sin_lineas_nuevas():
        app.procesar(s.esperar_linea(''))


def usuario(texto, esperar=True):
    """El usuario escribe texto; si es valido se envia y se espera respuesta."""
    trama, error = app.entrada(texto)
    if error:
        return error
    enviadas.append(trama)
    s.pc_envia(trama)
    if esperar:
        while app.esperando:
            atender(5000)
    return None


atender(200000)
chequear('la app recibe #C y pide colocar el barco 0', app.que_pedir() == 'colocar' and app.barco == 0)
chequear('entrada mal escrita no se envia', usuario('3 4') is not None and not enviadas)
chequear('fila fuera de rango no se envia', usuario('9 0 H') is not None and not enviadas)
usuario('0 0 V')
chequear('barco 0 aceptado y dibujado en su tablero', app.barco == 1 and
         all(app.propio[f][0] == BARCO for f in range(4)))
usuario('1 0 H')                     # traslapa: la FPGA lo rechaza
chequear('rechazo de la FPGA: sigue pidiendo el barco 1', app.barco == 1 and app.que_pedir() == 'colocar')
chequear('el rechazo no dibuja nada', app.propio[1][1] == AGUA)
usuario('0 5 V')
usuario('7 6 H')
chequear('tres barcos colocados, la app espera', app.barco == 3 and app.que_pedir() is None)

# Jugador 1 coloca con los botones (lo hace el simulador)
OK, ABA = 32, 2
s.presionar(OK)                      # (0,0) H
s.presionar(ABA); s.presionar(ABA); s.presionar(OK)      # (2,0) H
s.presionar(ABA); s.presionar(ABA); s.presionar(OK)      # (4,0) H
atender(100000)
chequear('la app recibe #B y el turno del J1', app.fase == 'batalla' and app.turno == 1)

# batalla: J1 hunde los barcos del J2, J2 dispara al agua
objetivos_j1 = [(f, 0) for f in range(4)] + [(f, 5) for f in range(3)] + [(7, 6), (7, 7)]
cur = [0, 0]


def mover_j1(f, c):
    teclas = {(1, 0): 2, (-1, 0): 1, (0, 1): 8, (0, -1): 4}
    while cur[0] != f:
        paso = 1 if f > cur[0] else -1
        s.presionar(teclas[(paso, 0)]); cur[0] += paso
    while cur[1] != c:
        paso = 1 if c > cur[1] else -1
        s.presionar(teclas[(0, paso)]); cur[1] += paso


disparos_j2 = [(6, c) for c in range(8)]
repetido_ok = False
for k, (f, c) in enumerate(objetivos_j1):
    mover_j1(f, c)
    s.presionar(OK)
    atender(50000)
    if app.fase == 'fin':
        break
    chequear(f'disparo {k + 1} del J1 llega a la app', app.propio[f][c] == IMPACTO and app.turno == 2)
    if k == 1:
        usuario('6 0')               # ya atacada en el turno anterior
        repetido_ok = app.que_pedir() == 'disparar'
        chequear('casilla repetida: la app vuelve a pedir disparo (#N)', repetido_ok)
        usuario('6 1')
    else:
        usuario(f'{disparos_j2[k][0]} {disparos_j2[k][1]}')
    while app.turno != 1:
        atender(5000)

chequear('la app registra sus fallos en el tablero rival', app.rival[6][0] == FALLO)
chequear('la app nunca vio barcos del J1', all(x in '.oX' for fila in app.rival for x in fila))
chequear('fin de partida: gano el J1', app.fase == 'fin' and app.resumen['ganador'] == 1,
         app.resumen)
chequear('resumen: 9 disparos del J1, 3 hundidos por el J1',
         app.resumen['disparos_j1'] == 9 and app.resumen['hundidos_j1'] == 3)
chequear('la app no pide nada al terminar', app.que_pedir() is None)

# BTN_RST en la FPGA: la app reinicia su vista
s.presionar(64, mantener=200000)
atender(100000)
chequear('BTN_RST: la app reinicia y pide colocar de nuevo',
         app.fase == 'colocacion' and app.barco == 0 and app.propio[0][0] == AGUA)

chequear('ningun byte perdido en la FPGA', s.rx_perdidos == 0)
print('tramas enviadas por la app:', ' '.join(enviadas))
print('RESULTADO: PASS' if fallos == 0 else f'RESULTADO: FAIL ({fallos} errores)')
