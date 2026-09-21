// =====================================================================
// vga_sync.sv - Temporizacion VGA 640 x 480 a 60 Hz
//
// Con reloj de pixel de 25 MHz [Chu, cap. de VGA]:
//
//                visible  portico frontal  sincronismo  portico trasero  total
//   horizontal     640          16              96            48          800
//   vertical       480          10               2            33          525
//
// Ambos sincronismos son activos en bajo. x_o e y_o son la posicion del
// pixel actual (0-799, 0-524); video_on_o vale 1 dentro de la zona
// visible. Todas las salidas son combinacionales a partir de los
// contadores registrados.
// =====================================================================

module vga_sync (
    input  logic       clk_i,      // reloj de pixel
    input  logic       rst_i,
    output logic [9:0] x_o,
    output logic [9:0] y_o,
    output logic       hsync_o,
    output logic       vsync_o,
    output logic       video_on_o
);

    localparam int H_VISIBLE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48;
    localparam int V_VISIBLE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33;
    localparam int H_TOTAL   = H_VISIBLE + H_FP + H_SYNC + H_BP;   // 800
    localparam int V_TOTAL   = V_VISIBLE + V_FP + V_SYNC + V_BP;   // 525

    logic [9:0] x_q, y_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            x_q <= '0;
            y_q <= '0;
        end else if (x_q == 10'(H_TOTAL - 1)) begin
            x_q <= '0;
            y_q <= (y_q == 10'(V_TOTAL - 1)) ? '0 : y_q + 1'b1;
        end else begin
            x_q <= x_q + 1'b1;
        end
    end

    assign x_o        = x_q;
    assign y_o        = y_q;
    assign hsync_o    = !((x_q >= 10'(H_VISIBLE + H_FP)) &&
                          (x_q <  10'(H_VISIBLE + H_FP + H_SYNC)));
    assign vsync_o    = !((y_q >= 10'(V_VISIBLE + V_FP)) &&
                          (y_q <  10'(V_VISIBLE + V_FP + V_SYNC)));
    assign video_on_o = (x_q < 10'(H_VISIBLE)) && (y_q < 10'(V_VISIBLE));

endmodule
