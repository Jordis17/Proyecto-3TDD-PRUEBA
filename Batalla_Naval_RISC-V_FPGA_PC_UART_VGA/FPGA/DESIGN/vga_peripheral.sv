// =====================================================================
// vga_peripheral.sv - Periferico VGA por tiles
//
// Memoria de video en 0x0001_1000 - 0x0001_17FF: una palabra por tile
// de una cuadricula de 20 x 15 tiles de 32 x 32 pixeles (300 tiles).
//
//   indice    = fila * 20 + columna
//   direccion = 0x0001_1000 + indice * 4      (addr_i = indice)
//
// Formato de la palabra (planteamiento, seccion 9.4):
//   [2:0]   color de fondo (paleta)
//   [7:3]   simbolo (0 = ninguno, ver glyph_rom.sv)
//   [8]     cursor: marco de 4 pixeles en el borde del tile
//   [11:9]  color del simbolo (paleta)
//   [31:12] reservado
//
// Interfaz del CPU igual a la de los demas perifericos, salvo que la
// direccion es de 9 bits porque el periferico se comporta como memoria.
// Actualizar un tile es una sola escritura (sw), sin esperar nada.
//
// Generacion de la imagen (dominio del reloj de pixel), en dos etapas:
//   etapa 1: con x, y se calcula el tile y se lee la memoria (registro
//            dentro de video_mem);
//   etapa 2: con la palabra leida se consulta la ROM de simbolos y la
//            paleta y se registra el color de salida.
// Los sincronismos, la zona visible y la posicion dentro del tile se
// retrasan dos ciclos para quedar alineados con el color.
// =====================================================================

module vga_peripheral (
    // lado del CPU (reloj del sistema)
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [8:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // lado del video (reloj de pixel)
    input  logic        clk_pix_i,
    input  logic        rst_pix_i,
    output logic [3:0]  vga_r_o,
    output logic [3:0]  vga_g_o,
    output logic [3:0]  vga_b_o,
    output logic        vga_hs_o,
    output logic        vga_vs_o
);

    // ---- temporizacion ----
    logic [9:0] x, y;
    logic       hs, vs, video_on;

    vga_sync u_sync (
        .clk_i(clk_pix_i), .rst_i(rst_pix_i),
        .x_o(x), .y_o(y), .hsync_o(hs), .vsync_o(vs), .video_on_o(video_on)
    );

    // ---- etapa 1: indice del tile y lectura de la memoria ----
    // fila * 20 = fila * 16 + fila * 4
    logic [3:0] fila_tile;
    logic [4:0] col_tile;
    logic [8:0] indice;

    assign fila_tile = y[8:5];
    assign col_tile  = x[9:5];
    assign indice    = {1'b0, fila_tile, 4'b0000} + {3'b000, fila_tile, 2'b00} + {4'b0000, col_tile};

    logic [31:0] palabra;

    video_mem u_mem (
        .clk_a_i(clk_i), .we_a_i(write_enable_i), .addr_a_i(addr_i),
        .wdata_a_i(wdata_i), .rdata_a_o(rdata_o),
        .clk_b_i(clk_pix_i), .addr_b_i(indice), .rdata_b_o(palabra)
    );

    // datos que acompanan a la palabra leida (un ciclo de retraso)
    logic [4:0] px1, py1;
    logic       on1, hs1, vs1;

    always_ff @(posedge clk_pix_i) begin
        px1 <= x[4:0];
        py1 <= y[4:0];
        on1 <= video_on;
        hs1 <= hs;
        vs1 <= vs;
    end

    // ---- etapa 2: simbolo, cursor y paleta ----
    logic [7:0] fila_glifo;
    logic       bit_glifo, borde;
    logic [2:0] indice_color;

    glyph_rom u_rom (
        .code_i(palabra[7:3]), .row_i(py1[4:2]), .bits_o(fila_glifo)
    );

    // cada pixel del simbolo ocupa 4 x 4 pixeles de pantalla
    assign bit_glifo = fila_glifo[3'd7 - px1[4:2]];
    assign borde     = (px1 < 5'd4) || (px1 > 5'd27) || (py1 < 5'd4) || (py1 > 5'd27);

    always_comb begin
        if (palabra[8] && borde)  indice_color = 3'd6;            // cursor amarillo
        else if (bit_glifo)       indice_color = palabra[11:9];   // simbolo
        else                      indice_color = palabra[2:0];    // fondo
    end

    logic [11:0] rgb;

    always_comb begin
        case (indice_color)
            3'd0:    rgb = 12'h000;   // negro: fondo
            3'd1:    rgb = 12'h05C;   // azul: agua
            3'd2:    rgb = 12'h888;   // gris: barco propio
            3'd3:    rgb = 12'hF00;   // rojo: impacto
            3'd4:    rgb = 12'hFFF;   // blanco: fallo, texto
            3'd5:    rgb = 12'h0C0;   // verde: vista previa
            3'd6:    rgb = 12'hFF0;   // amarillo: cursor
            default: rgb = 12'h006;   // azul oscuro
        endcase
    end

    logic [11:0] rgb_q;
    logic        hs_q, vs_q;

    always_ff @(posedge clk_pix_i) begin
        rgb_q <= on1 ? rgb : 12'h000;
        hs_q  <= hs1;
        vs_q  <= vs1;
    end

    assign {vga_r_o, vga_g_o, vga_b_o} = rgb_q;
    assign vga_hs_o = hs_q;
    assign vga_vs_o = vs_q;

endmodule
