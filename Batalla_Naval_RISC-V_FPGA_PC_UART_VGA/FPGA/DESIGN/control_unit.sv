// =====================================================================
// control_unit.sv - Unidad de control del procesador uniciclo
//
// Junta el decodificador principal, el decodificador de la ALU y la
// logica de saltos condicionales.
//
// Saltos condicionales (funct3), con las banderas de la resta rs1 - rs2:
//   000 beq  salta si zero
//   001 bne  salta si no zero
//   100 blt  salta si neg xor ovf
//   101 bge  salta si no (neg xor ovf)
// bltu y bgeu (110, 111) no forman parte del subconjunto pedido y
// nunca saltan.
//
// pc_src_o = 1 elige PC + inmediato (salto tomado o jal).
// jalr_o   = 1 elige (rs1 + inmediato) con el bit 0 en cero.
// =====================================================================

module control_unit (
    input  logic [31:0] instr_i,
    input  logic        zero_i,
    input  logic        neg_i,
    input  logic        ovf_i,
    output logic        reg_write_o,
    output logic [1:0]  imm_src_o,
    output logic        alu_src_o,
    output logic        mem_write_o,
    output logic [1:0]  result_src_o,
    output logic [3:0]  alu_ctrl_o,
    output logic        pc_src_o,
    output logic        jalr_o
);

    logic       branch, jal;
    logic [1:0] alu_op;
    logic [2:0] funct3;
    assign funct3 = instr_i[14:12];

    main_decoder u_main_dec (
        .opcode_i     (instr_i[6:0]),
        .reg_write_o  (reg_write_o),
        .imm_src_o    (imm_src_o),
        .alu_src_o    (alu_src_o),
        .mem_write_o  (mem_write_o),
        .result_src_o (result_src_o),
        .branch_o     (branch),
        .jal_o        (jal),
        .jalr_o       (jalr_o),
        .alu_op_o     (alu_op)
    );

    alu_decoder u_alu_dec (
        .alu_op_i   (alu_op),
        .funct3_i   (funct3),
        .funct7b5_i (instr_i[30]),
        .op5_i      (instr_i[5]),
        .alu_ctrl_o (alu_ctrl_o)
    );

    logic menor, cond;
    assign menor = neg_i ^ ovf_i;

    always_comb begin
        case (funct3)
            3'b000:  cond = zero_i;
            3'b001:  cond = !zero_i;
            3'b100:  cond = menor;
            3'b101:  cond = !menor;
            default: cond = 1'b0;
        endcase
    end

    assign pc_src_o = (branch && cond) || jal;

endmodule
