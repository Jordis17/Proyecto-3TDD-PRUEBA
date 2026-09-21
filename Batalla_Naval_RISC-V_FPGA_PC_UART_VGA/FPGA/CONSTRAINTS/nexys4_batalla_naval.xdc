## =====================================================================
## nexys4_batalla_naval.xdc - Restricciones para la Nexys 4 (rev B)
## Pines tomados del archivo general de la tarjeta proporcionado por el
## curso. Solo se declaran los puertos que usa top.sv.
## =====================================================================

## Reloj de 100 MHz. Los relojes de 50 y 25 MHz los genera el PLL y
## Vivado los deriva automaticamente de este.
set_property PACKAGE_PIN E3 [get_ports clk100_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk100_i]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports clk100_i]

## Botones
set_property PACKAGE_PIN F15 [get_ports btn_up_i]
set_property PACKAGE_PIN V10 [get_ports btn_down_i]
set_property PACKAGE_PIN T16 [get_ports btn_left_i]
set_property PACKAGE_PIN R10 [get_ports btn_right_i]
set_property PACKAGE_PIN E16 [get_ports btn_center_i]
set_property PACKAGE_PIN C12 [get_ports btn_cpu_reset_n_i]
set_property IOSTANDARD LVCMOS33 [get_ports {btn_up_i btn_down_i btn_left_i btn_right_i btn_center_i btn_cpu_reset_n_i}]

## Switch SW0 (BTN_SEL)
set_property PACKAGE_PIN U9 [get_ports sw_sel_i]
set_property IOSTANDARD LVCMOS33 [get_ports sw_sel_i]

## UART (puente USB-UART)
set_property PACKAGE_PIN C4 [get_ports uart_rx_i]
set_property PACKAGE_PIN D4 [get_ports uart_tx_o]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx_i uart_tx_o}]

## LED
set_property PACKAGE_PIN T8 [get_ports {led_o[0]}]
set_property PACKAGE_PIN V9 [get_ports {led_o[1]}]
set_property PACKAGE_PIN R8 [get_ports {led_o[2]}]
set_property PACKAGE_PIN T6 [get_ports {led_o[3]}]
set_property PACKAGE_PIN T5 [get_ports {led_o[4]}]
set_property PACKAGE_PIN T4 [get_ports {led_o[5]}]
set_property PACKAGE_PIN U7 [get_ports {led_o[6]}]
set_property PACKAGE_PIN U6 [get_ports {led_o[7]}]
set_property PACKAGE_PIN V4 [get_ports {led_o[8]}]
set_property PACKAGE_PIN U3 [get_ports {led_o[9]}]
set_property PACKAGE_PIN V1 [get_ports {led_o[10]}]
set_property PACKAGE_PIN R1 [get_ports {led_o[11]}]
set_property PACKAGE_PIN P5 [get_ports {led_o[12]}]
set_property PACKAGE_PIN U1 [get_ports {led_o[13]}]
set_property PACKAGE_PIN R2 [get_ports {led_o[14]}]
set_property PACKAGE_PIN P2 [get_ports {led_o[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_o[*]}]

## Displays de 7 segmentos {g,f,e,d,c,b,a} = seg_o[6:0]
set_property PACKAGE_PIN L3 [get_ports {seg_o[0]}]
set_property PACKAGE_PIN N1 [get_ports {seg_o[1]}]
set_property PACKAGE_PIN L5 [get_ports {seg_o[2]}]
set_property PACKAGE_PIN L4 [get_ports {seg_o[3]}]
set_property PACKAGE_PIN K3 [get_ports {seg_o[4]}]
set_property PACKAGE_PIN M2 [get_ports {seg_o[5]}]
set_property PACKAGE_PIN L6 [get_ports {seg_o[6]}]
set_property PACKAGE_PIN M4 [get_ports dp_o]
set_property PACKAGE_PIN N6 [get_ports {an_o[0]}]
set_property PACKAGE_PIN M6 [get_ports {an_o[1]}]
set_property PACKAGE_PIN M3 [get_ports {an_o[2]}]
set_property PACKAGE_PIN N5 [get_ports {an_o[3]}]
set_property PACKAGE_PIN N2 [get_ports {an_o[4]}]
set_property PACKAGE_PIN N4 [get_ports {an_o[5]}]
set_property PACKAGE_PIN L1 [get_ports {an_o[6]}]
set_property PACKAGE_PIN M1 [get_ports {an_o[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg_o[*] dp_o an_o[*]}]

## Audio (amplificador PWM de la tarjeta)
set_property PACKAGE_PIN A11 [get_ports aud_pwm_o]
set_property PACKAGE_PIN D12 [get_ports aud_sd_o]
set_property IOSTANDARD LVCMOS33 [get_ports {aud_pwm_o aud_sd_o}]

## VGA
set_property PACKAGE_PIN A3 [get_ports {vga_r_o[0]}]
set_property PACKAGE_PIN B4 [get_ports {vga_r_o[1]}]
set_property PACKAGE_PIN C5 [get_ports {vga_r_o[2]}]
set_property PACKAGE_PIN A4 [get_ports {vga_r_o[3]}]
set_property PACKAGE_PIN C6 [get_ports {vga_g_o[0]}]
set_property PACKAGE_PIN A5 [get_ports {vga_g_o[1]}]
set_property PACKAGE_PIN B6 [get_ports {vga_g_o[2]}]
set_property PACKAGE_PIN A6 [get_ports {vga_g_o[3]}]
set_property PACKAGE_PIN B7 [get_ports {vga_b_o[0]}]
set_property PACKAGE_PIN C7 [get_ports {vga_b_o[1]}]
set_property PACKAGE_PIN D7 [get_ports {vga_b_o[2]}]
set_property PACKAGE_PIN D8 [get_ports {vga_b_o[3]}]
set_property PACKAGE_PIN B11 [get_ports vga_hs_o]
set_property PACKAGE_PIN B12 [get_ports vga_vs_o]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r_o[*] vga_g_o[*] vga_b_o[*] vga_hs_o vga_vs_o}]

## Entradas asincronas: pasan por sincronizadores de dos flip-flops
## (button_input y el receptor UART), por lo que no se analiza su
## temporizacion respecto al reloj.
set_false_path -from [get_ports {btn_up_i btn_down_i btn_left_i btn_right_i btn_center_i btn_cpu_reset_n_i sw_sel_i uart_rx_i}]

## Configuracion del banco de configuracion
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
