// =====================================================================
// tb_cpu_bus.sv - Testbench autoverificable de memorias y bus de datos
//
// Conecta el procesador con la ROM, la RAM y el decodificador reales
// (rom.sv, ram.sv, data_bus.sv). Los perifericos se reemplazan por
// modelos simples de 4 registros que, al leer, devuelven el valor
// guardado XOR una marca propia de cada periferico; la memoria de video
// se modela como 512 palabras.
//
// La ROM se carga con programas/tb_bus.mem (generado desde tb_bus.s).
// En Vivado, agregar tb_bus.mem como fuente de simulacion para que el
// simulador lo encuentre.
//
// Revisa:
//   - las 15 firmas que el programa deja en la RAM desde 0x2100;
//   - que cada periferico recibio exactamente las escrituras esperadas
//     (LED y displays no se mezclan, 0x1_0100 no llega a nadie).
// =====================================================================
`timescale 1ns/1ps

module tb_cpu_bus;

    localparam int MAX_CICLOS = 2000;

    logic clk = 1'b0, rst = 1'b1;
    always #10 clk = ~clk;

    logic [31:0] prog_addr, prog_in, data_addr, data_out, data_in;
    logic        we;

    riscv_core u_cpu (
        .clk_i(clk), .rst_i(rst),
        .ProgAddress_o(prog_addr), .ProgIn_i(prog_in),
        .DataAddress_o(data_addr), .DataOut_o(data_out),
        .DataIn_i(data_in), .we_o(we)
    );

    rom #(.INIT_FILE("tb_bus.mem")) u_rom (.addr_i(prog_addr), .data_o(prog_in));

    logic [31:0] wdata, ram_rdata;
    logic        ram_we;
    logic [9:0]  ram_addr;
    logic [1:0]  reg_addr;
    logic        uart_we, in_we, seg_we, led_we, buz_we, vga_we;
    logic [8:0]  vga_addr;
    logic [31:0] uart_rd, in_rd, seg_rd, led_rd, buz_rd, vga_rd;

    ram u_ram (.clk_i(clk), .we_i(ram_we), .addr_i(ram_addr),
               .wdata_i(wdata), .rdata_o(ram_rdata));

    data_bus u_bus (
        .addr_i(data_addr), .wdata_i(data_out), .we_i(we), .rdata_o(data_in),
        .wdata_o(wdata),
        .ram_we_o(ram_we), .ram_addr_o(ram_addr), .ram_rdata_i(ram_rdata),
        .reg_addr_o(reg_addr),
        .uart_we_o(uart_we), .uart_rdata_i(uart_rd),
        .in_we_o(in_we),     .in_rdata_i(in_rd),
        .seg_we_o(seg_we),   .seg_rdata_i(seg_rd),
        .led_we_o(led_we),   .led_rdata_i(led_rd),
        .buz_we_o(buz_we),   .buz_rdata_i(buz_rd),
        .vga_we_o(vga_we),   .vga_addr_o(vga_addr), .vga_rdata_i(vga_rd)
    );

    // ---- modelos de perifericos ----
    logic [31:0] r_uart [0:3], r_in [0:3], r_seg [0:3], r_led [0:3], r_buz [0:3];
    logic [31:0] vmem [0:511];
    int          n_esc [0:5];   // escrituras por destino: uart,in,seg,led,buz,vga

    initial begin
        for (int i = 0; i < 4; i++) begin
            r_uart[i] = 0; r_in[i] = 0; r_seg[i] = 0; r_led[i] = 0; r_buz[i] = 0;
        end
        for (int i = 0; i < 512; i++) vmem[i] = 0;
        for (int i = 0; i < 6; i++) n_esc[i] = 0;
    end

    always @(posedge clk) begin
        if (uart_we) begin r_uart[reg_addr] <= wdata; n_esc[0]++; end
        if (in_we)   begin r_in[reg_addr]   <= wdata; n_esc[1]++; end
        if (seg_we)  begin r_seg[reg_addr]  <= wdata; n_esc[2]++; end
        if (led_we)  begin r_led[reg_addr]  <= wdata; n_esc[3]++; end
        if (buz_we)  begin r_buz[reg_addr]  <= wdata; n_esc[4]++; end
        if (vga_we)  begin vmem[vga_addr]   <= wdata; n_esc[5]++; end
    end

    assign uart_rd = r_uart[reg_addr] ^ 32'h1000_0000;
    assign in_rd   = r_in[reg_addr]   ^ 32'h2000_0000;
    assign seg_rd  = r_seg[reg_addr]  ^ 32'h3000_0000;
    assign led_rd  = r_led[reg_addr]  ^ 32'h4000_0000;
    assign buz_rd  = r_buz[reg_addr]  ^ 32'h5000_0000;
    assign vga_rd  = vmem[vga_addr];

    // ---- verificacion ----
    int fallos = 0;

    task automatic revisar(input string nombre, input logic [31:0] obtenido, esperado);
        if (obtenido === esperado) $display("PASS %-28s %h", nombre, obtenido);
        else begin
            $display("FAIL %-28s esperado=%h obtenido=%h", nombre, esperado, obtenido);
            fallos++;
        end
    endtask

    task automatic revisar_n(input string nombre, input int obtenido, esperado);
        if (obtenido == esperado) $display("PASS %-28s %0d", nombre, obtenido);
        else begin
            $display("FAIL %-28s esperado=%0d obtenido=%0d", nombre, esperado, obtenido);
            fallos++;
        end
    endtask

    int ciclos = 0, estable = 0;
    logic [31:0] pc_ant;

    initial begin
        repeat (3) @(posedge clk);
        rst <= 1'b0;
        pc_ant = '1;
        while (ciclos < MAX_CICLOS && estable < 3) begin
            @(posedge clk);
            ciclos++;
            estable = (prog_addr == pc_ant) ? estable + 1 : 0;
            pc_ant  = prog_addr;
        end
        if (estable < 3) begin
            $display("FAIL el programa no termino");
            fallos++;
        end

        // firmas en 0x2100 = palabra 64 de la RAM
        revisar("RAM primera palabra",       u_ram.mem[64], 32'h0000_0011);
        revisar("RAM ultima palabra",        u_ram.mem[65], 32'h0000_0022);
        revisar("UART registro 0 (0x40)",    u_ram.mem[66], 32'h1000_0031);
        revisar("UART registro 1 (0x44)",    u_ram.mem[67], 32'h1000_0032);
        revisar("UART registro 2 (0x48)",    u_ram.mem[68], 32'h1000_0033);
        revisar("Entradas (0x120)",          u_ram.mem[69], 32'h2000_0041);
        revisar("Displays (0x130)",          u_ram.mem[70], 32'h3000_0051);
        revisar("LED (0x138)",               u_ram.mem[71], 32'h4000_0061);
        revisar("LED registro 1 (0x13C)",    u_ram.mem[72], 32'h4000_0062);
        revisar("Buzzer (0x140)",            u_ram.mem[73], 32'h5000_0071);
        revisar("Video primer tile",         u_ram.mem[74], 32'h0000_0081);
        revisar("Video ultimo (0x117FC)",    u_ram.mem[75], 32'h0000_0082);
        revisar("Lectura sin asignar 0x10100", u_ram.mem[76], 32'h0);
        revisar("Lectura 0x3000 (tras RAM)", u_ram.mem[77], 32'h0);
        revisar("Lectura 0x11800 (tras video)", u_ram.mem[78], 32'h0);
        revisar("RAM 0x2000 directo",        u_ram.mem[0],    32'h11);
        revisar("RAM 0x2FFC directo",        u_ram.mem[1023], 32'h22);

        revisar_n("escrituras UART",    n_esc[0], 3);
        revisar_n("escrituras entradas", n_esc[1], 1);
        revisar_n("escrituras displays", n_esc[2], 1);
        revisar_n("escrituras LED",     n_esc[3], 2);
        revisar_n("escrituras buzzer",  n_esc[4], 1);
        revisar_n("escrituras video",   n_esc[5], 2);
        revisar("displays reg 1 intacto", r_seg[1], 32'h0);

        if (fallos == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL (%0d errores)", fallos);
        $finish;
    end

endmodule
