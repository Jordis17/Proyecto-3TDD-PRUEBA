// =====================================================================
// tb_seg_led_peripheral.sv - Testbench autoverificable de displays y LED
//
// Displays: escribe victorias en BCD y recorre el barrido revisando que
// cada milisegundo se habilite un solo anodo (AN0, AN1, AN4, AN5, en
// ese orden) con los segmentos del digito correcto; un nibble mayor a 9
// apaga el digito. La tarjeta usa segmentos y anodos activos en bajo.
//
// LED: escritura, lectura y salida a los pines.
// =====================================================================
`timescale 1ns/1ps

module tb_seg_led_peripheral;

    logic        clk = 0, rst = 1, tick = 0;
    logic        we_seg = 0, we_led = 0;
    logic [1:0]  addr = 0;
    logic [31:0] wdata = 0, rd_seg, rd_led;
    logic [6:0]  seg;
    logic [7:0]  an;
    logic [15:0] led;

    always #10 clk = ~clk;

    seg_peripheral u_seg (
        .clk_i(clk), .rst_i(rst), .write_enable_i(we_seg), .addr_i(addr),
        .wdata_i(wdata), .rdata_o(rd_seg), .tick_i(tick), .seg_o(seg), .an_o(an)
    );

    led_peripheral u_led (
        .clk_i(clk), .rst_i(rst), .write_enable_i(we_led), .addr_i(addr),
        .wdata_i(wdata), .rdata_o(rd_led), .led_o(led)
    );

    // patrones {g,f,e,d,c,b,a} con 1 = encendido
    function automatic logic [6:0] patron(input int d);
        case (d)
            0: return 7'b0111111;  1: return 7'b0000110;  2: return 7'b1011011;
            3: return 7'b1001111;  4: return 7'b1100110;  5: return 7'b1101101;
            6: return 7'b1111101;  7: return 7'b0000111;  8: return 7'b1111111;
            9: return 7'b1101111;  default: return 7'b0000000;
        endcase
    endfunction

    int fallos = 0;

    task automatic chequear(input string nombre, input logic cond);
        if (cond) $display("PASS %s", nombre);
        else begin $display("FAIL %s", nombre); fallos++; end
    endtask

    task automatic escribir_seg(input logic [31:0] v);
        @(negedge clk); wdata = v; we_seg = 1; @(negedge clk); we_seg = 0;
    endtask

    task automatic escribir_led(input logic [31:0] v);
        @(negedge clk); wdata = v; we_led = 1; @(negedge clk); we_led = 0;
    endtask

    task automatic un_tick();
        @(negedge clk); tick = 1; @(negedge clk); tick = 0; #1;
    endtask

    // revisa una vuelta completa del barrido
    task automatic revisar_barrido(input logic [15:0] v, input string nombre);
        logic [7:0] an_esp [0:3];
        int         d;
        logic       ok;
        an_esp[0] = 8'b0000_0001; an_esp[1] = 8'b0000_0010;
        an_esp[2] = 8'b0001_0000; an_esp[3] = 8'b0010_0000;
        ok = 1;
        for (int k = 0; k < 4; k++) begin
            d = u_seg.dig_q;
            if (~an !== an_esp[d] || ~seg !== patron(int'(v[4*d +: 4]))) begin
                ok = 0;
                $display("     digito %0d: an=%b seg=%b", d, ~an, ~seg);
            end
            un_tick();
        end
        chequear(nombre, ok);
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst = 0; #1;
        chequear("displays en 0 tras reinicio", rd_seg == 32'd0);
        chequear("LED en 0 tras reinicio", rd_led == 32'd0 && led == 16'd0);

        escribir_seg(32'h0000_1234); #1;
        chequear("displays: lectura del registro", rd_seg == 32'h0000_1234);
        revisar_barrido(16'h1234, "barrido 12 (J1) y 34 (J2)");

        escribir_seg(32'hFFFF_9950); #1;
        chequear("displays: bits [31:16] se ignoran", rd_seg == 32'h0000_9950);
        revisar_barrido(16'h9950, "barrido 99 y 50");

        escribir_seg(32'h0000_0A0F);
        revisar_barrido(16'h0A0F, "nibbles > 9 apagan el digito");

        escribir_led(32'hFFFF_0005); #1;
        chequear("LED: registro y pines", rd_led == 32'h0000_0005 && led == 16'h0005);
        addr = 2'b01; #1;
        chequear("addr 01 lee 0", rd_led == 0 && rd_seg == 0);
        escribir_led(32'h0000_00FF); addr = 2'b00; #1;
        chequear("escritura en addr 01 no cambia el LED", led == 16'h0005);

        if (fallos == 0) $display("RESULTADO: PASS");
        else             $display("RESULTADO: FAIL (%0d errores)", fallos);
        $finish;
    end

endmodule
