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

| Dirección | Desplazamiento desde `gp` | Contenido | Se limpia al iniciar partida |
|---|---|---|---|
| `0x2000–0x20FF` | -2048 a -1793 | Tablero del Jugador 1 (64 palabras) | Sí |
| `0x2100–0x21FF` | -1792 a -1537 | Tablero del Jugador 2 (64 palabras) | Sí |
| `0x2200`, `0x2204`, `0x2208` | -1536, -1532, -1528 | J1: casillas restantes de los barcos 0, 1 y 2 | Sí |
| `0x220C` | -1524 | J1: barcos colocados (bit *i* = barco *i* colocado) | Sí |
| `0x2210`, `0x2214`, `0x2218` | -1520, -1516, -1512 | J2: casillas restantes de los barcos 0, 1 y 2 | Sí |
| `0x221C` | -1508 | J2: barcos colocados (bit *i* = barco *i* colocado) | Sí |
| `0x2220` | -1504 | Fase: 0 colocación, 1 batalla, 2 fin | Sí |
| `0x2224` | -1500 | Turno: 0 = J1, 1 = J2 | Sí |
| `0x2228` | -1496 | Disparos válidos del J1 | Sí |
| `0x222C` | -1492 | Disparos válidos del J2 | Sí |
| `0x2230` | -1488 | Barcos del J2 hundidos por el J1 | Sí |
| `0x2234` | -1484 | Barcos del J1 hundidos por el J2 | Sí |
| `0x2238` | -1480 | Ganador | Sí |
| `0x2240–0x224C` | -1472 a -1460 | Cursor del J1: fila, columna, orientación, barco actual | Sí |
| `0x2280–0x22FF` | -1408 a -1281 | Buffer de recepción UART (tamaño final según el protocolo) | Sí |
| `0x2300–0x2EFF` | -1280 a 1791 | Pila (crece hacia abajo desde `0x2F00`) | No |
| `0x2F00` | 1792 | Victorias acumuladas del J1 | No |
| `0x2F04` | 1796 | Victorias acumuladas del J2 | No |

El estado de colocación se guarda como máscara y no como contador porque el Jugador 2 puede enviar los barcos en cualquier orden; la máscara permite además rechazar un barco que ya fue colocado.

Todas las variables se leen y escriben con `lw`/`sw` relativos a `gp = 0x0000_2800` (sección 11.2).

La pila se inicializa con `sp = 0x0000_2F00` y crece hacia direcciones menores, de modo que nunca alcanza las victorias acumuladas. Dispone de `0x2300–0x2EFF` (3 KB), mucho más de lo que necesita el programa.

### 8.4. Reinicio de partida

Al iniciar una nueva partida se limpia `0x2000–0x22FF` y se recargan las casillas restantes (4, 3 y 2). Las victorias acumuladas no se tocan.

> **Pendiente de confirmar:** esta organización supone que `BTN_RST` lo lee el software desde el registro de entradas y salta a la rutina de nueva partida, mientras que `rst_i` del procesador solo se usa para el arranque general (que sí pone las victorias en 0).

## 9. Memoria de video y distribución de tiles
## 10. Protocolo UART
## 11. Programa en ensamblador (flujo y diagramas de estado)

### 11.1. Convención de registros y llamadas

Se sigue la convención estándar de RISC-V descrita en [1, cap. 6], adaptada al conjunto de instrucciones que implementa el procesador.

| Registro | Nombre | Uso | Preservado por |
|---|---|---|---|
| `x0` | `zero` | Constante 0 | — |
| `x1` | `ra` | Dirección de retorno | La rutina que llama, si llama a otra |
| `x2` | `sp` | Puntero de pila | La rutina llamada |
| `x3` | `gp` | Base de la RAM, fija en `0x0000_2800` | No se modifica después de la inicialización |
| `x4` | `tp` | Base de periféricos, fija en `0x0001_0000` | No se modifica después de la inicialización |
| `x5–x7`, `x28–x31` | `t0–t6` | Temporales | Nadie |
| `x8–x9`, `x18–x27` | `s0–s11` | Valores que deben conservarse entre llamadas | La rutina llamada |
| `x10–x17` | `a0–a7` | Argumentos; el resultado se devuelve en `a0` (y `a1`) | Nadie |

Reglas de llamada:

- Llamada: `jal ra, rutina`. Retorno: `jalr x0, 0(ra)`.
- Una rutina que llama a otra guarda `ra` en la pila al entrar y lo restaura al salir; también guarda los registros `s` que modifique.
- Una rutina hoja usa solo registros `t` y `a` y no toca la pila.
- `sp` se inicializa en `0x0000_2F00` (sección 8.3) y se ajusta siempre en múltiplos de 4.

Ejemplo de entrada y salida de una rutina que llama a otra y usa `s0`:

```asm
rutina:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)
    # ... cuerpo ...
    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    jalr x0, 0(ra)
```

### 11.2. Registros base y carga de constantes

El conjunto de instrucciones implementado no incluye `lui` ni `auipc`, por lo que una constante mayor a 12 bits no se puede cargar en una sola instrucción. Las direcciones de la RAM y de los periféricos superan ese rango, así que se fijan dos registros base al inicio del programa:

```asm
    addi gp, zero, 5
    slli gp, gp, 11        # gp = 0x0000_2800
    addi tp, zero, 1
    slli tp, tp, 16        # tp = 0x0001_0000
```

`lw` y `sw` aceptan desplazamientos de −2048 a +2047, por lo que desde `gp = 0x2800` se alcanza toda la RAM (`0x2000–0x2FFF`). Desde `tp` se alcanzan todos los registros de periféricos:

| Periférico | Acceso |
|---|---|
| UART Control/Estado | `0x40(tp)` |
| UART Datos TX | `0x44(tp)` |
| UART Datos RX | `0x48(tp)` |
| Entradas del Jugador 1 | `0x120(tp)` |
| Displays de 7 segmentos | `0x130(tp)` |
| LED de estado | `0x138(tp)` |
| Buzzer | `0x140(tp)` |

La memoria de video (`0x0001_1000`) queda fuera del alcance de `tp`; las rutinas de video calculan su base con `addi t0, zero, 0x11` y `slli t0, t0, 12`.

### 11.3. Pseudoinstrucciones

Solo se usan pseudoinstrucciones que el ensamblador traduce a instrucciones implementadas. Las constantes pequeñas se escriben directamente con `addi` en lugar de `li`.

| Permitida | Se traduce a |
|---|---|
| `mv rd, rs` | `addi rd, rs, 0` |
| `nop` | `addi x0, x0, 0` |
| `j etiqueta` | `jal x0, etiqueta` |
| `ret` | `jalr x0, 0(ra)` |
| `not rd, rs` | `xori rd, rs, -1` |
| `neg rd, rs` | `sub rd, x0, rs` |
| `beqz` / `bnez rs, etiqueta` | `beq` / `bne rs, x0, etiqueta` |
| `bgt` / `ble rs, rt, etiqueta` | `blt` / `bge rt, rs, etiqueta` |
| `seqz rd, rs` | `sltiu rd, rs, 1` |
| `snez rd, rs` | `sltu rd, x0, rs` |

No se permiten: `li` con valores fuera de −2048…2047 y `la`, `call` o `tail` (usan `lui`/`auipc`); `bltu`, `bgeu`, `bgtu`, `bleu`; ni accesos por byte o media palabra (`lb`, `lbu`, `sb`, `lh`, `sh`).

### 11.4. Flujo del programa
## 12. Aplicación de PC
## 13. Estrategia de implementación
## 14. Plan de pruebas

## Referencias

[1] D. Harris y S. Harris. *Digital Design and Computer Architecture. RISC-V Edition*. Morgan Kaufmann, 2022. ISBN: 978-0-12-820064-3.

[2] P. P. Chu. *FPGA Prototyping by SystemVerilog Examples*. Wiley, 2018. ISBN: 978-1-119-28266-2.
