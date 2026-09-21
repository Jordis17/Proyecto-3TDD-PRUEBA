// =====================================================================
// input_peripheral.sv - Periferico de entradas del Jugador 1
//
// Direccion 0x0001_0120. Un solo registro de estado, de solo lectura
// (addr_i = 00), con el nivel ya filtrado de cada entrada (1 = activa):
//
//   bit 0  arriba      BTNU
//   bit 1  abajo       BTND
//   bit 2  izquierda   BTNL
//   bit 3  derecha     BTNR
//   bit 4  BTN_SEL     switch SW0
//   bit 5  BTN_OK      boton CPU RESET (activo en bajo en la tarjeta)
//   bit 6  BTN_RST     BTNC
//
// Cada entrada pasa por button_input (Proyecto 2): sincronizador de dos
// flip-flops y filtro antirrebote de DEBOUNCE_MS. Las escrituras se
// ignoran y las demas direcciones leen 0.
//
// El periferico solo entrega niveles. Detectar una pulsacion nueva
// (flanco) es trabajo del programa, que compara con la lectura anterior
// (planteamiento, seccion 7.4).
// =====================================================================

module input_peripheral #(
    parameter int DEBOUNCE_MS = 10
) (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic        tick_i,        // pulso de 1 ms
    input  logic        btn_up_i,
    input  logic        btn_down_i,
    input  logic        btn_left_i,
    input  logic        btn_right_i,
    input  logic        sw_sel_i,
    input  logic        btn_ok_n_i,    // CPU RESET, activo en bajo
    input  logic        btn_rst_i
);

    logic [6:0] entradas, niveles;

    assign entradas = {btn_rst_i, btn_ok_n_i, sw_sel_i,
                       btn_right_i, btn_left_i, btn_down_i, btn_up_i};

    // BTN_OK es el unico activo en bajo; button_input lo normaliza a
    // 1 = presionado con BTN_ACTIVE_LEVEL = 0.
    genvar i;
    generate
        for (i = 0; i < 7; i++) begin : g_entrada
            button_input #(
                .DEBOUNCE_MS      (DEBOUNCE_MS),
                .BTN_ACTIVE_LEVEL ((i == 5) ? 1'b0 : 1'b1)
            ) u_btn (
                .clk_i   (clk_i),
                .rst_i   (rst_i),
                .tick_i  (tick_i),
                .btn_i   (entradas[i]),
                .pulse_o (),
                .level_o (niveles[i])
            );
        end
    endgenerate

    assign rdata_o = (addr_i == 2'b00) ? {25'd0, niveles} : 32'd0;
    // El registro es de solo lectura: write_enable_i y wdata_i quedan
    // sin usar, pero se mantienen para respetar la interfaz comun.

endmodule
