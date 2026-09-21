"""Dibuja la pantalla 640x480 a partir de la memoria de video, con la
misma paleta, simbolos y cursor que vga_peripheral.sv."""
from PIL import Image

PALETA = [0x000, 0x05C, 0x888, 0xF00, 0xFFF, 0x0C0, 0xFF0, 0x006]
GLIFOS = {1: 0x3C666E7666663C00, 2: 0x1838181818187E00, 3: 0x3C66060C30607E00,
          4: 0x3C66061C06663C00, 5: 0x0C1C3C6C7E0C0C00, 6: 0x7E607C0606663C00,
          7: 0x3C607C6666663C00, 8: 0x7E060C1830303000, 9: 0x3C66663C66663C00,
          10: 0x3C66663E060C3800, 11: 0x183C66667E666600, 12: 0x7C66667C66667C00,
          13: 0x3C66606060663C00, 14: 0x7E60607C60606000, 15: 0x3C66606E66663C00,
          16: 0x3C18181818183C00, 17: 0x1E0C0C0C6C6C3800, 18: 0x6060606060607E00,
          19: 0x66767E7E6E666600, 20: 0x3C66666666663C00, 21: 0x7C66667C6C666600,
          22: 0x7E18181818181800, 23: 0x6666666666663C00, 24: 0x0018180018180000}

def rgb(i):
    c = PALETA[i]
    return tuple(((c >> s) & 0xF) * 17 for s in (8, 4, 0))

def dibujar(vmem, archivo):
    img = Image.new('RGB', (640, 480))
    px = img.load()
    for f in range(15):
        for c in range(20):
            w = vmem[f * 20 + c]
            g = GLIFOS.get((w >> 3) & 31, 0)
            for y in range(32):
                fila = (g >> (8 * (7 - (y >> 2)))) & 0xFF
                for x in range(32):
                    borde = x < 4 or x > 27 or y < 4 or y > 27
                    if (w >> 8) & 1 and borde: i = 6
                    elif (fila >> (7 - (x >> 2))) & 1: i = (w >> 9) & 7
                    else: i = w & 7
                    px[c * 32 + x, f * 32 + y] = rgb(i)
    img.save(archivo)
