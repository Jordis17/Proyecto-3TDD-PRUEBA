# Planteamiento del diseño — Proyecto 3

**EL3313 Taller de Diseño Digital — Batalla Naval sobre RISC-V con periférico VGA**

> Documento en construcción. Sigue la metodología de diseño modular (top-down).

## 1. Comprensión del problema
## 2. Investigación previa
## 3. Objetivos de la solución
## 4. Diagrama de primer nivel
## 5. Diagrama de segundo nivel
## 6. Diagrama de tercer nivel
## 7. Mapa de memoria y registros de periféricos
## 8. Organización de RAM

La RAM de datos ocupa `0x0000_2000–0x0000_2FFF` (4 KB). El procesador solo implementa `lw` y `sw` para acceder a memoria, por lo que todos los datos del juego se guardan en palabras de 32 bits.

### 8.1. Alternativas consideradas

| | A. Una palabra por casilla | B. Mapas de bits | C. Lista de barcos |
|---|---|---|---|
| Idea | 64 palabras por jugador; cada una indica si hay barco (y cuál) y si ya fue disparada | 64 bits por tablero en 2 palabras: ocupadas, disparadas y una máscara por barco | Se guarda solo cada barco (fila, columna, orientación, impactos) y un tablero de disparos |
| Memoria aproximada | ~600 B | ~60 B | ~300 B |
| Dirección de una casilla | `base + ((fila << 3) + col) << 2` | bit `fila·8 + col` repartido en dos palabras | hay que recorrer los barcos |
| Validar traslape | revisar 2 a 4 casillas | `and` de máscaras; los barcos verticales cruzan entre las dos palabras | comparar contra cada barco |
| Detectar hundido | contador de casillas restantes por barco | `(barco & disparos) == barco` | contar impactos del barco |
| Depuración en simulación | directa, casilla por casilla | hay que interpretar bits | intermedia |

Se eligió la **alternativa A**. Con solo `lw`/`sw` cada acceso es directo, la dirección se calcula con dos desplazamientos y una suma, y el contenido de la RAM se puede leer casilla por casilla en la simulación. El consumo de memoria no es una limitación porque se usa menos del 20 % de la RAM.

### 8.2. Formato de una casilla

| Bits | Significado |
|---|---|
| `[1:0]` | 0 = agua, 1 = barco 0 (4 casillas), 2 = barco 1 (3 casillas), 3 = barco 2 (2 casillas) |
| `[2]` | 1 = casilla ya disparada |
| `[31:3]` | Sin uso, siempre en 0 |

El agua se codifica como 0 para que limpiar un tablero sea escribir ceros. No existe un segundo tablero con lo que cada jugador sabe del rival: esa vista se obtiene del tablero del rival mostrando solo las casillas disparadas (disparada con barco = impacto, disparada sin barco = fallo, no disparada = agua). Así la posición de los barcos no descubiertos existe en un solo lugar.

Procesamiento de un disparo sobre una casilla con contenido `v`:

1. Si `v & 4 ≠ 0`, la casilla ya fue disparada: se ignora y no se consume el turno.
2. Si `v & 3 = 0`, es fallo; si no, es impacto sobre el barco `(v & 3) − 1`.
3. En un impacto se resta 1 a las casillas restantes de ese barco; si llega a 0, el barco está hundido.
4. Se escribe `v | 4` en la casilla.

La partida termina cuando un jugador suma 3 barcos hundidos del rival.

### 8.3. Mapa de RAM

| Dirección | Contenido | Se limpia al iniciar partida |
|---|---|---|
| `0x2000–0x20FF` | Tablero del Jugador 1 (64 palabras) | Sí |
| `0x2100–0x21FF` | Tablero del Jugador 2 (64 palabras) | Sí |
| `0x2200`, `0x2204`, `0x2208` | J1: casillas restantes de los barcos 0, 1 y 2 | Sí |
| `0x220C` | J1: barcos colocados (bit *i* = barco *i* colocado) | Sí |
| `0x2210`, `0x2214`, `0x2218` | J2: casillas restantes de los barcos 0, 1 y 2 | Sí |
| `0x221C` | J2: barcos colocados (bit *i* = barco *i* colocado) | Sí |
| `0x2220` | Fase: 0 colocación, 1 batalla, 2 fin | Sí |
| `0x2224` | Turno: 0 = J1, 1 = J2 | Sí |
| `0x2228` | Disparos válidos del J1 | Sí |
| `0x222C` | Disparos válidos del J2 | Sí |
| `0x2230` | Barcos del J2 hundidos por el J1 | Sí |
| `0x2234` | Barcos del J1 hundidos por el J2 | Sí |
| `0x2238` | Ganador | Sí |
| `0x2240–0x224C` | Cursor del J1: fila, columna, orientación, barco actual | Sí |
| `0x2280–0x22FF` | Buffer de recepción UART (tamaño final según el protocolo) | Sí |
| `0x2300–0x2EFF` | Pila (crece hacia abajo desde `0x2F00`) | No |
| `0x2F00` | Victorias acumuladas del J1 | No |
| `0x2F04` | Victorias acumuladas del J2 | No |

El estado de colocación se guarda como máscara y no como contador porque el Jugador 2 puede enviar los barcos en cualquier orden; la máscara permite además rechazar un barco que ya fue colocado.

La pila se inicializa con `sp = 0x0000_2F00` y crece hacia direcciones menores, de modo que nunca alcanza las victorias acumuladas. Dispone de `0x2300–0x2EFF` (3 KB), mucho más de lo que necesita el programa.

### 8.4. Reinicio de partida

Al iniciar una nueva partida se limpia `0x2000–0x22FF` y se recargan las casillas restantes (4, 3 y 2). Las victorias acumuladas no se tocan.

> **Pendiente de confirmar:** esta organización supone que `BTN_RST` lo lee el software desde el registro de entradas y salta a la rutina de nueva partida, mientras que `rst_i` del procesador solo se usa para el arranque general (que sí pone las victorias en 0).

## 9. Memoria de video y distribución de tiles
## 10. Protocolo UART
## 11. Programa en ensamblador (flujo y diagramas de estado)
## 12. Aplicación de PC
## 13. Estrategia de implementación
## 14. Plan de pruebas

## Referencias

[1] D. Harris y S. Harris. *Digital Design and Computer Architecture. RISC-V Edition*. Morgan Kaufmann, 2022. ISBN: 978-0-12-820064-3.

[2] P. P. Chu. *FPGA Prototyping by SystemVerilog Examples*. Wiley, 2018. ISBN: 978-1-119-28266-2.
