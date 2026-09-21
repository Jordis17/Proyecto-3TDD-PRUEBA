// =====================================================================
// riscv_core.sv - Microprocesador RV32I uniciclo
//
// Interfaz definida por el enunciado: bus de programa (ProgAddress_o,
// ProgIn_i) y bus de datos (DataAddress_o, DataOut_o, DataIn_i, we_o)
// independientes.
//
// Al ser uniciclo, la instruccion y el dato leido deben estar listos en
// el mismo ciclo: ProgIn_i y DataIn_i se esperan combinacionales
// respecto a sus direcciones. Las escrituras (we_o) se efectuan en el
// flanco de subida de clk_i.
//
// rst_i es sincrono y activo en alto; lleva el PC a 0x0000_0000.
// =====================================================================

module riscv_core (
    input  logic        clk_i,
    input  logic        rst_i,
    output logic [31:0] ProgAddress_o,
    input  logic [31:0] ProgIn_i,
    output logic [31:0] DataAddress_o,
    output logic [31:0] DataOut_o,
    input  logic [31:0] DataIn_i,
    output logic        we_o
);

    logic       reg_write, alu_src, mem_write, pc_src, jalr;
    logic [1:0] imm_src, result_src;
    logic [3:0] alu_ctrl;
    logic       zero, neg, ovf;

    control_unit u_control (
        .instr_i      (ProgIn_i),
        .zero_i       (zero),
        .neg_i        (neg),
        .ovf_i        (ovf),
        .reg_write_o  (reg_write),
        .imm_src_o    (imm_src),
        .alu_src_o    (alu_src),
        .mem_write_o  (mem_write),
        .result_src_o (result_src),
        .alu_ctrl_o   (alu_ctrl),
        .pc_src_o     (pc_src),
        .jalr_o       (jalr)
    );

    datapath u_datapath (
        .clk_i        (clk_i),
        .rst_i        (rst_i),
        .reg_write_i  (reg_write),
        .imm_src_i    (imm_src),
        .alu_src_i    (alu_src),
        .result_src_i (result_src),
        .alu_ctrl_i   (alu_ctrl),
        .pc_src_i     (pc_src),
        .jalr_i       (jalr),
        .zero_o       (zero),
        .neg_o        (neg),
        .ovf_o        (ovf),
        .pc_o         (ProgAddress_o),
        .instr_i      (ProgIn_i),
        .alu_result_o (DataAddress_o),
        .write_data_o (DataOut_o),
        .read_data_i  (DataIn_i)
    );

    // Durante el reinicio no se escribe nada en memoria ni en perifericos.
    assign we_o = mem_write && !rst_i;

endmodule
