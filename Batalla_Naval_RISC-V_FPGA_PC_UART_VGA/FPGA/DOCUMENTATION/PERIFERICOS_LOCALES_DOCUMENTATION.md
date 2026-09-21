# Periféricos locales — Batalla Naval sobre RISC-V

## 1. Introducción

Los periféricos locales son la interfaz del Jugador 1 con la tarjeta, aparte del monitor VGA:

| Módulo | Dirección | Función |
|---|---|---|
| `input_peripheral` | `0x0001_0120` | Botones y switch del Jugador 1, filtrados |
| `seg_peripheral` | `0x0001_0130` | Victorias acumuladas en los displays de 7 segmentos |
| `led_peripheral` | `0x0001_0138` | LED de fase |
| `buzzer_peripheral` | `0x0001_0140` | Sonidos de los eventos del juego |
| `button_input` | — | Sincronizador y antirrebote de una entrada (del Proyecto 2) |
| `clk_tick_gen` | — | Tick de 1 ms (del Proyecto 2) |
| `buzzer_controller` | — | Generador de tonos (adaptado del Proyecto 2) |

Ninguno contiene reglas del juego. El programa decide qué mostrar, cuándo sonar y qué hacer con cada botón; los periféricos solo se encargan de las señales físicas: rebotes, multiplexado de dígitos y generación de ondas.

Todos usan la interfaz estándar del enunciado (`clk_i`, `rst_i`, `write_enable_i`, `addr_i[1:0]`, `wdata_i`, `rdata_o`), con reinicio síncrono activo en alto. La lectura es combinacional, como necesita el procesador uniciclo.

## 2. Base de tiempo: `clk_tick_gen`

Genera un pulso de un ciclo cada `TICK_CYCLES` ciclos. Con reloj de 50 MHz se instancia con `TICK_CYCLES = 50 000`, es decir, un tick por milisegundo. El antirrebote, el barrido de los displays y las duraciones del buzzer cuentan estos ticks.

## 3. Entradas del Jugador 1: `input_peripheral`

Un registro de solo lectura (`addr_i = 00`) con el nivel ya filtrado de cada entrada (1 = activa):

| Bit | Entrada | Pin de la Nexys 4 |
|---|---|---|
| 0 | Arriba | BTNU (F15) |
| 1 | Abajo | BTND (V10) |
| 2 | Izquierda | BTNL (T16) |
| 3 | Derecha | BTNR (R10) |
| 4 | `BTN_SEL` | Switch SW0 (U9) |
| 5 | `BTN_OK` | Botón CPU RESET (C12), activo en bajo |
| 6 | `BTN_RST` | BTNC (E16), el botón central que indica el enunciado |

**Por qué estos pines:** la tarjeta tiene cinco pulsadores más el botón CPU RESET. El enunciado fija `BTN_RST` en el botón central y la navegación ocupa los otros cuatro. Por eso `BTN_OK` usa el botón CPU RESET (en este diseño no reinicia nada) y `BTN_SEL` usa un switch.

**Filtrado:** cada entrada pasa por `button_input` del Proyecto 2:

- un sincronizador de dos flip-flops, porque los botones son asíncronos respecto al reloj;
- un contador que acepta un cambio solo si se mantiene estable durante 10 ms.

Para `BTN_OK`, `button_input` se instancia con `BTN_ACTIVE_LEVEL = 0`, así que se lee como 1 al presionarlo.

**Detección de pulsaciones:** el periférico entrega niveles, no pulsos. El programa detecta cada pulsación comparando con la lectura anterior: en los botones cuenta el paso de 0 a 1, y en el switch de `BTN_SEL`, cualquier cambio de posición.

## 4. Displays: `seg_peripheral`

| `addr_i` | Acceso | Bits |
|---|---|---|
| `00` | L/E | `[3:0]` unidades J2, `[7:4]` decenas J2, `[11:8]` unidades J1, `[15:12]` decenas J1 (BCD) |

| Dígito del registro | Ánodo | Muestra |
|---|---|---|
| 3 | AN5 | decenas del J1 |
| 2 | AN4 | unidades del J1 |
| 1 | AN1 | decenas del J2 |
| 0 | AN0 | unidades del J2 |

- **Ubicación en la tarjeta:** los contadores de cada jugador quedan en bloques distintos, para que no se lean como un solo número de cuatro cifras. AN2, AN3, AN6 y AN7 quedan apagados.
- **Barrido:** se muestra un dígito por tick de 1 ms, así que la vuelta completa es de 4 ms (250 Hz).
- **Dígitos inválidos:** un nibble mayor a 9 apaga ese dígito.
- **Polaridad:** segmentos y ánodos son activos en bajo en la tarjeta. La polaridad se aplica al final, con `SEG_ACTIVE_LEVEL` y `AN_ACTIVE_LEVEL`.

El barrido y la tabla BCD a 7 segmentos son los del `display_controller` del Proyecto 2.

## 5. LED: `led_peripheral`

Un registro de lectura y escritura (`addr_i = 00`) cuyos bits `[15:0]` se copian a LD0–LD15. El significado lo fija el programa:

| LED | Fase |
|---|---|
| LD0 | Colocación de barcos |
| LD1 | Batalla |
| LD2 | Resultado final |

## 6. Buzzer: `buzzer_peripheral` y `buzzer_controller`

| `addr_i` | Acceso | Bits |
|---|---|---|
| `00` | Escritura | `[2:0]` evento; un valor de 1 a 5 inicia ese sonido |
| `00` | Lectura | `[0]` 1 mientras suena |

| Evento | Sonido | Duración |
|---|---|---|
| 1 Impacto | 2 kHz | 100 ms |
| 2 Fallo | 500 Hz | 150 ms |
| 3 Barco hundido | 3 kHz → 2 kHz → 3 kHz | 80 ms cada tono |
| 4 Colocación inválida | 250 Hz | 250 ms |
| 5 Victoria | 2 kHz → 2,5 kHz → 3 kHz | 150 ms cada tono |

Los sonidos se distinguen sin mirar la pantalla:

- el impacto es agudo y corto, y el fallo es grave;
- el hundido alterna dos tonos;
- la colocación inválida es el más grave y largo;
- la victoria sube de tono.

**Generación de la onda:** `buzzer_controller` es el del Proyecto 2 con los eventos nuevos. Un contador de semiperíodo invierte la salida para generar la onda cuadrada, y otro contador de milisegundos mide la duración de cada tono.

**Solapamiento:** un evento nuevo siempre reemplaza al que está sonando, porque en el juego el más reciente es el más relevante. Por ejemplo, la victoria llega justo después del sonido de hundido.

La Nexys 4 no tiene zumbador: la onda sale por el amplificador PWM de la salida de audio (`AUD_PWM` en A11, `AUD_SD` en D12). Hay que conectar audífonos o un parlante.

## 7. Validación

| Testbench | Qué revisa | Resultado |
|---|---|---|
| `tb_input_peripheral.sv` | Cada entrada en su bit; un rebote más corto que el filtro no se acepta; 8 ticks estables no alcanzan y 12 sí; CPU RESET invertido; escrituras ignoradas; `addr ≠ 00` lee 0 | PASS, 14 pruebas |
| `tb_seg_led_peripheral.sv` | Registro de displays; en cada milisegundo, un solo ánodo activo (AN0, AN1, AN4, AN5) con los segmentos del dígito correcto; nibble > 9 apagado; LED en registro y pines | PASS, 10 pruebas |
| `tb_buzzer_peripheral.sv` | Para cada evento mide sobre la salida la frecuencia de cada tono y la duración total, con ±3 % de tolerancia; reemplazo de un sonido en curso; códigos 0 y 7 no suenan | PASS, 10 pruebas |

- **Ticks acelerados:** para acelerar la simulación, el tick de "1 ms" se genera cada pocos ciclos. En el buzzer se usa `CLK_HZ = 1 MHz`, por eso el tono de 3 kHz se mide como 2994 Hz; a 50 MHz el error es de 0,01 %.
- **El testbench de displays detecta errores:** se intercambiaron dos ánodos a propósito en el RTL y el testbench marcó FAIL.

> Resultados obtenidos con Icarus Verilog. Deben repetirse en Vivado antes de incluirse como evidencia final.
