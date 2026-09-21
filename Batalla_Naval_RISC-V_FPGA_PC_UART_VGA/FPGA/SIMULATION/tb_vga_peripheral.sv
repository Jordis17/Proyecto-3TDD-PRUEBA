// =====================================================================
// tb_vga_peripheral.sv - Testbench autoverificable del periferico VGA
//
// Relojes independientes: sistema a 50 MHz y pixel a 25 MHz.
//
// 1. Temporizacion, medida sobre las salidas: linea de 800 ciclos,
//    HSYNC bajo 96 ciclos, cuadro de 525 lineas, VSYNC bajo 2 lineas.
// 2. Puerto del CPU: escritura y lectura de tiles (primero y ultimo).
// 3. Imagen: el testbench reconstruye la posicion (x, y) de cada pixel
//    a partir de los flancos de HSYNC y VSYNC de salida (HSYNC baja en
//    x = 656, VSYNC baja en y = 490) y revisa el color en puntos
//    elegidos: fondo, simbolo, marco del cursor, tile sin escribir y
//    zona no visible. Si el color saliera desfasado de los
//    sincronismos, estas pruebas fallan.
// =====================================================================
`timescale 1ns/1ps

module tb_vga_peripheral;

    logic clk = 0, clk_pix = 0, rst = 1, rst_pix = 1;
    always #10 clk = ~clk;            // 50 MHz
    always #20.3 clk_pix = ~clk_pix;  // ~25 MHz, sin relacion de fase con clk

    logic        we = 0;
    logic [8:0]  addr = 0;
    logic [31:0] wdata = 0, rdata;
    logic [3:0]  r, g, b;
    logic        hs, vs;

    vga_peripheral dut (
        .clk_i(clk), .rst_i(rst), .write_enable_i(we), .addr_i(addr),
        .wdata_i(wdata), .rdata_o(rdata),
        .clk_pix_i(clk_pix), .rst_pix_i(rst_pix),
        .vga_r_o(r), .vga_g_o(g), .vga_b_o(b), .vga_hs_o(hs), .vga_vs_o(vs)
    );

    int fallos = 0;

    task automatic chequear(input string nombre, input logic cond);
        if (cond) $display("PASS %s", nombre);
        else begin $display("FAIL %s", nombre); fallos++; end
    endtask

    task automatic escribir(input int fila, input int col, input logic [31:0] v);
        @(negedge clk); addr = 9'(fila * 20 + col); wdata = v; we = 1;
        @(negedge clk); we = 0;
    endtask

    // ---- medicion de temporizacion sobre las salidas ----
    int  t = 0, t_hs_baja = -1, t_hs_sube = -1, t_hs_baja_ant = -1;
    int  ancho_hs = 0, periodo_linea = 0;
    int  lineas = 0, lineas_cuadro = 0, t_vs_baja = -1, ancho_vs = 0;
    logic hs_ant = 1, vs_ant = 1;

    // ---- posicion reconstruida del pixel de salida ----
    int  hx = -1, vy = -1;

    // Puntos donde se captura el color. La captura la hace el mismo
    // bloque que reconstruye la posicion, asi no hay carreras.
    localparam int NP = 14;
    int          px [0:NP-1], py [0:NP-1];
    logic [11:0] capturado [0:NP-1];
    logic        capturar = 0;

    // Se muestrea en el flanco de bajada, cuando las salidas registradas
    // en el flanco de subida ya estan estables.
    always @(negedge clk_pix) begin
        t++;
        // flancos de HSYNC
        if (!hs && hs_ant) begin
            if (t_hs_baja >= 0) periodo_linea = t - t_hs_baja;
            t_hs_baja = t;
            lineas++;
        end
        if (hs && !hs_ant && t_hs_baja >= 0) ancho_hs = t - t_hs_baja;
        // flancos de VSYNC
        if (!vs && vs_ant) begin
            if (lineas > 0 && vy >= 0) lineas_cuadro = lineas;
            lineas = 0;
            t_vs_baja = t;
        end
        if (vs && !vs_ant && t_vs_baja >= 0) ancho_vs = t - t_vs_baja;
        // posicion: HSYNC baja en x = 656; VSYNC baja en y = 490
        if (hx >= 0) hx = (hx == 799) ? 0 : hx + 1;
        if (!hs && hs_ant) hx = 656;
        if (hx == 0 && vy >= 0) vy = (vy == 524) ? 0 : vy + 1;
        if (!vs && vs_ant) vy = 490;
        hs_ant = hs;
        vs_ant = vs;
        if (capturar)
            for (int i = 0; i < NP; i++)
                if (hx == px[i] && vy == py[i]) capturado[i] = {r, g, b};
    end

    // pide los puntos, deja pasar un cuadro completo y los devuelve
    task automatic capturar_cuadro();
        for (int i = 0; i < NP; i++) capturado[i] = 12'hXXX;
        wait (vy == 0);
        capturar = 1;
        wait (vy == 490);
        capturar = 0;
    endtask

    task automatic punto(input int i, input string nombre, input logic [11:0] esperado);
        chequear($sformatf("%s en (%0d,%0d): %h", nombre, px[i], py[i], capturado[i]),
                 capturado[i] === esperado);
    endtask

    task automatic definir(input int i, input int x, input int y);
        px[i] = x; py[i] = y;
    endtask


    initial begin
        repeat (4) @(posedge clk);
        rst = 0;
        @(posedge clk_pix); rst_pix = 0;

        // tiles de prueba
        escribir(0, 0, {20'd0, 3'd4, 1'b0, 5'd2, 3'd0});    // '1' blanco sobre negro
        escribir(5, 1, {20'd0, 3'd0, 1'b0, 5'd0, 3'd1});    // agua
        escribir(14, 19, {20'd0, 3'd0, 1'b1, 5'd0, 3'd3});  // impacto con cursor (indice 299)

        @(negedge clk); addr = 9'd0; #1
        chequear("CPU lee el tile 0", rdata == 32'h0000_0810);
        addr = 9'd299; #1
        chequear("CPU lee el tile 299", rdata == 32'h0000_0103);
        addr = 9'd150; #1
        chequear("tile sin escribir lee 0", rdata == 32'd0);

        // se deja pasar un cuadro completo para medir
        wait (vy == 0);
        wait (vy == 100);
        chequear($sformatf("periodo de linea = 800 (%0d)", periodo_linea), periodo_linea == 800);
        chequear($sformatf("HSYNC bajo 96 ciclos (%0d)", ancho_hs), ancho_hs == 96);
        wait (vy == 495);
        wait (vy == 100);
        chequear($sformatf("cuadro de 525 lineas (%0d)", lineas_cuadro), lineas_cuadro == 525);
        chequear($sformatf("VSYNC bajo 2 lineas = 1600 ciclos (%0d)", ancho_vs), ancho_vs == 1600);

        definir(0, 2, 1);      definir(1, 11, 1);     definir(2, 12, 1);
        definir(3, 19, 1);     definir(4, 20, 1);     definir(5, 5, 25);
        definir(6, 48, 176);   definir(7, 700, 200);  definir(8, 250, 250);
        definir(9, 609, 449);  definir(10, 611, 452); definir(11, 612, 452);
        definir(12, 624, 464); definir(13, 639, 479);
        capturar_cuadro();

        punto(0,  "simbolo '1' fuera del trazo, negro",           12'h000);
        punto(1,  "simbolo '1' x=11 justo antes del trazo, negro", 12'h000);
        punto(2,  "simbolo '1' x=12 primer pixel del trazo, blanco", 12'hFFF);
        punto(3,  "simbolo '1' x=19 ultimo pixel del trazo, blanco", 12'hFFF);
        punto(4,  "simbolo '1' x=20 despues del trazo, negro",     12'h000);
        punto(5,  "simbolo '1' base, blanco",                      12'hFFF);
        punto(6,  "tile (5,1) agua",                               12'h05C);
        punto(7,  "zona no visible, negro",                        12'h000);
        punto(8,  "tile sin escribir, negro",                      12'h000);
        punto(9,  "tile (14,19) marco del cursor, amarillo",       12'hFF0);
        punto(10, "tile (14,19) x=611 ultimo pixel del marco",     12'hFF0);
        punto(11, "tile (14,19) x=612 primer pixel interior, rojo", 12'hF00);
        punto(12, "tile (14,19) centro, rojo",                     12'hF00);
        punto(13, "ultimo pixel visible (marco), amarillo",        12'hFF0);

        // cambio de un tile con una sola escritura
        escribir(5, 1, {20'd0, 3'd0, 1'b0, 5'd0, 3'd4});    // ahora fallo (blanco)
        capturar_cuadro();
        punto(6,  "tile (5,1) actualizado con un sw, blanco",      12'hFFF);

        if (fallos == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL (%0d errores)", fallos);
        $finish;
    end

    initial begin
        #100ms;
        $display("FAIL tiempo de simulacion agotado");
        $finish;
    end

endmodule
