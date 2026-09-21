// =====================================================================
// regfile.sv - Banco de 32 registros de 32 bits
//
// Dos lecturas combinacionales (rs1, rs2) y una escritura en el flanco
// de subida. x0 siempre se lee como 0 y nunca se escribe.
//
// No tiene reinicio: el programa carga cada registro antes de usarlo
// (gp, tp y sp al inicio). Sin reinicio la herramienta puede
// implementarlo como RAM distribuida en vez de 1024 flip-flops.
// =====================================================================

module regfile (
    input  logic        clk_i,
    input  logic        we_i,
    input  logic [4:0]  rs1_i,
    input  logic [4:0]  rs2_i,
    input  logic [4:0]  rd_i,
    input  logic [31:0] wd_i,
    output logic [31:0] rd1_o,
    output logic [31:0] rd2_o
);

    logic [31:0] regs [31:1];

    always_ff @(posedge clk_i) begin
        if (we_i && (rd_i != 5'd0))
            regs[rd_i] <= wd_i;
    end

    assign rd1_o = (rs1_i == 5'd0) ? 32'd0 : regs[rs1_i];
    assign rd2_o = (rs2_i == 5'd0) ? 32'd0 : regs[rs2_i];

endmodule
