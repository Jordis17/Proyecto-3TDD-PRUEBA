// =====================================================================
// tb_top.sv - Testbench autoverificable del sistema completo
//
// Simula top.sv con el programa programas/tb_top.mem (desde tb_top.s)
// y revisa cada periferico desde los pines de la tarjeta, pasando por
// el procesador, el bus y los perifericos reales:
//   - LED[0] se enciende;
//   - los displays muestran 12 (J1) y 34 (J2) en el barrido;
//   - la memoria de video tiene los dos tiles escritos y VGA genera
//     sincronismos;
//   - llega 'A' por la linea TX del UART;
//   - la salida de audio oscila (sonido de impacto);
//   - al presionar BTNU y CPU RESET se encienden LED[8] y LED[13];
//   - al enviar 0x55 por RX, el programa responde 0x56.
//
// Para acelerar: tick de "1 ms" cada 50 ciclos, 32 ciclos por bit en
// el UART y CLK_HZ reducido para el buzzer. En Vivado se simula con el
// PLL real (primitiva PLLE2_BASE de la biblioteca UNISIM).
// =====================================================================
`timescale 1ns/1ps

module tb_top;

    localparam int BAUD_DIV = 32;
    localparam real T_SYS   = 20.0;               // periodo de 50 MHz
    localparam real T_BIT   = BAUD_DIV * T_SYS;

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
        .PROGRAM_FILE ("tb_top.mem"),
        .CLK_HZ       (200_000),
        .TICK_CYCLES  (50),
        .DEBOUNCE_MS  (10),
        .BAUD_DIV     (BAUD_DIV),
        .BAUD_X16_DIV (2)
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

    // recibe un byte de la linea TX (8N1); ok = 0 si no llega a tiempo
    task automatic uart_recibir(output logic [7:0] dato, output logic ok);
        int espera;
        ok = 0; dato = 8'h00; espera = 0;
        while (tx == 1'b1 && espera < 400 * BAUD_DIV) begin
            #(T_SYS); espera++;
        end
        if (tx == 1'b0) begin
            #(T_BIT * 1.5);          // centro del bit 0
            for (int i = 0; i < 8; i++) begin
                dato[i] = tx;
                #(T_BIT);
            end
            ok = tx;                 // bit de parada en 1
        end
    endtask

    // envia un byte por la linea RX (8N1)
    task automatic uart_enviar(input logic [7:0] dato);
        rx = 0; #(T_BIT);
        for (int i = 0; i < 8; i++) begin rx = dato[i]; #(T_BIT); end
        rx = 1; #(T_BIT);
    endtask

    // espera a que un anodo este activo (en bajo) y devuelve los segmentos
    task automatic segmentos_en(input int anodo, output logic [6:0] s);
        wait (an[anodo] == 1'b0);
        #(T_SYS * 2);
        s = ~seg;
    endtask

    int flancos_pwm = 0, flancos_hs = 0;
    always @(posedge pwm) flancos_pwm++;
    always @(negedge hs)  flancos_hs++;

    logic [7:0] byte_rx;
    logic       ok;
    logic [6:0] s;

    initial begin
        // esperar a que el PLL enganche y termine el reinicio
        wait (dut.rst == 1'b0);
        #(T_SYS * 2);
        chequear("linea TX en reposo (1) al salir del reinicio", tx == 1'b1);

        // el primer byte que envia el programa es 'A'
        uart_recibir(byte_rx, ok);
        chequear($sformatf("UART TX envia 'A' (0x%h)", byte_rx), ok && byte_rx == 8'h41);

        #(T_SYS * 200);
        chequear("LED[0] encendido", led[0] == 1'b1);
        chequear("registro de displays = 0x1234", dut.u_seg.datos_q == 16'h1234);
        segmentos_en(5, s); chequear("AN5 muestra 1 (decenas J1)",  s == 7'b0000110);
        segmentos_en(4, s); chequear("AN4 muestra 2 (unidades J1)", s == 7'b1011011);
        segmentos_en(1, s); chequear("AN1 muestra 3 (decenas J2)",  s == 7'b1001111);
        segmentos_en(0, s); chequear("AN0 muestra 4 (unidades J2)", s == 7'b1100110);
        chequear("tile 0 = 0x810 en memoria de video",   dut.u_vga.u_mem.mem[0]   == 32'h810);
        chequear("tile 299 = 0x103 en memoria de video", dut.u_vga.u_mem.mem[299] == 32'h103);
        chequear("amplificador habilitado", sd == 1'b1);

        btn_up = 1;
        #(T_SYS * 50 * 14);
        chequear("BTNU presionado -> LED[8]", led[8] == 1'b1);
        btn_up = 0; btn_ok_n = 0;
        #(T_SYS * 50 * 14);
        chequear("CPU RESET presionado (BTN_OK) -> LED[13]", led[13] == 1'b1 && led[8] == 1'b0);
        btn_ok_n = 1;
        chequear($sformatf("salida de audio oscilo con el sonido de impacto (%0d flancos)", flancos_pwm),
                 flancos_pwm > 10);

        fork
            uart_enviar(8'h55);
            uart_recibir(byte_rx, ok);
        join
        chequear($sformatf("eco por UART: envia 0x55, recibe 0x%h", byte_rx), ok && byte_rx == 8'h56);

        // la simulacion dura pocas lineas VGA; la temporizacion completa
        // la valida tb_vga_peripheral
        chequear($sformatf("VGA genera HSYNC (%0d pulsos)", flancos_hs), flancos_hs >= 1);

        if (fallos == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL (%0d errores)", fallos);
        $finish;
    end

    initial begin
        #5ms;
        $display("FAIL tiempo de simulacion agotado");
        $finish;
    end

endmodule
