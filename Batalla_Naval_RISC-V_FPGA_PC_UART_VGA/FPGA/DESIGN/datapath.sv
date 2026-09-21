// =====================================================================
// datapath.sv - Camino de datos del procesador uniciclo
//
// Registro PC, sumadores PC+4 y PC+inmediato, banco de registros,
// extensor de inmediatos, ALU y multiplexores [Harris y Harris, cap. 7].
//
// Siguiente PC:
//   jalr      -> (rs1 + inm) con el bit 0 en cero
//   pc_src=1  -> PC + inm   (salto tomado o jal)
//   si no     -> PC + 4
//
// El PC tiene reinicio sincrono a 0x0000_0000 (vector de reset).
// =====================================================================

module datapath (
    input  logic        clk_i,
    input  logic        rst_i,
    // senales de control
    input  logic        reg_write_i,
    input  logic [1:0]  imm_src_i,
    input  logic        alu_src_i,
    input  logic [1:0]  result_src_i,
    input  logic [3:0]  alu_ctrl_i,
    input  logic        pc_src_i,
    input  logic        jalr_i,
    output logic        zero_o,
    output logic        neg_o,
    output logic        ovf_o,
    // memoria de programa
    output logic [31:0] pc_o,
    input  logic [31:0] instr_i,
    // bus de datos
    output logic [31:0] alu_result_o,
    output logic [31:0] write_data_o,
    input  logic [31:0] read_data_i
);

    logic [31:0] pc_q, pc_next, pc_plus4, pc_target;
    logic [31:0] imm, rs1_val, rs2_val, src_b, result;

    // ---- PC ----
    always_ff @(posedge clk_i) begin
        if (rst_i) pc_q <= 32'd0;
        else       pc_q <= pc_next;
    end

    assign pc_plus4  = pc_q + 32'd4;
    assign pc_target = pc_q + imm;

    always_comb begin
        if (jalr_i)        pc_next = {alu_result_o[31:1], 1'b0};
        else if (pc_src_i) pc_next = pc_target;
        else               pc_next = pc_plus4;
    end

    assign pc_o = pc_q;

    // ---- banco de registros ----
    regfile u_regfile (
        .clk_i (clk_i),
        .we_i  (reg_write_i),
        .rs1_i (instr_i[19:15]),
        .rs2_i (instr_i[24:20]),
        .rd_i  (instr_i[11:7]),
        .wd_i  (result),
        .rd1_o (rs1_val),
        .rd2_o (rs2_val)
    );

    imm_gen u_imm_gen (
        .instr_i   (instr_i[31:7]),
        .imm_src_i (imm_src_i),
        .imm_o     (imm)
    );

    // ---- ALU ----
    assign src_b = alu_src_i ? imm : rs2_val;

    alu u_alu (
        .a_i        (rs1_val),
        .b_i        (src_b),
        .alu_ctrl_i (alu_ctrl_i),
        .result_o   (alu_result_o),
        .zero_o     (zero_o),
        .neg_o      (neg_o),
        .ovf_o      (ovf_o)
    );

    assign write_data_o = rs2_val;

    // ---- resultado que se escribe en rd ----
    always_comb begin
        case (result_src_i)
            2'b01:   result = read_data_i;
            2'b10:   result = pc_plus4;
            default: result = alu_result_o;
        endcase
    end

endmodule
