// =====================================================================
// rom.sv - Memoria de programa (0x0000_0000 - 0x0000_1FFF)
//
// 2048 palabras de 32 bits con lectura combinacional: en un procesador
// uniciclo la instruccion debe estar lista en el mismo ciclo en que se
// presenta la direccion [Harris y Harris, cap. 7]. Vivado la implementa
// con LUTs (ROM distribuida).
//
// El contenido se carga al sintetizar desde INIT_FILE, un archivo de
// texto con una palabra hexadecimal por linea, generado a partir del
// programa en ensamblador.
//
// Solo se usan los bits [12:2] de la direccion: las instrucciones estan
// alineadas a 4 bytes y la ROM ocupa 8 KB.
// =====================================================================

module rom #(
    parameter string INIT_FILE = "programa.mem"
) (
    input  logic [31:0] addr_i,
    output logic [31:0] data_o
);

    logic [31:0] mem [0:2047];

    initial begin
        // Las posiciones que el archivo no cubra quedan como nop.
        for (int i = 0; i < 2048; i++) mem[i] = 32'h0000_0013;
        $readmemh(INIT_FILE, mem);
    end

    assign data_o = mem[addr_i[12:2]];

endmodule
