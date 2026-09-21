"""Mide el peor intervalo entre lecturas del UART por el lazo principal
(entrada de uart_recibir) mientras la FPGA no esta transmitiendo,
jugando las partidas de prueba_juego.py. Debe ser menor que la duracion
de un byte (4340 ciclos a 50 MHz) para que el receptor de un solo byte
no pierda datos.

Uso:
    python3 medir_uart.py ../../FPGA/DESIGN/programa.mem <direccion de uart_recibir en hex>
""" 
import sys, runpy, iss
DIR = int(sys.argv[2], 16)
orig = iss.Sistema.paso
d = {'ult': None, 'max': 0}
def paso(self):
    if self.pc == DIR:
        u = d['ult']
        if u is not None and not any(u <= c <= self.ciclo for c, _ in self.tx_bytes[-6:]) \
           and self.ciclo >= self.tx_fin:
            d['max'] = max(d['max'], self.ciclo - u)
        d['ult'] = self.ciclo
    orig(self)
iss.Sistema.paso = paso
sys.argv = ['prueba_juego.py', sys.argv[1]]
try:
    runpy.run_path('prueba_juego.py', run_name='__main__')
except SystemExit:
    pass
print(f'peor intervalo entre lecturas del UART: {d["max"]} ciclos (un byte dura 4340 a 50 MHz y 2170 a 25 MHz)')
