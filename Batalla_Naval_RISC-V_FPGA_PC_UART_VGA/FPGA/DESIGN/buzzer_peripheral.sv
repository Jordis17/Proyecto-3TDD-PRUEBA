// =====================================================================
// buzzer_peripheral.sv - Periferico de sonido
//
// Direccion 0x0001_0140, addr_i = 00:
//   escritura  [2:0] evento (1-5); un valor distinto de 0 inicia ese
//              sonido, reemplazando al que este sonando
//   lectura    [0]   1 mientras suena
//
// La tabla de eventos esta en buzzer_controller.sv y en el
// planteamiento, seccion 7.7.
// =====================================================================

module buzzer_peripheral #(
    parameter int CLK_HZ = 50_000_000
) (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic        tick_i,     // pulso de 1 ms
    output logic        aud_pwm_o,
    output logic        aud_sd_o
);

    logic busy, inicio;

    // la escritura en CONTROL es el pulso de inicio
    assign inicio = write_enable_i && (addr_i == 2'b00);

    buzzer_controller #(.CLK_HZ(CLK_HZ)) u_tonos (
        .clk_i       (clk_i),
        .rst_i       (rst_i),
        .tick_i      (tick_i),
        .snd_event_i (wdata_i[2:0]),
        .snd_start_i (inicio),
        .aud_pwm_o   (aud_pwm_o),
        .aud_sd_o    (aud_sd_o),
        .busy_o      (busy)
    );

    assign rdata_o = (addr_i == 2'b00) ? {31'd0, busy} : 32'd0;

endmodule
