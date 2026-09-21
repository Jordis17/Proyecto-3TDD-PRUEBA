"""Estado de la terminal del Jugador 2.

Lleva la vista que el Jugador 2 tiene de la partida y decide cuando
pedirle datos al usuario, siempre a partir de los mensajes de la FPGA.
No valida reglas del juego (traslapes, impactos, turnos, victoria):
solo el formato y el rango de lo que escribe el usuario.

No usa el puerto serie, asi se puede probar sin la tarjeta.
"""
from protocolo import (interpretar, trama_colocacion, trama_disparo, leer_casilla,
                       leer_colocacion, MOTIVOS, RESULTADOS, LARGOS)

AGUA, BARCO, IMPACTO, FALLO = '~', 'B', 'X', 'o'
DESCONOCIDO = '.'


class ClienteJ2:
    def __init__(self):
        self.reiniciar()
        self.conectado = False        # True al recibir el primer #C

    def reiniciar(self):
        self.propio = [[AGUA] * 8 for _ in range(8)]
        self.rival = [[DESCONOCIDO] * 8 for _ in range(8)]
        self.fase = 'espera'          # espera, colocacion, batalla, fin
        self.barco = 0                # barco que toca colocar
        self.pendiente = None         # colocacion enviada sin respuesta
        self.turno = None
        self.esperando = False        # se envio algo y falta la respuesta
        self.resumen = None

    # ------------------------------------------------------------------
    def procesar(self, linea):
        """Aplica una linea recibida. Devuelve mensajes para mostrar."""
        m = interpretar(linea)
        if m is None:
            return []                 # lo que no es una trama valida se ignora
        tipo, d = m
        if tipo == 'C':
            self.reiniciar()
            self.conectado = True
            self.fase = 'colocacion'
            return ['Nueva partida: coloque sus barcos.']
        if tipo == 'A' and self.pendiente and d['barco'] == self.pendiente[0]:
            b, f, c, o = self.pendiente
            for k in range(LARGOS[b]):
                self.propio[f + k * (o == 'V')][c + k * (o == 'H')] = BARCO
            self.pendiente, self.esperando = None, False
            self.barco += 1
            if self.barco == 3:
                return ['Barco aceptado. Esperando a que el Jugador 1 termine de colocar.']
            return ['Barco aceptado.']
        if tipo == 'X' and self.pendiente:
            self.pendiente, self.esperando = None, False
            return [f'Colocacion rechazada: {MOTIVOS[d["motivo"]]}. Intente de nuevo.']
        if tipo == 'B':
            self.fase = 'batalla'
            return ['Comienza la batalla.']
        if tipo == 'T':
            self.turno = d['jugador']
            self.esperando = False
            return ['Su turno: dispare.' if self.turno == 2 else 'Turno del Jugador 1.']
        if tipo == 'R':
            self.rival[d['fila']][d['col']] = FALLO if d['res'] == 'F' else IMPACTO
            return [f'Su disparo a ({d["fila"]},{d["col"]}): {RESULTADOS[d["res"]]}.']
        if tipo == 'N':
            self.esperando = False
            return [f'La casilla ({d["fila"]},{d["col"]}) ya fue atacada. Elija otra.']
        if tipo == 'E':
            f, c = d['fila'], d['col']
            self.propio[f][c] = FALLO if d['res'] == 'F' else IMPACTO
            return [f'El Jugador 1 disparo a ({f},{c}): {RESULTADOS[d["res"]]}.']
        if tipo == 'F':
            self.fase, self.turno, self.esperando = 'fin', None, False
            self.resumen = d
            gano = 'USTED GANO' if d['ganador'] == 2 else 'Gano el Jugador 1'
            return [f'Fin de la partida: {gano}.',
                    f'Disparos: Jugador 1 = {d["disparos_j1"]}, Jugador 2 = {d["disparos_j2"]}.',
                    f'Barcos hundidos: por el Jugador 1 = {d["hundidos_j1"]}, '
                    f'por el Jugador 2 = {d["hundidos_j2"]}.',
                    'Esperando una nueva partida (BTN_RST en la FPGA).']
        return []

    # ------------------------------------------------------------------
    def que_pedir(self):
        """'colocar', 'disparar' o None si no hay que pedir nada."""
        if self.esperando:
            return None
        if self.fase == 'colocacion' and self.barco < 3:
            return 'colocar'
        if self.fase == 'batalla' and self.turno == 2:
            return 'disparar'
        return None

    def indicacion(self):
        p = self.que_pedir()
        if p == 'colocar':
            return (f'Barco {self.barco} ({LARGOS[self.barco]} casillas). '
                    'Fila, columna y orientacion (H/V), por ejemplo 3 4 H: ')
        if p == 'disparar':
            return 'Casilla a disparar (fila columna), por ejemplo 2 5: '
        return ''

    def entrada(self, texto):
        """Valida lo que escribio el usuario. Devuelve (trama, error)."""
        p = self.que_pedir()
        if p == 'colocar':
            v, error = leer_colocacion(texto)
            if error:
                return None, error
            f, c, o = v
            self.pendiente = (self.barco, f, c, o)
            self.esperando = True
            return trama_colocacion(self.barco, f, c, o), None
        if p == 'disparar':
            v, error = leer_casilla(texto)
            if error:
                return None, error
            self.esperando = True
            return trama_disparo(*v), None
        return None, 'no es momento de enviar nada'

    def reintentar(self):
        """La FPGA no respondio a tiempo: se permite volver a enviar."""
        self.pendiente, self.esperando = None, False

    # ------------------------------------------------------------------
    def dibujo(self):
        filas = ['   Su tablero          Tablero del rival',
                 '   0 1 2 3 4 5 6 7     0 1 2 3 4 5 6 7']
        for f in range(8):
            filas.append(f'{f}  ' + ' '.join(self.propio[f]) + f'   {f} ' + ' '.join(self.rival[f]))
        filas.append(f'   {AGUA} agua  {BARCO} barco  {IMPACTO} impacto  {FALLO} fallo  '
                     f'{DESCONOCIDO} sin disparar')
        return '\n'.join(filas)
