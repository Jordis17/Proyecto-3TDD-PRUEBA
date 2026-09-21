// =====================================================================
// seg_peripheral.sv - Periferico de displays de 7 segmentos
//
// Direccion 0x0001_0130. Un registro de lectura/escritura (addr_i = 00):
//
//   [3:0]   digito 0  unidades de victorias del J2   -> AN0
//   [7:4]   digito 1  decenas de victorias del J2    -> AN1
//   [11:8]  digito 2  unidades de victorias del J1   -> AN4
//   [15:12] digito 3  decenas de victorias del J1    -> AN5
//
// Cada digito va en BCD; un valor mayor a 9 apaga ese digito. Los
// digitos del J1 y del J2 quedan en bloques distintos de la tarjeta
// (AN5-AN4 y AN1-AN0) para que no se lean como un solo numero de cuatro
// cifras. AN2, AN3, AN6 y AN7 quedan apagados.
//
// El barrido y el decodificador son los del display_controller del
// Proyecto 2: un digito por tick de 1 ms, 250 Hz por vuelta. Dentro del
// modulo 1 = encendido; la polaridad de la tarjeta se aplica al final.
// =====================================================================

module seg_peripheral #(
    parameter logic SEG_ACTIVE_LEVEL = 1'b0,
    parameter logic AN_ACTIVE_LEVEL  = 1'b0
) (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic        tick_i,       // pulso de 1 ms
    output logic [6:0]  seg_o,        // {g,f,e,d,c,b,a}
    output logic [7:0]  an_o
);

    logic [15:0] datos_q;
    logic [1:0]  dig_q;
    logic [3:0]  nibble;
    logic [6:0]  seg;
    logic [7:0]  an;

    always_ff @(posedge clk_i) begin
        if (rst_i)                                  datos_q <= 16'd0;
        else if (write_enable_i && addr_i == 2'b00) datos_q <= wdata_i[15:0];
    end

    assign rdata_o = (addr_i == 2'b00) ? {16'd0, datos_q} : 32'd0;

    // digito que se muestra en este milisegundo
    always_ff @(posedge clk_i) begin
        if (rst_i)       dig_q <= 2'd0;
        else if (tick_i) dig_q <= dig_q + 2'd1;
    end

    always_comb begin
        case (dig_q)
            2'd0:    nibble = datos_q[3:0];
            2'd1:    nibble = datos_q[7:4];
            2'd2:    nibble = datos_q[11:8];
            default: nibble = datos_q[15:12];
        endcase
    end

    // {g,f,e,d,c,b,a}, 1 = segmento encendido
    always_comb begin
        case (nibble)
            4'd0:    seg = 7'b0111111;
            4'd1:    seg = 7'b0000110;
            4'd2:    seg = 7'b1011011;
            4'd3:    seg = 7'b1001111;
            4'd4:    seg = 7'b1100110;
            4'd5:    seg = 7'b1101101;
            4'd6:    seg = 7'b1111101;
            4'd7:    seg = 7'b0000111;
            4'd8:    seg = 7'b1111111;
            4'd9:    seg = 7'b1101111;
            default: seg = 7'b0000000;   // no es BCD: digito apagado
        endcase
    end

    always_comb begin
        case (dig_q)
            2'd0:    an = 8'b0000_0001;   // AN0
            2'd1:    an = 8'b0000_0010;   // AN1
            2'd2:    an = 8'b0001_0000;   // AN4
            default: an = 8'b0010_0000;   // AN5
        endcase
    end

    assign seg_o = SEG_ACTIVE_LEVEL ? seg : ~seg;
    assign an_o  = AN_ACTIVE_LEVEL  ? an  : ~an;

endmodule
