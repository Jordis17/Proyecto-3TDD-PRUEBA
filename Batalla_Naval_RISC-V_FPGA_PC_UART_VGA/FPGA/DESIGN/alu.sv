// =====================================================================
// alu.sv - Unidad aritmetico-logica del procesador RV32I
//
// Operaciones (alu_ctrl_i):
//   0000 add   0001 sub   0010 and   0011 or    0100 xor
//   0101 slt   0110 sltu  0111 sll   1000 srl   1001 sra
//
// Las banderas zero, neg y ovf salen siempre de la resta a - b, sin
// importar la operacion elegida. La logica de saltos las usa para
// decidir beq/bne/blt/bge [Harris y Harris, cap. 5 y 7]:
//   a <  b con signo  <=>  neg xor ovf
// Se usa neg xor ovf y no solo el bit de signo porque la resta puede
// desbordarse (por ejemplo 0x8000_0000 - 1) y en ese caso el signo del
// resultado queda invertido.
// =====================================================================

module alu (
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic [3:0]  alu_ctrl_i,
    output logic [31:0] result_o,
    output logic        zero_o,
    output logic        neg_o,
    output logic        ovf_o
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

    // Resta con un bit extra: el bit 32 es el prestamo, que vale 1
    // exactamente cuando a < b sin signo.
    logic [32:0] resta;
    assign resta = {1'b0, a_i} - {1'b0, b_i};

    assign zero_o = (resta[31:0] == 32'd0);
    assign neg_o  = resta[31];
    // Hay desbordamiento si a y b tienen signos distintos y el signo
    // del resultado no coincide con el de a.
    assign ovf_o  = (a_i[31] != b_i[31]) && (resta[31] != a_i[31]);

    logic       menor_con_signo, menor_sin_signo;
    logic [4:0] shamt;
    assign menor_con_signo = neg_o ^ ovf_o;
    assign menor_sin_signo = resta[32];
    // RV32I usa solo los 5 bits bajos como cantidad de desplazamiento.
    assign shamt = b_i[4:0];

    always_comb begin
        case (alu_ctrl_i)
            ALU_ADD:  result_o = a_i + b_i;
            ALU_SUB:  result_o = resta[31:0];
            ALU_AND:  result_o = a_i & b_i;
            ALU_OR:   result_o = a_i | b_i;
            ALU_XOR:  result_o = a_i ^ b_i;
            ALU_SLT:  result_o = {31'd0, menor_con_signo};
            ALU_SLTU: result_o = {31'd0, menor_sin_signo};
            ALU_SLL:  result_o = a_i << shamt;
            ALU_SRL:  result_o = a_i >> shamt;
            ALU_SRA:  result_o = $signed(a_i) >>> shamt;
            default:  result_o = 32'd0;
        endcase
    end

endmodule
