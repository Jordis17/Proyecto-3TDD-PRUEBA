// =====================================================================
// ram.sv - Memoria de datos (0x0000_2000 - 0x0000_2FFF)
//
// 1024 palabras de 32 bits. Escritura sincrona en el flanco de subida
// y lectura combinacional, porque el procesador uniciclo necesita el
// dato de lw en el mismo ciclo. Vivado la implementa como RAM
// distribuida (LUTs).
//
// Arranca en cero al programar la FPGA; el programa igual inicializa
// todo lo que usa.
// =====================================================================

module ram (
    input  logic        clk_i,
    input  logic        we_i,
    input  logic [9:0]  addr_i,     // palabra: DataAddress[11:2]
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o
);

    logic [31:0] mem [0:1023];

    initial begin
        for (int i = 0; i < 1024; i++) mem[i] = 32'd0;
    end

    always_ff @(posedge clk_i) begin
        if (we_i) mem[addr_i] <= wdata_i;
    end

    assign rdata_o = mem[addr_i];

endmodule
