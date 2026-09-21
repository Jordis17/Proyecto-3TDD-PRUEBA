# UART — Batalla Naval sobre RISC-V

## 1. Introducción

El UART es el único canal del Jugador 2 con la FPGA. Como pide el enunciado, se reutiliza el periférico del Proyecto 2 a 115200 baudios, con su interfaz de registros:

| Archivo | Origen | Cambio en el Proyecto 3 |
|---|---|---|
| `UART_tx.vhd`, `UART_rx.vhd` | Núcleo proporcionado por el curso | Ninguno |
| `uart_core.sv` | Envoltura del Proyecto 2 | Divisores para 50 MHz |
| `uart_peripheral.sv` | Periférico de registros del Proyecto 2 | Orden de los registros |

## 2. Registros

| Dirección | `addr_i` | Registro | Bits |
|---|---|---|---|
| `0x0001_0040` | `00` | Control/Estado | bit 0 `send`, bit 1 `new_rx` |
| `0x0001_0044` | `01` | Datos TX | `[7:0]` byte a transmitir |
| `0x0001_0048` | `10` | Datos RX | `[7:0]` último byte recibido |
| — | `11` | Reservado | Lee 0 |

- **`send`:** escribir 1 inicia la transmisión del byte de Datos TX, si no hay otra en curso. Se lee en 1 mientras transmite y el hardware lo baja al terminar. Escribir 0 no hace nada.
- **`new_rx`:** se lee en 1 cuando llegó un byte. Escribir 1 lo limpia y escribir 0 no hace nada. Si llega un byte en el mismo ciclo en que se limpia, gana la llegada.

Por esa semántica, una sola escritura de 32 bits en Control no puede cancelar una transmisión ni borrar un aviso de recepción por accidente.

**Único cambio en el periférico:** el orden de los registros. En el Proyecto 2 era TX = `00`, RX = `01` y Control = `10`. El mapa del Proyecto 3 pone Control en `0x40`, TX en `0x44` y RX en `0x48`, así que solo se cambiaron los tres `localparam` de `uart_peripheral.sv`.

## 3. Velocidad a 50 MHz

| | Cálculo | Valor | Velocidad real | Error |
|---|---|---|---|---|
| Transmisión (`BAUD_DIV`) | 50 000 000 / 115 200 | 434 | 115 207 baud | 0,01 % |
| Recepción (`BAUD_X16_DIV`) | 50 000 000 / 115 200 / 16 | 27 | 115 741 baud | 0,5 % |

Un error de 0,5 % acumula cerca de 5 % de un bit al final de una trama de 10 bits, así que el muestreo sigue cayendo cerca del centro de cada bit. En el Proyecto 2, a 100 MHz, los valores eran 868 y 54.

## 4. Receptor de un solo byte

El receptor guarda un solo byte: el programa tiene que leerlo antes de que llegue el siguiente (4340 ciclos a 50 MHz). Se decidió no agregar una FIFO para respetar el periférico reutilizado. Dos cosas lo garantizan:

- **El protocolo de aplicación:** la PC envía una trama y espera la respuesta antes de enviar otra, así que nunca transmite mientras la FPGA está enviando.
- **El programa:** su lazo principal lee el UART a lo sumo cada 1276 ciclos, medido en el simulador de instrucciones durante partidas completas.

El protocolo está en `docs/diseño/planteamiento.md`, sección 10, y en la documentación del ensamblador.

## 5. Validación

| Testbench | Qué revisa | Resultado |
|---|---|---|
| `tb_uart_peripheral.sv` | Registros tras el reinicio, registro TX, semántica de `send` y `new_rx`, independencia de los dos campos, trama completa por la línea (TX conectado a RX) | PASS, con divisores cortos y con los reales (434 y 27) |

El testbench es el del Proyecto 2 adaptado al nuevo orden de registros, y usa el núcleo VHDL real en lugar de un modelo.

> Resultados obtenidos con Icarus Verilog, convirtiendo el núcleo VHDL a Verilog con GHDL solo para esa simulación. En Vivado la simulación mixta VHDL/SystemVerilog funciona directamente; deben repetirse ahí antes de incluirse como evidencia final.
