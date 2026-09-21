// =====================================================================
// video_mem.sv - Memoria de video de doble puerto (512 x 32)
//
// Puerto A (CPU), reloj del sistema:
//   escritura sincrona con we_a_i; lectura combinacional, porque el
//   procesador uniciclo necesita el dato de lw en el mismo ciclo.
// Puerto B (video), reloj de pixel:
//   solo lectura, registrada en el flanco de clk_b_i.
//
// Cada puerto trabaja unicamente con su propio reloj y no comparten
// senales de control, asi que no hace falta sincronizar nada entre
// dominios: el cruce lo resuelve la memoria. Si el CPU escribe un tile
// en el mismo instante en que el video lo lee, ese tile puede verse con
// el valor anterior durante un solo cuadro (planteamiento, 9.7).
//
// Con esta descripcion Vivado infiere RAM distribuida de doble puerto.
// Arranca en cero: pantalla negra sin simbolos.
// =====================================================================

module video_mem (
    // puerto A: CPU
    input  logic        clk_a_i,
    input  logic        we_a_i,
    input  logic [8:0]  addr_a_i,
    input  logic [31:0] wdata_a_i,
    output logic [31:0] rdata_a_o,
    // puerto B: video
    input  logic        clk_b_i,
    input  logic [8:0]  addr_b_i,
    output logic [31:0] rdata_b_o
);

    logic [31:0] mem [0:511];

    initial begin
        for (int i = 0; i < 512; i++) mem[i] = 32'd0;
    end

    always_ff @(posedge clk_a_i) begin
        if (we_a_i) mem[addr_a_i] <= wdata_a_i;
    end

    assign rdata_a_o = mem[addr_a_i];

    always_ff @(posedge clk_b_i) begin
        rdata_b_o <= mem[addr_b_i];
    end

endmodule
