// =====================================================================
// main_decoder.sv - Decodificador principal de la unidad de control
//
// A partir del opcode genera las senales de control del datapath
// uniciclo [Harris y Harris, cap. 7]. Ver tabla en el planteamiento,
// seccion 6.1.
//
//   result_src_o  00 resultado de la ALU
//                 01 dato leido del bus de datos (lw)
//                 10 PC + 4 (jal, jalr)
//   alu_op_o      00 suma (lw, sw, jalr)
//                 01 resta (saltos condicionales)
//                 10 segun funct3/funct7 (tipo R y tipo I aritmeticas)
//
// Un opcode que no pertenece al subconjunto implementado deja todas las
// senales en 0: no escribe registros ni memoria y el PC avanza a PC+4.
// =====================================================================

module main_decoder (
    input  logic [6:0] opcode_i,
    output logic       reg_write_o,
    output logic [1:0] imm_src_o,
    output logic       alu_src_o,     // 0: rs2, 1: inmediato
    output logic       mem_write_o,
    output logic [1:0] result_src_o,
    output logic       branch_o,
    output logic       jal_o,
    output logic       jalr_o,
    output logic [1:0] alu_op_o
);

    localparam logic [6:0] OP_R      = 7'b0110011;
    localparam logic [6:0] OP_I_ARIT = 7'b0010011;
    localparam logic [6:0] OP_LW     = 7'b0000011;
    localparam logic [6:0] OP_SW     = 7'b0100011;
    localparam logic [6:0] OP_BRANCH = 7'b1100011;
    localparam logic [6:0] OP_JAL    = 7'b1101111;
    localparam logic [6:0] OP_JALR   = 7'b1100111;

    always_comb begin
        // valores por defecto: instruccion sin efecto
        reg_write_o  = 1'b0;
        imm_src_o    = 2'b00;
        alu_src_o    = 1'b0;
        mem_write_o  = 1'b0;
        result_src_o = 2'b00;
        branch_o     = 1'b0;
        jal_o        = 1'b0;
        jalr_o       = 1'b0;
        alu_op_o     = 2'b00;

        case (opcode_i)
            OP_R: begin
                reg_write_o = 1'b1;
                alu_op_o    = 2'b10;
            end
            OP_I_ARIT: begin
                reg_write_o = 1'b1;
                alu_src_o   = 1'b1;
                alu_op_o    = 2'b10;
            end
            OP_LW: begin
                reg_write_o  = 1'b1;
                alu_src_o    = 1'b1;
                result_src_o = 2'b01;
            end
            OP_SW: begin
                imm_src_o   = 2'b01;
                alu_src_o   = 1'b1;
                mem_write_o = 1'b1;
            end
            OP_BRANCH: begin
                imm_src_o = 2'b10;
                branch_o  = 1'b1;
                alu_op_o  = 2'b01;
            end
            OP_JAL: begin
                reg_write_o  = 1'b1;
                imm_src_o    = 2'b11;
                result_src_o = 2'b10;
                jal_o        = 1'b1;
            end
            OP_JALR: begin
                reg_write_o  = 1'b1;
                alu_src_o    = 1'b1;
                result_src_o = 2'b10;
                jalr_o       = 1'b1;
            end
            default: ;
        endcase
    end

endmodule
