"""Protocolo de aplicacion sobre UART (planteamiento, seccion 10).

PC -> FPGA (sin terminador):
    #P b f c o   colocacion: barco 0-2, fila 0-7, columna 0-7, H/V
    #D f c       disparo: fila 0-7, columna 0-7
FPGA -> PC (terminadas en '\\n'):
    #C  #A b  #X b m  #B  #T j  #R f c r  #N f c  #E f c r  #F g d1d1 d2d2 h1 h2

Este modulo solo arma y reconoce tramas. No sabe nada de las reglas
del juego: eso lo decide el programa en la FPGA.
"""

MOTIVOS = {1: 'el barco se sale del tablero', 2: 'se traslapa con otro barco',
           3: 'ese barco ya estaba colocado'}
RESULTADOS = {'F': 'fallo', 'I': 'impacto', 'H': 'impacto y barco hundido'}
LARGOS = {0: 4, 1: 3, 2: 2}           # casillas de cada barco


def trama_colocacion(barco, fila, col, orient):
    return f'#P{barco}{fila}{col}{orient}'


def trama_disparo(fila, col):
    return f'#D{fila}{col}'


def _digito(ch, maximo):
    return ch.isdigit() and int(ch) <= maximo


def interpretar(linea):
    """Convierte una linea recibida en (tipo, campos). Devuelve None si
    no es una trama valida (la linea se ignora)."""
    t = linea.strip()
    if len(t) < 2 or t[0] != '#':
        return None
    tipo, resto = t[1], t[2:]
    try:
        if tipo in 'CB' and resto == '':
            return tipo, {}
        if tipo == 'A' and len(resto) == 1 and _digito(resto[0], 2):
            return tipo, {'barco': int(resto)}
        if tipo == 'X' and len(resto) == 2 and _digito(resto[0], 2) and resto[1] in '123':
            return tipo, {'barco': int(resto[0]), 'motivo': int(resto[1])}
        if tipo == 'T' and resto in ('1', '2'):
            return tipo, {'jugador': int(resto)}
        if tipo in 'RE' and len(resto) == 3 and _digito(resto[0], 7) and _digito(resto[1], 7) \
                and resto[2] in 'FIH':
            return tipo, {'fila': int(resto[0]), 'col': int(resto[1]), 'res': resto[2]}
        if tipo == 'N' and len(resto) == 2 and _digito(resto[0], 7) and _digito(resto[1], 7):
            return tipo, {'fila': int(resto[0]), 'col': int(resto[1])}
        if tipo == 'F' and len(resto) == 7 and resto.isdigit() and resto[0] in '12':
            return tipo, {'ganador': int(resto[0]), 'disparos_j1': int(resto[1:3]),
                          'disparos_j2': int(resto[3:5]), 'hundidos_j1': int(resto[5]),
                          'hundidos_j2': int(resto[6])}
    except ValueError:
        return None
    return None


def leer_casilla(texto):
    """'3 4', '3,4' o '34' -> (3, 4). Devuelve (None, error) si no sirve."""
    t = texto.replace(' ', '').replace(',', '')
    if len(t) != 2 or not t.isdigit():
        return None, 'escriba fila y columna, por ejemplo: 3 4'
    f, c = int(t[0]), int(t[1])
    if f > 7 or c > 7:
        return None, 'fila y columna deben estar entre 0 y 7'
    return (f, c), None


def leer_colocacion(texto):
    """'3 4 H', '34v' -> (3, 4, 'H'). Devuelve (None, error) si no sirve."""
    t = texto.replace(' ', '').replace(',', '').upper()
    if len(t) != 3 or t[2] not in 'HV':
        return None, 'escriba fila, columna y orientacion H o V, por ejemplo: 3 4 H'
    casilla, error = leer_casilla(t[:2])
    if error:
        return None, error
    return (casilla[0], casilla[1], t[2]), None
