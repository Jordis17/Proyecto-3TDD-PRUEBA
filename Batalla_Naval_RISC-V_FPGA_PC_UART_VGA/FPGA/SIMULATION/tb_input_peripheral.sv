// =====================================================================
// tb_input_peripheral.sv - Testbench autoverificable de las entradas
//
// Para acelerar la simulacion el tick de "1 ms" se genera cada 20
// ciclos; el filtro sigue exigiendo DEBOUNCE_MS = 10 ticks estables.
//
// Revisa:
//   - cada entrada aparece en su bit despues del filtro;
//   - un rebote mas corto que el filtro no cambia el registro;
//   - BTN_OK (CPU RESET) es activo en bajo y se lee como 1 presionado;
//   - las escrituras no cambian nada y addr != 00 lee 0.
// =====================================================================
`timescale 1ns/1ps

module tb_input_peripheral;

    localparam int CICLOS_TICK = 20;

    logic        clk = 0, rst = 1, we = 0, tick = 0;
    logic [1:0]  addr = 0;
    logic [31:0] wdata = 0, rdata;
    logic        up = 0, down = 0, left = 0, right = 0, sel = 0, ok_n = 1, brst = 0;

    always #10 clk = ~clk;

    int cnt_tick = 0;
    always @(posedge clk) begin
        cnt_tick <= (cnt_tick == CICLOS_TICK - 1) ? 0 : cnt_tick + 1;
        tick     <= (cnt_tick == CICLOS_TICK - 1);
    end

    input_peripheral #(.DEBOUNCE_MS(10)) dut (
        .clk_i(clk), .rst_i(rst), .write_enable_i(we), .addr_i(addr),
        .wdata_i(wdata), .rdata_o(rdata), .tick_i(tick),
        .btn_up_i(up), .btn_down_i(down), .btn_left_i(left), .btn_right_i(right),
        .sw_sel_i(sel), .btn_ok_n_i(ok_n), .btn_rst_i(brst)
    );

    int fallos = 0;

    task automatic esperar_ticks(input int n);
        repeat (n * CICLOS_TICK) @(posedge clk);
    endtask

    task automatic revisar(input string nombre, input logic [31:0] esperado);
        #1;
        if (rdata === esperado) $display("PASS %-36s %h", nombre, rdata);
        else begin
            $display("FAIL %-36s esperado=%h obtenido=%h", nombre, esperado, rdata);
            fallos++;
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rst = 0;
        esperar_ticks(12);
        revisar("reposo: todo en 0", 32'h00);

        up = 1;    esperar_ticks(12); revisar("arriba -> bit 0", 32'h01); up = 0;
        esperar_ticks(12);
        down = 1;  esperar_ticks(12); revisar("abajo -> bit 1", 32'h02); down = 0;
        esperar_ticks(12);
        left = 1;  esperar_ticks(12); revisar("izquierda -> bit 2", 32'h04); left = 0;
        esperar_ticks(12);
        right = 1; esperar_ticks(12); revisar("derecha -> bit 3", 32'h08); right = 0;
        esperar_ticks(12);
        sel = 1;   esperar_ticks(12); revisar("SW0 (SEL) -> bit 4", 32'h10);
        ok_n = 0;  esperar_ticks(12); revisar("CPU RESET en 0 (OK) -> bit 5", 32'h30);
        ok_n = 1; sel = 0;
        esperar_ticks(12);
        brst = 1;  esperar_ticks(12); revisar("BTNC (RST) -> bit 6", 32'h40); brst = 0;
        esperar_ticks(12);
        revisar("todo soltado", 32'h00);

        // rebote: pulsos de 3 ticks, mas cortos que el filtro de 10
        repeat (4) begin
            up = 1; esperar_ticks(3);
            up = 0; esperar_ticks(3);
        end
        revisar("rebote corto no se acepta", 32'h00);

        // nivel estable menos de 10 ticks tampoco
        up = 1; esperar_ticks(8);
        revisar("8 ticks estable: aun 0", 32'h00);
        esperar_ticks(4);
        revisar("12 ticks estable: 1", 32'h01);

        // escritura ignorada y otras direcciones
        @(negedge clk); we = 1; wdata = 32'hFFFF_FFFF; @(negedge clk); we = 0;
        revisar("escritura ignorada", 32'h01);
        addr = 2'b01; revisar("addr 01 lee 0", 32'h00);
        addr = 2'b00; up = 0;

        if (fallos == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL (%0d errores)", fallos);
        $finish;
    end

endmodule
