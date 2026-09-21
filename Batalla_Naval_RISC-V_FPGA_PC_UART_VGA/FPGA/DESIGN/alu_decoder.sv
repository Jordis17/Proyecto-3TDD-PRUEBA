// =====================================================================
// alu_decoder.sv - Decodificador de la ALU
//
// Elige la operacion de la ALU con alu_op (del decodificador principal),
// funct3 y el bit 30 de la instruccion (funct7[5]) [Harris y Harris,
// cap. 7].
//
// El bit 30 tiene dos usos:
//   - en tipo R con funct3 = 000 distingue sub (1) de add (0);
//   - con funct3 = 101 distingue sra/srai (1) de srl/srli (0).
// En addi ese bit es parte del inmediato, por eso sub solo se elige si
// ademas la instruccion es tipo R (opcode[5] = 1).
// =====================================================================

module alu_decoder (
    input  logic [1:0] alu_op_i,
    input  logic [2:0] funct3_i,
    input  logic       funct7b5_i,   // instr[30]
    input  logic       op5_i,        // instr[5]: 1 tipo R, 0 tipo I
    output logic [3:0] alu_ctrl_o
);

    localparam logic [3:0] ALU_ADD  = 4'b0000;
    localparam logic [3:0] ALU_SUB  = 4'b0001;
    localparam logic [3:0] ALU_AND  = 4'b0010;
    localparam logic [3:0] ALU_OR   = 4'b0011;
    localparam logic [3:0] ALU_XOR  = 4'b0100;
    localparam logic [3:0] ALU_SLT  = 4'b0101;
    localparam logic [3:0] ALU_SLTU = 4'b0110;
    localparam logic [3:0] ALU_SLL  = 4'b0111;
    localparam logic [3:0] ALU_SRL  = 4'b1000;
    localparam logic [3:0] ALU_SRA  = 4'b1001;

    always_comb begin
        case (alu_op_i)
            2'b00:   alu_ctrl_o = ALU_ADD;
            2'b01:   alu_ctrl_o = ALU_SUB;
            default: begin
                case (funct3_i)
                    3'b000:  alu_ctrl_o = (op5_i && funct7b5_i) ? ALU_SUB : ALU_ADD;
                    3'b001:  alu_ctrl_o = ALU_SLL;
                    3'b010:  alu_ctrl_o = ALU_SLT;
                    3'b011:  alu_ctrl_o = ALU_SLTU;
                    3'b100:  alu_ctrl_o = ALU_XOR;
                    3'b101:  alu_ctrl_o = funct7b5_i ? ALU_SRA : ALU_SRL;
                    3'b110:  alu_ctrl_o = ALU_OR;
                    default: alu_ctrl_o = ALU_AND;   // 3'b111
                endcase
            end
        endcase
    end

endmodule
