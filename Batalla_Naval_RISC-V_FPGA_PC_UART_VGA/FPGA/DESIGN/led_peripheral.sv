// =====================================================================
// led_peripheral.sv - Periferico de LED de estado
//
// Direccion 0x0001_0138. Un registro de lectura/escritura (addr_i = 00)
// cuyos bits [15:0] se copian a los LED LD0-LD15. Valor tras reinicio:
// 0. El significado de cada LED lo fija el programa (planteamiento,
// seccion 7.6): LD0 colocacion, LD1 batalla, LD2 resultado final.
// =====================================================================

module led_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    output logic [15:0] led_o
);

    logic [15:0] led_q;

    always_ff @(posedge clk_i) begin
        if (rst_i)                                     led_q <= 16'd0;
        else if (write_enable_i && addr_i == 2'b00)    led_q <= wdata_i[15:0];
    end

    assign rdata_o = (addr_i == 2'b00) ? {16'd0, led_q} : 32'd0;
    assign led_o   = led_q;

endmodule
