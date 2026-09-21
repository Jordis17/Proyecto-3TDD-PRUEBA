// =====================================================================
// clk_gen.sv - Generacion de relojes y reinicio general
//
// A partir de los 100 MHz de la tarjeta, un PLL del Artix-7 (primitiva
// PLLE2_BASE) genera:
//   clk_sys_o  50 MHz  CPU, memorias y perifericos de registros
//   clk_pix_o  25 MHz  generacion VGA
//
//   VCO  = 100 MHz x CLKFBOUT_MULT (10) / DIVCLK_DIVIDE (1) = 1000 MHz
//          (rango valido del Artix-7 -1: 800 a 1600 MHz)
//   sys  = 1000 / 20 = 50 MHz
//   pix  = 1000 / 40 = 25 MHz
//
// Para cambiar el reloj del sistema (por ejemplo a 25 MHz si no cierra
// timing) basta con cambiar SYS_DIVIDE.
//
// Reinicio: mientras el PLL no este enclavado (locked = 0) los relojes
// no son confiables. Cada dominio recibe su propio reinicio, activo en
// alto, que se activa cuando locked cae y se libera sincronizado a su
// reloj con dos flip-flops (planteamiento, seccion 7.1).
// =====================================================================

module clk_gen #(
    parameter int SYS_DIVIDE = 20,
    parameter int PIX_DIVIDE = 40
) (
    input  logic clk100_i,
    output logic clk_sys_o,
    output logic clk_pix_o,
    output logic rst_sys_o,
    output logic rst_pix_o
);

    logic clkfb, clk_sys_pll, clk_pix_pll, locked;

    PLLE2_BASE #(
        .CLKIN1_PERIOD  (10.0),
        .CLKFBOUT_MULT  (10),
        .DIVCLK_DIVIDE  (1),
        .CLKOUT0_DIVIDE (SYS_DIVIDE),
        .CLKOUT1_DIVIDE (PIX_DIVIDE)
    ) u_pll (
        .CLKIN1   (clk100_i),
        .CLKFBIN  (clkfb),
        .CLKFBOUT (clkfb),
        .CLKOUT0  (clk_sys_pll),
        .CLKOUT1  (clk_pix_pll),
        .CLKOUT2  (),
        .CLKOUT3  (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .LOCKED   (locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    BUFG u_bufg_sys (.I(clk_sys_pll), .O(clk_sys_o));
    BUFG u_bufg_pix (.I(clk_pix_pll), .O(clk_pix_o));

    reset_sync u_rst_sys (.clk_i(clk_sys_o), .locked_i(locked), .rst_o(rst_sys_o));
    reset_sync u_rst_pix (.clk_i(clk_pix_o), .locked_i(locked), .rst_o(rst_pix_o));

endmodule
