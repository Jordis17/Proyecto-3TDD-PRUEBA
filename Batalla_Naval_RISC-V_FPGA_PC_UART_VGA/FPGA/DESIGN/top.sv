// =====================================================================
// top.sv - Sistema Batalla Naval sobre RISC-V (Nexys 4)
//
// Une los bloques del diagrama de segundo nivel (planteamiento, 5):
//   clk_gen       PLL: 50 MHz sistema, 25 MHz pixel, reinicios
//   riscv_core    procesador RV32I uniciclo
//   rom / ram     memoria de programa y de datos
//   data_bus      decodificador de direcciones del bus de datos
//   perifericos   UART, entradas J1, displays, LED, buzzer, VGA
//
// Solo hay reinicio general al programar la tarjeta (mientras el PLL
// no esta enclavado). BTN_RST lo atiende el programa.
//
// Los parametros de tiempo existen para acelerar la simulacion del
// sistema; en la tarjeta se usan los valores por defecto.
// =====================================================================

module top #(
    parameter        PROGRAM_FILE = "programa.mem",
    parameter int    CLK_HZ       = 50_000_000,
    parameter int    TICK_CYCLES  = 50_000,    // 1 ms a 50 MHz
    parameter int    DEBOUNCE_MS  = 10,
    parameter int    BAUD_DIV     = 434,       // 115200 baud a 50 MHz
    parameter int    BAUD_X16_DIV = 27
) (
    input  logic        clk100_i,

    // entradas del Jugador 1
    input  logic        btn_up_i,
    input  logic        btn_down_i,
    input  logic        btn_left_i,
    input  logic        btn_right_i,
    input  logic        btn_center_i,     // BTN_RST
    input  logic        btn_cpu_reset_n_i,// BTN_OK (activo en bajo)
    input  logic        sw_sel_i,         // BTN_SEL (SW0)

    // UART
    input  logic        uart_rx_i,
    output logic        uart_tx_o,

    // displays, LED y audio
    output logic [6:0]  seg_o,
    output logic        dp_o,
    output logic [7:0]  an_o,
    output logic [15:0] led_o,
    output logic        aud_pwm_o,
    output logic        aud_sd_o,

    // VGA
    output logic [3:0]  vga_r_o,
    output logic [3:0]  vga_g_o,
    output logic [3:0]  vga_b_o,
    output logic        vga_hs_o,
    output logic        vga_vs_o
);

    // ---- relojes y reinicios ----
    logic clk, clk_pix, rst, rst_pix;

    clk_gen u_clk (
        .clk100_i(clk100_i), .clk_sys_o(clk), .clk_pix_o(clk_pix),
        .rst_sys_o(rst), .rst_pix_o(rst_pix)
    );

    // ---- procesador y memoria de programa ----
    logic [31:0] prog_addr, prog_in, data_addr, data_out, data_in;
    logic        we;

    riscv_core u_cpu (
        .clk_i(clk), .rst_i(rst),
        .ProgAddress_o(prog_addr), .ProgIn_i(prog_in),
        .DataAddress_o(data_addr), .DataOut_o(data_out),
        .DataIn_i(data_in), .we_o(we)
    );

    rom #(.INIT_FILE(PROGRAM_FILE)) u_rom (.addr_i(prog_addr), .data_o(prog_in));

    // ---- bus de datos ----
    logic [31:0] wdata, ram_rd, uart_rd, in_rd, seg_rd, led_rd, buz_rd, vga_rd;
    logic [9:0]  ram_addr;
    logic [8:0]  vga_addr;
    logic [1:0]  reg_addr;
    logic        ram_we, uart_we, in_we, seg_we, led_we, buz_we, vga_we;

    data_bus u_bus (
        .addr_i(data_addr), .wdata_i(data_out), .we_i(we), .rdata_o(data_in),
        .wdata_o(wdata),
        .ram_we_o(ram_we), .ram_addr_o(ram_addr), .ram_rdata_i(ram_rd),
        .reg_addr_o(reg_addr),
        .uart_we_o(uart_we), .uart_rdata_i(uart_rd),
        .in_we_o(in_we),     .in_rdata_i(in_rd),
        .seg_we_o(seg_we),   .seg_rdata_i(seg_rd),
        .led_we_o(led_we),   .led_rdata_i(led_rd),
        .buz_we_o(buz_we),   .buz_rdata_i(buz_rd),
        .vga_we_o(vga_we),   .vga_addr_o(vga_addr), .vga_rdata_i(vga_rd)
    );

    ram u_ram (.clk_i(clk), .we_i(ram_we), .addr_i(ram_addr),
               .wdata_i(wdata), .rdata_o(ram_rd));

    // ---- base de tiempo de 1 ms ----
    logic tick;
    clk_tick_gen #(.TICK_CYCLES(TICK_CYCLES)) u_tick (.clk_i(clk), .rst_i(rst), .tick_o(tick));

    // ---- UART ----
    logic [7:0] tx_data, rx_data;
    logic       tx_start, tx_busy, rx_valid;

    uart_peripheral u_uart (
        .clk_i(clk), .rst_i(rst),
        .write_enable_i(uart_we), .addr_i(reg_addr), .wdata_i(wdata), .rdata_o(uart_rd),
        .tx_data_o(tx_data), .tx_start_o(tx_start), .tx_busy_i(tx_busy),
        .rx_data_i(rx_data), .rx_valid_i(rx_valid)
    );

    uart_core #(.BAUD_DIV(BAUD_DIV), .BAUD_X16_DIV(BAUD_X16_DIV)) u_uart_core (
        .clk_i(clk), .rst_i(rst), .tx_o(uart_tx_o), .rx_i(uart_rx_i),
        .tx_data_i(tx_data), .tx_start_i(tx_start), .tx_busy_o(tx_busy),
        .rx_data_o(rx_data), .rx_valid_o(rx_valid)
    );

    // ---- entradas del Jugador 1 ----
    input_peripheral #(.DEBOUNCE_MS(DEBOUNCE_MS)) u_in (
        .clk_i(clk), .rst_i(rst),
        .write_enable_i(in_we), .addr_i(reg_addr), .wdata_i(wdata), .rdata_o(in_rd),
        .tick_i(tick),
        .btn_up_i(btn_up_i), .btn_down_i(btn_down_i),
        .btn_left_i(btn_left_i), .btn_right_i(btn_right_i),
        .sw_sel_i(sw_sel_i), .btn_ok_n_i(btn_cpu_reset_n_i), .btn_rst_i(btn_center_i)
    );

    // ---- displays, LED y buzzer ----
    seg_peripheral u_seg (
        .clk_i(clk), .rst_i(rst),
        .write_enable_i(seg_we), .addr_i(reg_addr), .wdata_i(wdata), .rdata_o(seg_rd),
        .tick_i(tick), .seg_o(seg_o), .an_o(an_o)
    );
    assign dp_o = 1'b1;   // punto decimal apagado (activo en bajo)

    led_peripheral u_led (
        .clk_i(clk), .rst_i(rst),
        .write_enable_i(led_we), .addr_i(reg_addr), .wdata_i(wdata), .rdata_o(led_rd),
        .led_o(led_o)
    );

    buzzer_peripheral #(.CLK_HZ(CLK_HZ)) u_buz (
        .clk_i(clk), .rst_i(rst),
        .write_enable_i(buz_we), .addr_i(reg_addr), .wdata_i(wdata), .rdata_o(buz_rd),
        .tick_i(tick), .aud_pwm_o(aud_pwm_o), .aud_sd_o(aud_sd_o)
    );

    // ---- VGA ----
    vga_peripheral u_vga (
        .clk_i(clk), .rst_i(rst),
        .write_enable_i(vga_we), .addr_i(vga_addr), .wdata_i(wdata), .rdata_o(vga_rd),
        .clk_pix_i(clk_pix), .rst_pix_i(rst_pix),
        .vga_r_o(vga_r_o), .vga_g_o(vga_g_o), .vga_b_o(vga_b_o),
        .vga_hs_o(vga_hs_o), .vga_vs_o(vga_vs_o)
    );

endmodule
