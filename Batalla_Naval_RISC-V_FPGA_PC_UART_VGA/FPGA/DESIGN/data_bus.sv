// =====================================================================
// data_bus.sv - Decodificador de direcciones del bus de datos
//
// Conecta el bus de datos del procesador (DataAddress, DataOut, we,
// DataIn) con la RAM y los perifericos segun el mapa de memoria del
// enunciado (planteamiento, secciones 7.2 y 7.3):
//
//   RAM          0x0000_2000 - 0x0000_2FFF   addr = [11:2]
//   UART         0x0001_0040 - 0x0001_004F   addr = [3:2]
//   Entradas J1  0x0001_0120 - 0x0001_012F   addr = [3:2]
//   Displays     0x0001_0130 - 0x0001_0137   addr = {0, [2]}
//   LED          0x0001_0138 - 0x0001_013F   addr = {0, [2]}
//   Buzzer       0x0001_0140 - 0x0001_014F   addr = [3:2]
//   Video        0x0001_1000 - 0x0001_17FF   addr = [10:2]
//
// Displays y LED se separan en bloques de 8 bytes porque el enunciado
// ubica el LED en 0x138, dentro del bloque de 16 bytes de los displays.
//
// Solo el destino seleccionado recibe we. Una direccion que no
// pertenece a ninguna region lee 0 y una escritura ahi no tiene efecto.
// Todo es combinacional: el dato leido llega en el mismo ciclo.
// =====================================================================

module data_bus (
    // lado del procesador
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        we_i,
    output logic [31:0] rdata_o,

    // dato de escritura comun para todos los destinos
    output logic [31:0] wdata_o,

    // RAM
    output logic        ram_we_o,
    output logic [9:0]  ram_addr_o,
    input  logic [31:0] ram_rdata_i,

    // perifericos de registros: comparten addr de 2 bits
    output logic [1:0]  reg_addr_o,
    output logic        uart_we_o,
    input  logic [31:0] uart_rdata_i,
    output logic        in_we_o,
    input  logic [31:0] in_rdata_i,
    output logic        seg_we_o,
    input  logic [31:0] seg_rdata_i,
    output logic        led_we_o,
    input  logic [31:0] led_rdata_i,
    output logic        buz_we_o,
    input  logic [31:0] buz_rdata_i,

    // memoria de video
    output logic        vga_we_o,
    output logic [8:0]  vga_addr_o,
    input  logic [31:0] vga_rdata_i
);

    logic sel_ram, sel_uart, sel_in, sel_seg, sel_led, sel_buz, sel_vga;

    assign sel_ram  = (addr_i[31:12] == 20'h0_0002);
    assign sel_uart = (addr_i[31:4]  == 28'h000_1004);
    assign sel_in   = (addr_i[31:4]  == 28'h000_1012);
    assign sel_seg  = (addr_i[31:3]  == 29'h0000_2026);   // 0x1_0130 >> 3
    assign sel_led  = (addr_i[31:3]  == 29'h0000_2027);   // 0x1_0138 >> 3
    assign sel_buz  = (addr_i[31:4]  == 28'h000_1014);
    assign sel_vga  = (addr_i[31:11] == 21'h00_0022);     // 0x1_1000 >> 11

    assign wdata_o    = wdata_i;
    assign ram_addr_o = addr_i[11:2];
    assign vga_addr_o = addr_i[10:2];
    // Displays y LED tienen bloques de 8 bytes: solo el bit 2 elige
    // registro.
    assign reg_addr_o = (sel_seg || sel_led) ? {1'b0, addr_i[2]} : addr_i[3:2];

    assign ram_we_o  = we_i && sel_ram;
    assign uart_we_o = we_i && sel_uart;
    assign in_we_o   = we_i && sel_in;
    assign seg_we_o  = we_i && sel_seg;
    assign led_we_o  = we_i && sel_led;
    assign buz_we_o  = we_i && sel_buz;
    assign vga_we_o  = we_i && sel_vga;

    always_comb begin
        if      (sel_ram)  rdata_o = ram_rdata_i;
        else if (sel_uart) rdata_o = uart_rdata_i;
        else if (sel_in)   rdata_o = in_rdata_i;
        else if (sel_seg)  rdata_o = seg_rdata_i;
        else if (sel_led)  rdata_o = led_rdata_i;
        else if (sel_buz)  rdata_o = buz_rdata_i;
        else if (sel_vga)  rdata_o = vga_rdata_i;
        else               rdata_o = 32'd0;
    end

endmodule
