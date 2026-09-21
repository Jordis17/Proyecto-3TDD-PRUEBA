"""Simulador del conjunto de instrucciones RV32I del proyecto con modelos
de los perifericos, para probar el programa del juego rapidamente.

Un ciclo = una instruccion (procesador uniciclo a 50 MHz, 20 ns).
Solo acepta las 27 instrucciones implementadas en el hardware y solo
las direcciones del mapa de memoria: cualquier otra cosa es un error.
El UART modela la duracion real de cada byte a 115200 baudios y el
receptor de un solo byte del periferico (cuenta los bytes perdidos).

Es una herramienta de verificacion del programa; la validacion del
hardware se hace con los testbenches de FPGA/SIMULATION.
"""
import struct

BYTE_CICLOS = 4340   # 10 bits a 115200 baudios con reloj de 50 MHz

def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v

class Error(Exception):
    pass

class Sistema:
    def __init__(self, hexfile):
        self.rom = [int(l, 16) for l in open(hexfile) if l.strip()]
        self.ram = [0] * 1024
        self.vmem = [0] * 512
        self.x = [0] * 32
        self.pc = 0
        self.ciclo = 0
        self.entradas = 0
        self.leds = 0
        self.displays = 0
        self.sonidos = []          # (ciclo, evento)
        # UART
        self.tx_reg = 0
        self.tx_fin = 0
        self.tx_bytes = []         # (ciclo, byte)
        self.rx_reg = 0
        self.new_rx = 0
        self.rx_llegadas = []      # (ciclo, byte) programados
        self.rx_perdidos = 0
        self.lineas = []           # tramas recibidas del FPGA, ya armadas
        self._linea = b''
        self.leidas = 0            # lineas ya consumidas por la prueba

    # ---------------- bus de datos ----------------
    def leer(self, a):
        if a & 3: raise Error(f'lw desalineado {a:#x} pc={self.pc:#x}')
        if 0x2000 <= a <= 0x2FFF: return self.ram[(a - 0x2000) >> 2]
        if 0x11000 <= a <= 0x117FF: return self.vmem[(a - 0x11000) >> 2]
        if a == 0x10040: return (1 if self.ciclo < self.tx_fin else 0) | (self.new_rx << 1)
        if a == 0x10044: return self.tx_reg
        if a == 0x10048: return self.rx_reg
        if a == 0x10120: return self.entradas
        if a == 0x10130: return self.displays
        if a == 0x10138: return self.leds
        if a == 0x10140: return 0
        raise Error(f'lw a direccion no usada {a:#x} pc={self.pc:#x}')

    def escribir(self, a, v):
        v &= 0xFFFFFFFF
        if a & 3: raise Error(f'sw desalineado {a:#x} pc={self.pc:#x}')
        if 0x2000 <= a <= 0x2FFF: self.ram[(a - 0x2000) >> 2] = v; return
        if 0x11000 <= a <= 0x117FF: self.vmem[(a - 0x11000) >> 2] = v; return
        if a == 0x10040:
            if v & 1 and self.ciclo >= self.tx_fin:
                self.tx_fin = self.ciclo + BYTE_CICLOS
                self._tx(self.tx_reg & 0xFF)
            if v & 2: self.new_rx = 0
            return
        if a == 0x10044: self.tx_reg = v & 0xFF; return
        if a == 0x10130: self.displays = v & 0xFFFF; return
        if a == 0x10138: self.leds = v & 0xFFFF; return
        if a == 0x10140:
            if 1 <= (v & 7) <= 5: self.sonidos.append((self.ciclo, v & 7))
            return
        raise Error(f'sw a direccion no usada {a:#x} pc={self.pc:#x}')

    def _tx(self, b):
        self.tx_bytes.append((self.ciclo, b))
        if b == 10:
            self.lineas.append(self._linea.decode('latin1'))
            self._linea = b''
        else:
            self._linea += bytes([b])

    # PC -> FPGA: los bytes llegan uno cada BYTE_CICLOS
    def pc_envia(self, texto):
        t = max([self.ciclo] + [c for c, _ in self.rx_llegadas])
        for i, ch in enumerate(texto.encode('latin1')):
            self.rx_llegadas.append((t + (i + 1) * BYTE_CICLOS, ch))

    # ---------------- ejecucion ----------------
    def paso(self):
        while self.rx_llegadas and self.rx_llegadas[0][0] <= self.ciclo:
            _, b = self.rx_llegadas.pop(0)
            if self.new_rx: self.rx_perdidos += 1
            self.rx_reg = b; self.new_rx = 1
        if self.pc & 3 or self.pc >= 0x2000: raise Error(f'PC invalido {self.pc:#x}')
        idx = self.pc >> 2
        w = self.rom[idx] if idx < len(self.rom) else 0x13
        op = w & 0x7F; rd = (w >> 7) & 31; f3 = (w >> 12) & 7
        r1 = self.x[(w >> 15) & 31]; r2 = self.x[(w >> 20) & 31]
        b30 = (w >> 30) & 1
        i_imm = sx(w >> 20, 12)
        npc = self.pc + 4
        res = None
        u = lambda v: v & 0xFFFFFFFF
        s = lambda v: sx(v, 32)
        if op == 0x33:   # tipo R
            f7 = w >> 25
            if f7 not in (0, 0x20) or (f7 == 0x20 and f3 not in (0, 5)): raise Error(f'R no soportada {w:08x}')
            res = {0: (u(r1 - r2) if b30 else u(r1 + r2)), 1: u(r1 << (r2 & 31)), 2: int(s(r1) < s(r2)),
                   3: int(r1 < r2), 4: r1 ^ r2, 5: (u(s(r1) >> (r2 & 31)) if b30 else r1 >> (r2 & 31)),
                   6: r1 | r2, 7: r1 & r2}[f3]
        elif op == 0x13:  # tipo I
            sh = (w >> 20) & 31
            if f3 == 1 and (w >> 25) != 0: raise Error('slli invalida')
            if f3 == 5 and (w >> 25) not in (0, 0x20): raise Error('srli/srai invalida')
            res = {0: u(r1 + i_imm), 1: u(r1 << sh), 2: int(s(r1) < i_imm), 3: int(r1 < u(i_imm)),
                   4: u(r1 ^ i_imm), 5: (u(s(r1) >> sh) if b30 else r1 >> sh), 6: u(r1 | i_imm), 7: u(r1 & i_imm)}[f3]
        elif op == 0x03:
            if f3 != 2: raise Error(f'carga no soportada (solo lw) pc={self.pc:#x}')
            res = self.leer(u(r1 + i_imm))
        elif op == 0x23:
            if f3 != 2: raise Error(f'almacenamiento no soportado (solo sw) pc={self.pc:#x}')
            self.escribir(u(r1 + sx(((w >> 25) << 5) | ((w >> 7) & 31), 12)), r2)
        elif op == 0x63:
            imm = sx(((w >> 31) << 12) | (((w >> 7) & 1) << 11) | (((w >> 25) & 0x3F) << 5) | (((w >> 8) & 0xF) << 1), 13)
            if f3 not in (0, 1, 4, 5): raise Error(f'salto no soportado (bltu/bgeu) pc={self.pc:#x}')
            t = {0: r1 == r2, 1: r1 != r2, 4: s(r1) < s(r2), 5: s(r1) >= s(r2)}[f3]
            if t: npc = u(self.pc + imm)
        elif op == 0x6F:
            imm = sx(((w >> 31) << 20) | (((w >> 12) & 0xFF) << 12) | (((w >> 20) & 1) << 11) | (((w >> 21) & 0x3FF) << 1), 21)
            res = npc; npc = u(self.pc + imm)
        elif op == 0x67:
            res = npc; npc = u(r1 + i_imm) & ~1
        else:
            raise Error(f'instruccion no implementada {w:08x} en pc={self.pc:#x}')
        if res is not None and rd: self.x[rd] = u(res)
        self.pc = npc
        self.ciclo += 1

    def correr(self, ciclos):
        fin = self.ciclo + ciclos
        while self.ciclo < fin: self.paso()

    def esperar_linea(self, esperada, limite=3_000_000):
        """Devuelve la siguiente linea no leida, corriendo hasta que llegue."""
        fin = self.ciclo + limite
        while len(self.lineas) <= self.leidas:
            if self.ciclo > fin: raise Error(f'no llego respuesta (se esperaba {esperada})')
            self.paso()
        self.leidas += 1
        return self.lineas[self.leidas - 1]

    def sin_lineas_nuevas(self):
        return len(self.lineas) == self.leidas

    def presionar(self, bits, mantener=30000, soltar=30000):
        self.entradas |= bits; self.correr(mantener)
        self.entradas &= ~bits; self.correr(soltar)

    def ram_w(self, dir_):
        return self.ram[(dir_ - 0x2000) >> 2]
