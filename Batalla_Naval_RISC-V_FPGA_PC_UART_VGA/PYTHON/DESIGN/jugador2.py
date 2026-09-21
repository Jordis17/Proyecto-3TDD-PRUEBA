"""Aplicacion de PC del Jugador 2 - Batalla Naval sobre RISC-V.

Terminal remota: muestra el estado de la partida y envia las jugadas
por UART. Todas las decisiones del juego las toma la FPGA.

Uso:
    python jugador2.py COM5          (Windows)
    python jugador2.py /dev/ttyUSB1  (Linux)
Sin argumentos, muestra los puertos disponibles.

Dos hilos (planteamiento, seccion 12):
  - el hilo lector lee lineas del puerto y las pone en una cola;
  - el hilo principal las procesa, dibuja y pide datos al usuario.
Asi los mensajes que llegan mientras el usuario escribe no se pierden.
"""
import queue
import sys
import threading
import time

import serial
import serial.tools.list_ports

from cliente import ClienteJ2

BAUDIOS = 115200
ESPERA_RESPUESTA = 3.0     # segundos


def hilo_lector(puerto, cola):
    while True:
        try:
            linea = puerto.readline()
        except serial.SerialException:
            cola.put(None)
            return
        if linea:
            cola.put(linea.decode('ascii', errors='replace').strip())


def procesar_cola(cliente, cola):
    """Procesa todo lo recibido. Devuelve True si algo cambio."""
    cambio = False
    while True:
        try:
            linea = cola.get_nowait()
        except queue.Empty:
            return cambio
        if linea is None:
            print('\nSe perdio la conexion con la FPGA.')
            sys.exit(1)
        for mensaje in cliente.procesar(linea):
            print(mensaje)
        cambio = True


def main():
    if len(sys.argv) < 2:
        print('Uso: python jugador2.py PUERTO')
        print('Puertos disponibles:')
        for p in serial.tools.list_ports.comports():
            print(f'  {p.device}  {p.description}')
        return

    try:
        puerto = serial.Serial(sys.argv[1], BAUDIOS, timeout=0.1)
    except serial.SerialException as e:
        print(f'No se pudo abrir {sys.argv[1]}: {e}')
        return

    cola = queue.Queue()
    threading.Thread(target=hilo_lector, args=(puerto, cola), daemon=True).start()
    cliente = ClienteJ2()
    print('Jugador 2 conectado. Esperando el inicio de la partida (#C)...')
    print('Si la FPGA ya estaba encendida, presione BTN_RST para empezar.')

    envio = None           # momento del ultimo envio sin respuesta
    try:
        while True:
            if procesar_cola(cliente, cola):
                print()
                print(cliente.dibujo())
            if cliente.esperando and envio and time.time() - envio > ESPERA_RESPUESTA:
                print('La FPGA no respondio. Puede volver a intentarlo.')
                cliente.reintentar()
                envio = None
            if cliente.que_pedir() is None:
                time.sleep(0.05)
                continue

            texto = input(cliente.indicacion())
            # si mientras escribia llego algo (por ejemplo, BTN_RST), se
            # atiende primero y la entrada se descarta si ya no aplica
            fase_antes = (cliente.fase, cliente.barco, cliente.turno)
            if procesar_cola(cliente, cola):
                print(cliente.dibujo())
                if (cliente.fase, cliente.barco, cliente.turno) != fase_antes:
                    continue
            trama, error = cliente.entrada(texto)
            if error:
                print(f'Entrada invalida: {error}.')
                continue
            puerto.write(trama.encode('ascii'))
            envio = time.time()
    except (KeyboardInterrupt, EOFError):
        print('\nSaliendo.')
    finally:
        puerto.close()


if __name__ == '__main__':
    main()
