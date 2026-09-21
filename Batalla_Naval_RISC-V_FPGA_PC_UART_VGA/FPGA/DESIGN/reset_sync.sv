// =====================================================================
// reset_sync.sv - Reinicio sincronizado a un dominio de reloj
//
// locked_i viene del PLL y es asincrono respecto a clk_i. Se pasa por
// dos flip-flops para evitar metaestabilidad; rst_o = 1 mientras locked
// no haya sido visto estable en este dominio. Los flip-flops arrancan
// en 1 para que el sistema empiece en reinicio al programar la FPGA.
// =====================================================================

module reset_sync (
    input  logic clk_i,
    input  logic locked_i,
    output logic rst_o
);

    logic sinc1_q = 1'b1;
    logic sinc2_q = 1'b1;

    always_ff @(posedge clk_i) begin
        sinc1_q <= !locked_i;
        sinc2_q <= sinc1_q;
    end

    assign rst_o = sinc2_q;

endmodule
