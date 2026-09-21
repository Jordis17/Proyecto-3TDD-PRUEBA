// =====================================================================
// imm_gen.sv - Extensor de inmediatos
//
// Arma el inmediato de 32 bits con extension de signo segun el formato
// de la instruccion [Harris y Harris, cap. 6]:
//
//   imm_src_i  formato  usado por
//   00         I        addi, andi, ..., slli, lw, jalr
//   01         S        sw
//   10         B        beq, bne, blt, bge
//   11         J        jal
//
// En B y J el bit 0 siempre es 0 porque los destinos de salto son
// multiplos de 2. En los desplazamientos inmediatos (slli, srli, srai)
// el inmediato I trae la cantidad en [4:0] y el bit 10 distingue srai
// de srli; la ALU solo mira [4:0].
// =====================================================================

module imm_gen (
    input  logic [31:7] instr_i,
    input  logic [1:0]  imm_src_i,
    output logic [31:0] imm_o
);

    always_comb begin
        case (imm_src_i)
            2'b00:   imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
            2'b01:   imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
            2'b10:   imm_o = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25],
                              instr_i[11:8], 1'b0};
            2'b11:   imm_o = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20],
                              instr_i[30:21], 1'b0};
            default: imm_o = 32'd0;
        endcase
    end

endmodule
