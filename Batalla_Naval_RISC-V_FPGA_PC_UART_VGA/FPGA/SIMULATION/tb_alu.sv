// =====================================================================
// tb_alu.sv - Testbench autoverificable de la ALU
//
// Compara cada operacion contra un modelo de referencia escrito con
// operadores de SystemVerilog: primero casos de borde dirigidos y luego
// 2000 pares aleatorios por operacion. Tambien revisa las banderas
// zero, neg y ovf de la resta.
// =====================================================================
`timescale 1ns/1ps

module tb_alu;

    logic [31:0] a, b, res;
    logic [3:0]  op;
    logic        zero, neg, ovf;

    alu dut (
        .a_i(a), .b_i(b), .alu_ctrl_i(op),
        .result_o(res), .zero_o(zero), .neg_o(neg), .ovf_o(ovf)
    );

    int fallos = 0, pruebas = 0;

    function automatic logic [31:0] modelo(input logic [31:0] x, y, input logic [3:0] o);
        case (o)
            4'd0: return x + y;
            4'd1: return x - y;
            4'd2: return x & y;
            4'd3: return x | y;
            4'd4: return x ^ y;
            4'd5: return ($signed(x) < $signed(y)) ? 32'd1 : 32'd0;
            4'd6: return (x < y) ? 32'd1 : 32'd0;
            4'd7: return x << y[4:0];
            4'd8: return x >> y[4:0];
            4'd9: return $signed(x) >>> y[4:0];
            default: return 32'd0;
        endcase
    endfunction

    task automatic probar(input logic [31:0] x, y, input logic [3:0] o);
        logic [31:0] dif;
        logic        ovf_esp;
        a = x; b = y; op = o;
        #1;
        dif     = x - y;
        ovf_esp = (x[31] != y[31]) && (dif[31] != x[31]);
        pruebas++;
        if (res !== modelo(x, y, o) || zero !== (dif == 0) ||
            neg !== dif[31] || ovf !== ovf_esp) begin
            fallos++;
            if (fallos <= 10)
                $display("FAIL op=%0d a=%h b=%h res=%h esp=%h z=%b n=%b v=%b",
                         o, x, y, res, modelo(x, y, o), zero, neg, ovf);
        end
    endtask

    logic [31:0] bordes [0:7];

    initial begin
        bordes[0] = 32'h0;          bordes[1] = 32'h1;
        bordes[2] = 32'hFFFF_FFFF;  bordes[3] = 32'h7FFF_FFFF;
        bordes[4] = 32'h8000_0000;  bordes[5] = 32'h8000_0001;
        bordes[6] = 32'd31;         bordes[7] = 32'd32;
        for (int o = 0; o < 10; o++) begin
            foreach (bordes[i]) foreach (bordes[j]) probar(bordes[i], bordes[j], o[3:0]);
            repeat (2000) probar($urandom, $urandom, o[3:0]);
        end
        if (fallos == 0) $display("RESULTADO: PASS (%0d pruebas)", pruebas);
        else             $display("RESULTADO: FAIL (%0d de %0d pruebas)", fallos, pruebas);
        $finish;
    end

endmodule
