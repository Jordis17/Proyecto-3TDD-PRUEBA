# Batalla Naval sobre RISC-V con periférico VGA

Proyecto 3 — EL3313 Taller de Diseño Digital (ITCR).

Juego de Batalla Naval para dos jugadores ejecutado como un programa en ensamblador sobre un microprocesador propio RV32I implementado en FPGA. El Jugador 1 usa VGA, botones, displays de 7 segmentos, LED y buzzer; el Jugador 2 usa una aplicación de PC conectada por UART.

> README en construcción: las secciones marcadas como *pendiente* se completan conforme el equipo tome y valide las decisiones de diseño.

## Estructura del repositorio

```
Batalla_Naval_RISC-V_FPGA_PC_UART_VGA/
├── FPGA/
│   ├── DESIGN/          Fuentes SystemVerilog sintetizables (.sv)
│   ├── SIMULATION/      Testbenches (.sv)
│   ├── CONSTRAINTS/     Constraints (.xdc)
│   └── DOCUMENTATION/   Documentación de hardware (.md) y FIGURAS/
├── ASSEMBLY/
│   ├── DESIGN/          Programa en ensamblador RISC-V (.s)
│   └── DOCUMENTATION/   Documentación del programa (.md)
├── PYTHON/
│   ├── DESIGN/          Aplicación de PC del Jugador 2 (.py)
│   └── DOCUMENTATION/   Documentación de la aplicación (.md) y FIGURAS/
└── docs/
    ├── diseño/          planteamiento.md (planteamiento del diseño) y FIGURAS/
    └── informe/         informe.md (informe técnico) y FIGURAS/
```

## Flujo de trabajo (Git)

- `main`: versiones estables e integradas.
- `develop`: rama de integración.
- `feature/<funcionalidad>`: una rama por funcionalidad; se integra a `develop` mediante pull request con revisión de otro integrante.
- Cada tarea se registra como *issue* asignado a un integrante.

## Dependencias

*Pendiente.* (Versión de Vivado, tarjeta FPGA, toolchain/ensamblador RISC-V, Python y bibliotecas.)

## Compilación y síntesis

*Pendiente.*

## Simulación

*Pendiente.*

## Ejecución

*Pendiente.*

## Integrantes

*Pendiente.*
