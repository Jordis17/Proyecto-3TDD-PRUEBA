// =====================================================================
// tb_riscv_core.sv - Testbench autoverificable del procesador RV32I
//
// Carga en una ROM de prueba el programa programas/tb_cpu.s (codigo de
// maquina abajo, con la instruccion de cada palabra como comentario) y
// lo ejecuta hasta que el PC queda fijo en el lazo final. Cada prueba
// del programa guarda un resultado en la RAM desde 0x2000; al final el
// testbench compara cada palabra con el valor esperado y reporta
// PASS/FAIL por prueba y un resumen.
//
// Cubre las 27 instrucciones del subconjunto y casos de borde: x0,
// desplazamientos de 0 y 31, cantidad de desplazamiento mayor a 31,
// slt/sltu con negativos, comparaciones que desbordan la resta, saltos
// hacia atras y jalr con destino impar.
//
// La ROM y la RAM de este testbench son modelos de comportamiento con
// lectura combinacional, igual que las memorias reales del sistema.
// =====================================================================
`timescale 1ns/1ps

module tb_riscv_core;

    localparam int N_PRUEBAS = 46;
    localparam int MAX_CICLOS = 5000;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [31:0] prog_addr, prog_in, data_addr, data_out, data_in;
    logic        we;

    always #10 clk = ~clk;   // 50 MHz

    riscv_core dut (
        .clk_i         (clk),
        .rst_i         (rst),
        .ProgAddress_o (prog_addr),
        .ProgIn_i      (prog_in),
        .DataAddress_o (data_addr),
        .DataOut_o     (data_out),
        .DataIn_i      (data_in),
        .we_o          (we)
    );

    // ---- ROM de prueba: 0x0000-0x1FFF ----
    logic [31:0] rom [0:2047];
    assign prog_in = rom[prog_addr[12:2]];

    // ---- RAM de prueba: 0x2000-0x2FFF ----
    logic [31:0] ram [0:1023];
    logic        en_ram;
    assign en_ram  = (data_addr[31:12] == 20'h00002);
    assign data_in = en_ram ? ram[data_addr[11:2]] : 32'd0;

    int errores_bus = 0;
    always @(posedge clk) begin
        if (we) begin
            if (en_ram) ram[data_addr[11:2]] <= data_out;
            else begin
                $display("FAIL escritura fuera de la RAM: dir=%h dato=%h", data_addr, data_out);
                errores_bus++;
            end
        end
    end

    logic [31:0] esperado [0:N_PRUEBAS-1];
    string       nombre   [0:N_PRUEBAS-1];

    initial begin
        for (int i = 0; i < 2048; i++) rom[i] = 32'h0000_0013;   // nop
        for (int i = 0; i < 1024; i++) ram[i] = 32'hDEAD_BEEF;
        rom[  0] = 32'h00100413;  // addi x8,x0,1
        rom[  1] = 32'h00d41413;  // slli x8,x8,0xd
        rom[  2] = 32'h00500293;  // addi x5,x0,5
        rom[  3] = 32'h00542023;  // sw x5,0(x8)
        rom[  4] = 32'h00440413;  // addi x8,x8,4
        rom[  5] = 32'hffd00293;  // addi x5,x0,-3
        rom[  6] = 32'h00542023;  // sw x5,0(x8)
        rom[  7] = 32'h00440413;  // addi x8,x8,4
        rom[  8] = 32'h00500513;  // addi x10,x0,5
        rom[  9] = 32'hffd00593;  // addi x11,x0,-3
        rom[ 10] = 32'h00b502b3;  // add x5,x10,x11
        rom[ 11] = 32'h00542023;  // sw x5,0(x8)
        rom[ 12] = 32'h00440413;  // addi x8,x8,4
        rom[ 13] = 32'h40b502b3;  // sub x5,x10,x11
        rom[ 14] = 32'h00542023;  // sw x5,0(x8)
        rom[ 15] = 32'h00440413;  // addi x8,x8,4
        rom[ 16] = 32'h0f000613;  // addi x12,x0,240
        rom[ 17] = 32'h03c00693;  // addi x13,x0,60
        rom[ 18] = 32'h00d672b3;  // and x5,x12,x13
        rom[ 19] = 32'h00542023;  // sw x5,0(x8)
        rom[ 20] = 32'h00440413;  // addi x8,x8,4
        rom[ 21] = 32'h00d662b3;  // or x5,x12,x13
        rom[ 22] = 32'h00542023;  // sw x5,0(x8)
        rom[ 23] = 32'h00440413;  // addi x8,x8,4
        rom[ 24] = 32'h00d642b3;  // xor x5,x12,x13
        rom[ 25] = 32'h00542023;  // sw x5,0(x8)
        rom[ 26] = 32'h00440413;  // addi x8,x8,4
        rom[ 27] = 32'h03c67293;  // andi x5,x12,60
        rom[ 28] = 32'h00542023;  // sw x5,0(x8)
        rom[ 29] = 32'h00440413;  // addi x8,x8,4
        rom[ 30] = 32'h00f66293;  // ori x5,x12,15
        rom[ 31] = 32'h00542023;  // sw x5,0(x8)
        rom[ 32] = 32'h00440413;  // addi x8,x8,4
        rom[ 33] = 32'hfff64293;  // xori x5,x12,-1
        rom[ 34] = 32'h00542023;  // sw x5,0(x8)
        rom[ 35] = 32'h00440413;  // addi x8,x8,4
        rom[ 36] = 32'h00100713;  // addi x14,x0,1
        rom[ 37] = 32'h01f00793;  // addi x15,x0,31
        rom[ 38] = 32'h00f712b3;  // sll x5,x14,x15
        rom[ 39] = 32'h00542023;  // sw x5,0(x8)
        rom[ 40] = 32'h00440413;  // addi x8,x8,4
        rom[ 41] = 32'h00028833;  // add x16,x5,x0
        rom[ 42] = 32'h00471293;  // slli x5,x14,0x4
        rom[ 43] = 32'h00542023;  // sw x5,0(x8)
        rom[ 44] = 32'h00440413;  // addi x8,x8,4
        rom[ 45] = 32'h00f852b3;  // srl x5,x16,x15
        rom[ 46] = 32'h00542023;  // sw x5,0(x8)
        rom[ 47] = 32'h00440413;  // addi x8,x8,4
        rom[ 48] = 32'h00485293;  // srli x5,x16,0x4
        rom[ 49] = 32'h00542023;  // sw x5,0(x8)
        rom[ 50] = 32'h00440413;  // addi x8,x8,4
        rom[ 51] = 32'h40f852b3;  // sra x5,x16,x15
        rom[ 52] = 32'h00542023;  // sw x5,0(x8)
        rom[ 53] = 32'h00440413;  // addi x8,x8,4
        rom[ 54] = 32'h40485293;  // srai x5,x16,0x4
        rom[ 55] = 32'h00542023;  // sw x5,0(x8)
        rom[ 56] = 32'h00440413;  // addi x8,x8,4
        rom[ 57] = 32'h02100893;  // addi x17,x0,33
        rom[ 58] = 32'h011712b3;  // sll x5,x14,x17
        rom[ 59] = 32'h00542023;  // sw x5,0(x8)
        rom[ 60] = 32'h00440413;  // addi x8,x8,4
        rom[ 61] = 32'h00071293;  // slli x5,x14,0x0
        rom[ 62] = 32'h00542023;  // sw x5,0(x8)
        rom[ 63] = 32'h00440413;  // addi x8,x8,4
        rom[ 64] = 32'h00a5a2b3;  // slt x5,x11,x10
        rom[ 65] = 32'h00542023;  // sw x5,0(x8)
        rom[ 66] = 32'h00440413;  // addi x8,x8,4
        rom[ 67] = 32'h00b522b3;  // slt x5,x10,x11
        rom[ 68] = 32'h00542023;  // sw x5,0(x8)
        rom[ 69] = 32'h00440413;  // addi x8,x8,4
        rom[ 70] = 32'h00a5b2b3;  // sltu x5,x11,x10
        rom[ 71] = 32'h00542023;  // sw x5,0(x8)
        rom[ 72] = 32'h00440413;  // addi x8,x8,4
        rom[ 73] = 32'h00b532b3;  // sltu x5,x10,x11
        rom[ 74] = 32'h00542023;  // sw x5,0(x8)
        rom[ 75] = 32'h00440413;  // addi x8,x8,4
        rom[ 76] = 32'hffe5a293;  // slti x5,x11,-2
        rom[ 77] = 32'h00542023;  // sw x5,0(x8)
        rom[ 78] = 32'h00440413;  // addi x8,x8,4
        rom[ 79] = 32'h00552293;  // slti x5,x10,5
        rom[ 80] = 32'h00542023;  // sw x5,0(x8)
        rom[ 81] = 32'h00440413;  // addi x8,x8,4
        rom[ 82] = 32'h00653293;  // sltiu x5,x10,6
        rom[ 83] = 32'h00542023;  // sw x5,0(x8)
        rom[ 84] = 32'h00440413;  // addi x8,x8,4
        rom[ 85] = 32'hfff53293;  // sltiu x5,x10,-1
        rom[ 86] = 32'h00542023;  // sw x5,0(x8)
        rom[ 87] = 32'h00440413;  // addi x8,x8,4
        rom[ 88] = 32'h00103293;  // sltiu x5,x0,1
        rom[ 89] = 32'h00542023;  // sw x5,0(x8)
        rom[ 90] = 32'h00440413;  // addi x8,x8,4
        rom[ 91] = 32'h00e822b3;  // slt x5,x16,x14
        rom[ 92] = 32'h00542023;  // sw x5,0(x8)
        rom[ 93] = 32'h00440413;  // addi x8,x8,4
        rom[ 94] = 32'h00700013;  // addi x0,x0,7
        rom[ 95] = 32'h000002b3;  // add x5,x0,x0
        rom[ 96] = 32'h00542023;  // sw x5,0(x8)
        rom[ 97] = 32'h00440413;  // addi x8,x8,4
        rom[ 98] = 32'h00100493;  // addi x9,x0,1
        rom[ 99] = 32'h00d49493;  // slli x9,x9,0xd
        rom[100] = 32'h40048493;  // addi x9,x9,1024
        rom[101] = 32'h0104a023;  // sw x16,0(x9)
        rom[102] = 32'h00b4a223;  // sw x11,4(x9)
        rom[103] = 32'h0004a283;  // lw x5,0(x9)
        rom[104] = 32'h00542023;  // sw x5,0(x8)
        rom[105] = 32'h00440413;  // addi x8,x8,4
        rom[106] = 32'h00848913;  // addi x18,x9,8
        rom[107] = 32'hffc92283;  // lw x5,-4(x18)
        rom[108] = 32'h00542023;  // sw x5,0(x8)
        rom[109] = 32'h00440413;  // addi x8,x8,4
        rom[110] = 32'h00100293;  // addi x5,x0,1
        rom[111] = 32'h00a50463;  // beq x10,x10,1c4
        rom[112] = 32'h00000293;  // addi x5,x0,0
        rom[113] = 32'h00542023;  // sw x5,0(x8)
        rom[114] = 32'h00440413;  // addi x8,x8,4
        rom[115] = 32'h00100293;  // addi x5,x0,1
        rom[116] = 32'h00b50463;  // beq x10,x11,1d8
        rom[117] = 32'h00000293;  // addi x5,x0,0
        rom[118] = 32'h00542023;  // sw x5,0(x8)
        rom[119] = 32'h00440413;  // addi x8,x8,4
        rom[120] = 32'h00100293;  // addi x5,x0,1
        rom[121] = 32'h00b51463;  // bne x10,x11,1ec
        rom[122] = 32'h00000293;  // addi x5,x0,0
        rom[123] = 32'h00542023;  // sw x5,0(x8)
        rom[124] = 32'h00440413;  // addi x8,x8,4
        rom[125] = 32'h00100293;  // addi x5,x0,1
        rom[126] = 32'h00a51463;  // bne x10,x10,200
        rom[127] = 32'h00000293;  // addi x5,x0,0
        rom[128] = 32'h00542023;  // sw x5,0(x8)
        rom[129] = 32'h00440413;  // addi x8,x8,4
        rom[130] = 32'h00100293;  // addi x5,x0,1
        rom[131] = 32'h00a5c463;  // blt x11,x10,214
        rom[132] = 32'h00000293;  // addi x5,x0,0
        rom[133] = 32'h00542023;  // sw x5,0(x8)
        rom[134] = 32'h00440413;  // addi x8,x8,4
        rom[135] = 32'h00100293;  // addi x5,x0,1
        rom[136] = 32'h00b54463;  // blt x10,x11,228
        rom[137] = 32'h00000293;  // addi x5,x0,0
        rom[138] = 32'h00542023;  // sw x5,0(x8)
        rom[139] = 32'h00440413;  // addi x8,x8,4
        rom[140] = 32'h00100293;  // addi x5,x0,1
        rom[141] = 32'h00e84463;  // blt x16,x14,23c
        rom[142] = 32'h00000293;  // addi x5,x0,0
        rom[143] = 32'h00542023;  // sw x5,0(x8)
        rom[144] = 32'h00440413;  // addi x8,x8,4
        rom[145] = 32'h00100293;  // addi x5,x0,1
        rom[146] = 32'h00b55463;  // bge x10,x11,250
        rom[147] = 32'h00000293;  // addi x5,x0,0
        rom[148] = 32'h00542023;  // sw x5,0(x8)
        rom[149] = 32'h00440413;  // addi x8,x8,4
        rom[150] = 32'h00100293;  // addi x5,x0,1
        rom[151] = 32'h00a5d463;  // bge x11,x10,264
        rom[152] = 32'h00000293;  // addi x5,x0,0
        rom[153] = 32'h00542023;  // sw x5,0(x8)
        rom[154] = 32'h00440413;  // addi x8,x8,4
        rom[155] = 32'h00100293;  // addi x5,x0,1
        rom[156] = 32'h00a55463;  // bge x10,x10,278
        rom[157] = 32'h00000293;  // addi x5,x0,0
        rom[158] = 32'h00542023;  // sw x5,0(x8)
        rom[159] = 32'h00440413;  // addi x8,x8,4
        rom[160] = 32'h00100293;  // addi x5,x0,1
        rom[161] = 32'h01075463;  // bge x14,x16,28c
        rom[162] = 32'h00000293;  // addi x5,x0,0
        rom[163] = 32'h00542023;  // sw x5,0(x8)
        rom[164] = 32'h00440413;  // addi x8,x8,4
        rom[165] = 32'h00000293;  // addi x5,x0,0
        rom[166] = 32'h00500313;  // addi x6,x0,5
        rom[167] = 32'h00128293;  // addi x5,x5,1
        rom[168] = 32'hfe62cee3;  // blt x5,x6,29c
        rom[169] = 32'h00542023;  // sw x5,0(x8)
        rom[170] = 32'h00440413;  // addi x8,x8,4
        rom[171] = 32'h008000ef;  // jal x1,2b4
        rom[172] = 32'h06300393;  // addi x7,x0,99
        rom[173] = 32'h0040036f;  // jal x6,2b8
        rom[174] = 32'h401302b3;  // sub x5,x6,x1
        rom[175] = 32'h00542023;  // sw x5,0(x8)
        rom[176] = 32'h00440413;  // addi x8,x8,4
        rom[177] = 32'h00000293;  // addi x5,x0,0
        rom[178] = 32'h028000ef;  // jal x1,2f0
        rom[179] = 32'h00a28293;  // addi x5,x5,10
        rom[180] = 32'h00542023;  // sw x5,0(x8)
        rom[181] = 32'h00440413;  // addi x8,x8,4
        rom[182] = 32'h00000293;  // addi x5,x0,0
        rom[183] = 32'h01c000ef;  // jal x1,2f8
        rom[184] = 32'h00a28293;  // addi x5,x5,10
        rom[185] = 32'h00542023;  // sw x5,0(x8)
        rom[186] = 32'h00440413;  // addi x8,x8,4
        rom[187] = 32'h0000006f;  // jal x0,2ec
        rom[188] = 32'h00128293;  // addi x5,x5,1
        rom[189] = 32'h00008067;  // jalr x0,0(x1)
        rom[190] = 32'h00128293;  // addi x5,x5,1
        rom[191] = 32'h00108067;  // jalr x0,1(x1)
        esperado[ 0] = 32'h00000005; nombre[ 0] = "addi positivo";
        esperado[ 1] = 32'hFFFFFFFD; nombre[ 1] = "addi negativo";
        esperado[ 2] = 32'h00000002; nombre[ 2] = "add";
        esperado[ 3] = 32'h00000008; nombre[ 3] = "sub";
        esperado[ 4] = 32'h00000030; nombre[ 4] = "and";
        esperado[ 5] = 32'h000000FC; nombre[ 5] = "or";
        esperado[ 6] = 32'h000000CC; nombre[ 6] = "xor";
        esperado[ 7] = 32'h00000030; nombre[ 7] = "andi";
        esperado[ 8] = 32'h000000FF; nombre[ 8] = "ori";
        esperado[ 9] = 32'hFFFFFF0F; nombre[ 9] = "xori";
        esperado[10] = 32'h80000000; nombre[10] = "sll 31";
        esperado[11] = 32'h00000010; nombre[11] = "slli 4";
        esperado[12] = 32'h00000001; nombre[12] = "srl 31";
        esperado[13] = 32'h08000000; nombre[13] = "srli 4";
        esperado[14] = 32'hFFFFFFFF; nombre[14] = "sra 31";
        esperado[15] = 32'hF8000000; nombre[15] = "srai 4";
        esperado[16] = 32'h00000002; nombre[16] = "sll usa 5 bits";
        esperado[17] = 32'h00000001; nombre[17] = "slli 0";
        esperado[18] = 32'h00000001; nombre[18] = "slt -3<5";
        esperado[19] = 32'h00000000; nombre[19] = "slt 5<-3";
        esperado[20] = 32'h00000000; nombre[20] = "sltu grande<5";
        esperado[21] = 32'h00000001; nombre[21] = "sltu 5<grande";
        esperado[22] = 32'h00000001; nombre[22] = "slti -3<-2";
        esperado[23] = 32'h00000000; nombre[23] = "slti 5<5";
        esperado[24] = 32'h00000001; nombre[24] = "sltiu 5<6";
        esperado[25] = 32'h00000001; nombre[25] = "sltiu 5<-1";
        esperado[26] = 32'h00000001; nombre[26] = "sltiu seqz";
        esperado[27] = 32'h00000001; nombre[27] = "slt min<1";
        esperado[28] = 32'h00000000; nombre[28] = "escritura a x0";
        esperado[29] = 32'h80000000; nombre[29] = "lw desp 0";
        esperado[30] = 32'hFFFFFFFD; nombre[30] = "lw desp -4";
        esperado[31] = 32'h00000001; nombre[31] = "beq tomado";
        esperado[32] = 32'h00000000; nombre[32] = "beq no tomado";
        esperado[33] = 32'h00000001; nombre[33] = "bne tomado";
        esperado[34] = 32'h00000000; nombre[34] = "bne no tomado";
        esperado[35] = 32'h00000001; nombre[35] = "blt tomado";
        esperado[36] = 32'h00000000; nombre[36] = "blt no tomado";
        esperado[37] = 32'h00000001; nombre[37] = "blt con desborde";
        esperado[38] = 32'h00000001; nombre[38] = "bge tomado";
        esperado[39] = 32'h00000000; nombre[39] = "bge no tomado";
        esperado[40] = 32'h00000001; nombre[40] = "bge iguales";
        esperado[41] = 32'h00000001; nombre[41] = "bge con desborde";
        esperado[42] = 32'h00000005; nombre[42] = "blt hacia atras";
        esperado[43] = 32'h00000008; nombre[43] = "jal enlace";
        esperado[44] = 32'h0000000B; nombre[44] = "jal+jalr llamada";
        esperado[45] = 32'h0000000B; nombre[45] = "jalr bit0";
    end

    // ---- ejecucion ----
    int          ciclos = 0, fallos = 0, estable = 0;
    logic [31:0] pc_anterior;

    initial begin
        repeat (3) @(posedge clk);
        rst <= 1'b0;
        pc_anterior = 32'hFFFF_FFFF;
        while (ciclos < MAX_CICLOS && estable < 3) begin
            @(posedge clk);
            ciclos++;
            if (prog_addr == pc_anterior) estable++;
            else                          estable = 0;
            pc_anterior = prog_addr;
        end

        if (estable < 3) begin
            $display("FAIL el programa no llego al lazo final en %0d ciclos (PC=%h)", MAX_CICLOS, prog_addr);
            fallos++;
        end else
            $display("Programa terminado en %0d ciclos, PC final = %h", ciclos, prog_addr);

        for (int i = 0; i < N_PRUEBAS; i++) begin
            if (ram[i] === esperado[i])
                $display("PASS %2d %-18s obtenido=%h", i+1, nombre[i], ram[i]);
            else begin
                $display("FAIL %2d %-18s esperado=%h obtenido=%h", i+1, nombre[i], esperado[i], ram[i]);
                fallos++;
            end
        end

        fallos += errores_bus;
        if (fallos == 0) $display("RESULTADO: PASS (%0d pruebas)", N_PRUEBAS);
        else             $display("RESULTADO: FAIL (%0d errores)", fallos);
        $finish;
    end

endmodule
