// =====================================================================
// glyph_rom.sv - ROM de simbolos del HUD (8 x 8 pixeles)
//
// Entrega la fila row_i (0 = arriba) del simbolo code_i. El bit 7 es la
// columna de la izquierda. El periferico VGA amplia cada simbolo 4
// veces para llenar un tile de 32 x 32.
//
//   codigo   simbolo            codigo   simbolo
//   0        (ninguno)          17       J
//   1-10     digitos 0-9        18       L
//   11       A                  19       N
//   12       B                  20       O
//   13       C                  21       R
//   14       F                  22       T
//   15       G                  23       U
//   16       I                  24       :
//   25-31    reservados (sin dibujo)
//
// Con estas letras se escriben COLOCAR, BATALLA, FIN, TURNO, GANA, J1,
// J2 y las victorias (planteamiento, seccion 9.6).
// =====================================================================

module glyph_rom (
    input  logic [4:0] code_i,
    input  logic [2:0] row_i,
    output logic [7:0] bits_o
);

    logic [63:0] g;   // 8 filas de 8 bits, fila 0 en [63:56]

    always_comb begin
        case (code_i)
            5'd1:  g = 64'h3C666E7666663C00;   // 0
            5'd2:  g = 64'h1838181818187E00;   // 1
            5'd3:  g = 64'h3C66060C30607E00;   // 2
            5'd4:  g = 64'h3C66061C06663C00;   // 3
            5'd5:  g = 64'h0C1C3C6C7E0C0C00;   // 4
            5'd6:  g = 64'h7E607C0606663C00;   // 5
            5'd7:  g = 64'h3C607C6666663C00;   // 6
            5'd8:  g = 64'h7E060C1830303000;   // 7
            5'd9:  g = 64'h3C66663C66663C00;   // 8
            5'd10: g = 64'h3C66663E060C3800;   // 9
            5'd11: g = 64'h183C66667E666600;   // A
            5'd12: g = 64'h7C66667C66667C00;   // B
            5'd13: g = 64'h3C66606060663C00;   // C
            5'd14: g = 64'h7E60607C60606000;   // F
            5'd15: g = 64'h3C66606E66663C00;   // G
            5'd16: g = 64'h3C18181818183C00;   // I
            5'd17: g = 64'h1E0C0C0C6C6C3800;   // J
            5'd18: g = 64'h6060606060607E00;   // L
            5'd19: g = 64'h66767E7E6E666600;   // N
            5'd20: g = 64'h3C66666666663C00;   // O
            5'd21: g = 64'h7C66667C6C666600;   // R
            5'd22: g = 64'h7E18181818181800;   // T
            5'd23: g = 64'h6666666666663C00;   // U
            5'd24: g = 64'h0018180018180000;   // :
            default: g = 64'h0;                // 0 y reservados
        endcase
    end

    assign bits_o = g[8*(7 - row_i) +: 8];

endmodule
