// =====================================================================
// tb_sistema_juego.sv - Simulacion del sistema con el programa del juego
//
// Carga en la ROM el programa real (programa.mem, ensamblado con RARS
// desde ASSEMBLY/DESIGN/batalla_naval.s) y juega el inicio de una
// partida desde los pines de la tarjeta:
//   1. arranque: la FPGA envia #C;
//   2. el J2 coloca sus tres barcos por UART (uno rechazado por
//      traslape) mientras el J1 coloca los suyos con los botones;
//   3. inicio de la batalla: #B y #T1;
//   4. un disparo del J1 (impacto) y un disparo del J2 (fallo), con sus
//      tramas, la RAM y la memoria de video.
//
// Este mismo escenario sirve para la simulacion post-implementacion
// (fragmento del programa y validacion de un disparo).
//
// El UART usa los divisores reales (434 y 27): la relacion entre la
// velocidad del procesador y la llegada de bytes es la de la tarjeta.
// Solo se acelera el tick de 1 ms (cada 50 ciclos) para no simular los
// 10 ms del antirrebote. En Vivado, agregar programa.mem como fuente de
// simulacion.
// =====================================================================
`timescale 1ns/1ps

module tb_sistema_juego;

    localparam int  BAUD_DIV = 434;
    localparam real T_SYS    = 20.0;
    localparam real T_BIT    = BAUD_DIV * T_SYS;

    logic clk100 = 0;
    always #5 clk100 = ~clk100;

    logic btn_up = 0, btn_down = 0, btn_left = 0, btn_right = 0, btn_c = 0;
    logic btn_ok_n = 1, sw_sel = 0, rx = 1;
    logic tx, dp, pwm, sd, hs, vs;
    logic [6:0]  seg;
    logic [7:0]  an;
    logic [15:0] led;
    logic [3:0]  r, g, b;

    top #(
        .PROGRAM_FILE ("programa.mem"),
        .CLK_HZ       (200_000),
        .TICK_CYCLES  (50),
        .DEBOUNCE_MS  (10),
        .BAUD_DIV     (BAUD_DIV),
        .BAUD_X16_DIV (27)
    ) dut (
        .clk100_i(clk100),
        .btn_up_i(btn_up), .btn_down_i(btn_down), .btn_left_i(btn_left),
        .btn_right_i(btn_right), .btn_center_i(btn_c),
        .btn_cpu_reset_n_i(btn_ok_n), .sw_sel_i(sw_sel),
        .uart_rx_i(rx), .uart_tx_o(tx),
        .seg_o(seg), .dp_o(dp), .an_o(an), .led_o(led),
        .aud_pwm_o(pwm), .aud_sd_o(sd),
        .vga_r_o(r), .vga_g_o(g), .vga_b_o(b), .vga_hs_o(hs), .vga_vs_o(vs)
    );

    int fallos = 0;
    task automatic chequear(input string nombre, input logic cond);
        if (cond) $display("PASS %s", nombre);
        else begin $display("FAIL %s", nombre); fallos++; end
    endtask

    // ---- receptor de la linea TX: arma lineas terminadas en '\n' ----
    string lineas [0:63];
    string actual = "";
    int    n_lineas = 0, leidas = 0;
    logic [7:0] dato;

    initial begin
        wait (dut.rst == 1'b0);
        forever begin
            @(negedge tx);
            #(T_BIT * 1.5);
            for (int i = 0; i < 8; i++) begin dato[i] = tx; #(T_BIT); end
            if (dato == 8'h0A) begin
                lineas[n_lineas] = actual;
                n_lineas++;
                actual = "";
            end else
                actual = {actual, string'(dato)};
        end
    end

    task automatic esperar_linea(output string l);
        int espera = 0;
        while (n_lineas <= leidas && espera < 2_000_000) begin #(T_SYS); espera++; end
        if (n_lineas > leidas) begin l = lineas[leidas]; leidas++; end
        else l = "(nada)";
    endtask

    // envia los n caracteres de t (literal de texto, alineado a la derecha)
    task automatic uart_enviar(input logic [8*12-1:0] t, input int n);
        logic [7:0] c;
        for (int k = 0; k < n; k++) begin
            c = t[8*(n-1-k) +: 8];
            rx = 0; #(T_BIT);
            for (int i = 0; i < 8; i++) begin rx = c[i]; #(T_BIT); end
            rx = 1; #(T_BIT);
        end
    endtask

    // pulsacion: 14 ticks presionado (filtro de 10) y 14 soltado
    task automatic presionar(input int cual);
        case (cual)
            0: btn_up = 1;  1: btn_down = 1;  2: btn_left = 1;
            3: btn_right = 1;  5: btn_ok_n = 0;
        endcase
        #(T_SYS * 50 * 14);
        btn_up = 0; btn_down = 0; btn_left = 0; btn_right = 0; btn_ok_n = 1;
        #(T_SYS * 50 * 14);
    endtask

    function automatic logic [31:0] celda(input int j, f, c);
        return dut.u_ram.mem[j * 64 + f * 8 + c];
    endfunction

    localparam int ARRIBA = 0, ABAJO = 1, IZQ = 2, DER = 3, OK = 5;
    string l;

    initial begin
        esperar_linea(l);
        chequear($sformatf("arranque: #C (%s)", l), l == "#C");
        chequear("LED LD0 (colocacion)", led == 16'h0001);

        // J2 coloca mientras J1 coloca: las dos cosas a la vez
        fork
            uart_enviar("#P000H", 6);
            presionar(OK);                 // J1 barco 0 en (0,0) H
        join
        esperar_linea(l); chequear($sformatf("J2 barco 0 aceptado (%s)", l), l == "#A0");
        chequear("J1 barco 0 en (0,0)-(0,3)", celda(0,0,0) == 1 && celda(0,0,3) == 1 && celda(0,0,4) == 0);

        uart_enviar("#P100V", 6);             // traslapa
        esperar_linea(l); chequear($sformatf("J2 traslape rechazado (%s)", l), l == "#X12");
        uart_enviar("zz#P9", 5);              // basura: sin respuesta
        uart_enviar("#P120H", 6);
        esperar_linea(l); chequear($sformatf("J2 barco 1 aceptado tras basura (%s)", l), l == "#A1");

        presionar(ABAJO); presionar(ABAJO);
        presionar(OK);                     // J1 barco 1 en (2,0) H
        presionar(ABAJO); presionar(ABAJO);
        presionar(OK);                     // J1 barco 2 en (4,0) H
        chequear("J1 tres barcos colocados", dut.u_ram.mem[131] == 7);   // 0x220C

        uart_enviar("#P240H", 6);
        esperar_linea(l); chequear($sformatf("J2 barco 2 aceptado (%s)", l), l == "#A2");
        esperar_linea(l); chequear($sformatf("inicio de batalla (%s)", l), l == "#B");
        esperar_linea(l); chequear($sformatf("turno del J1 (%s)", l), l == "#T1");
        chequear("LED LD1 (batalla)", led == 16'h0002);

        // disparo del J1 a (0,0): impacto sobre el barco 0 del J2
        presionar(OK);
        esperar_linea(l); chequear($sformatf("disparo del J1 a (0,0): impacto (%s)", l), l == "#E00I");
        esperar_linea(l); chequear($sformatf("turno del J2 (%s)", l), l == "#T2");
        chequear("casilla (0,0) del J2 marcada disparada", celda(1,0,0) == 32'h5);
        chequear("tile del rival (5,11) en rojo", (dut.u_vga.u_mem.mem[5*20+11] & 7) == 3);

        // disparo del J2 a (7,7): fallo
        uart_enviar("#D77", 4);
        esperar_linea(l); chequear($sformatf("disparo del J2 a (7,7): fallo (%s)", l), l == "#R77F");
        esperar_linea(l); chequear($sformatf("vuelve el turno del J1 (%s)", l), l == "#T1");
        chequear("casilla (7,7) del J1 marcada disparada", celda(0,7,7) == 32'h4);
        chequear("tile propio (12,8) en blanco (fallo)", (dut.u_vga.u_mem.mem[12*20+8] & 7) == 4);
        chequear("disparos: J1 = 1, J2 = 1", dut.u_ram.mem[138] == 1 && dut.u_ram.mem[139] == 1);

        if (fallos == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL (%0d errores)", fallos);
        $finish;
    end

    initial begin
        #200ms;
        $display("FAIL tiempo de simulacion agotado");
        $finish;
    end

endmodule
