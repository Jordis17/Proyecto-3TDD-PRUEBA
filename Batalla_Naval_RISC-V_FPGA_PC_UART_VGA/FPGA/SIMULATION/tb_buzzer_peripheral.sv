// =====================================================================
// tb_buzzer_peripheral.sv - Testbench autoverificable del buzzer
//
// Para acelerar la simulacion se usa CLK_HZ = 1 MHz y un tick cada
// 1000 ciclos (1 ms). Para cada evento se mide sobre la onda de salida
// la frecuencia de cada tono (contando ciclos entre flancos) y la
// duracion total (tiempo con busy en 1), y se comparan con la tabla.
// Tambien revisa que un evento nuevo reemplace al que suena y que un
// codigo invalido no haga nada.
// =====================================================================
`timescale 1ns/1ps

module tb_buzzer_peripheral;

    localparam int CLK_HZ = 1_000_000;

    logic        clk = 0, rst = 1, we = 0, tick = 0;
    logic [1:0]  addr = 0;
    logic [31:0] wdata = 0, rdata;
    logic        pwm, sd;

    always #500 clk = ~clk;   // 1 MHz

    int c = 0;
    always @(posedge clk) begin
        c    <= (c == 999) ? 0 : c + 1;
        tick <= (c == 999);
    end

    buzzer_peripheral #(.CLK_HZ(CLK_HZ)) dut (
        .clk_i(clk), .rst_i(rst), .write_enable_i(we), .addr_i(addr),
        .wdata_i(wdata), .rdata_o(rdata), .tick_i(tick),
        .aud_pwm_o(pwm), .aud_sd_o(sd)
    );

    int fallos = 0;

    task automatic chequear(input string nombre, input logic cond);
        if (cond) $display("PASS %s", nombre);
        else begin $display("FAIL %s", nombre); fallos++; end
    endtask

    task automatic disparar(input logic [2:0] ev);
        @(negedge clk); wdata = {29'd0, ev}; we = 1; @(negedge clk); we = 0;
    endtask

    // Mide los tonos del evento en curso hasta que busy baja. Para cada
    // tono (segun el contador interno tono_q) cuenta los flancos de
    // subida de la onda y el tiempo entre el primero y el ultimo:
    // frecuencia = (flancos - 1) * CLK_HZ / ciclos. Deja los resultados
    // en f[0..2], n_tonos y dur_ms.
    int f [0:2];
    int n_tonos, dur_ms;

    task automatic medir();
        int t, total, tono, flancos, t_primero, t_ultimo;
        logic pwm_ant;
        for (int i = 0; i < 3; i++) f[i] = 0;
        n_tonos = 0; t = 0; total = 0; tono = 0; flancos = 0;
        t_primero = 0; t_ultimo = 0; pwm_ant = 0;
        while (dut.busy) begin
            @(posedge clk); #1;
            t++; total++;
            if (dut.u_tonos.tono_q != tono) begin
                if (flancos > 1) f[tono] = (flancos - 1) * CLK_HZ / (t_ultimo - t_primero);
                tono = dut.u_tonos.tono_q; flancos = 0;
            end
            if (pwm && !pwm_ant) begin
                if (flancos == 0) t_primero = t;
                t_ultimo = t;
                flancos++;
            end
            pwm_ant = pwm;
        end
        if (flancos > 1) f[tono] = (flancos - 1) * CLK_HZ / (t_ultimo - t_primero);
        n_tonos = tono + 1;
        dur_ms  = (total + 500) / 1000;
    endtask

    function automatic logic cerca(input int medido, esperado);
        return (medido >= esperado * 97 / 100) && (medido <= esperado * 103 / 100);
    endfunction

    initial begin
        repeat (5) @(posedge clk);
        rst = 0;
        repeat (2000) @(posedge clk);
        #1 chequear("en reposo busy = 0 y amplificador habilitado", rdata[0] == 0 && sd == 1);

        disparar(3'd1); #1 chequear("impacto: busy = 1 al iniciar", rdata[0] == 1);
        medir();
        chequear($sformatf("impacto: 1 tono 2000 Hz (%0d Hz), 100 ms (%0d ms)", f[0], dur_ms),
                 n_tonos == 1 && cerca(f[0], 2000) && cerca(dur_ms, 100));

        disparar(3'd2); medir();
        chequear($sformatf("fallo: 500 Hz (%0d Hz), 150 ms (%0d ms)", f[0], dur_ms),
                 n_tonos == 1 && cerca(f[0], 500) && cerca(dur_ms, 150));

        disparar(3'd3); medir();
        chequear($sformatf("hundido: 3000/2000/3000 Hz (%0d/%0d/%0d), 240 ms (%0d ms)",
                           f[0], f[1], f[2], dur_ms),
                 n_tonos == 3 && cerca(f[0], 3000) && cerca(f[1], 2000) && cerca(f[2], 3000) && cerca(dur_ms, 240));

        disparar(3'd4); medir();
        chequear($sformatf("colocacion invalida: 250 Hz (%0d Hz), 250 ms (%0d ms)", f[0], dur_ms),
                 n_tonos == 1 && cerca(f[0], 250) && cerca(dur_ms, 250));

        disparar(3'd5); medir();
        chequear($sformatf("victoria: 2000/2500/3000 Hz (%0d/%0d/%0d), 450 ms (%0d ms)",
                           f[0], f[1], f[2], dur_ms),
                 n_tonos == 3 && cerca(f[0], 2000) && cerca(f[1], 2500) && cerca(f[2], 3000) && cerca(dur_ms, 450));

        // reemplazo: fallo interrumpido por victoria
        disparar(3'd2);
        repeat (50_000) @(posedge clk);
        disparar(3'd5); #1
        chequear("evento nuevo reemplaza al actual", dut.u_tonos.ev_q == 3'd5 && dut.u_tonos.tono_q == 0);
        medir();

        // codigos invalidos
        disparar(3'd0); #1 chequear("evento 0 no suena", rdata[0] == 0);
        disparar(3'd7); #1 chequear("evento 7 no suena", rdata[0] == 0);

        if (fallos == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL (%0d errores)", fallos);
        $finish;
    end

endmodule
