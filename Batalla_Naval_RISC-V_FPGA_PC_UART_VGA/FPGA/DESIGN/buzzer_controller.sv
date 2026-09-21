// =====================================================================
// buzzer_controller.sv - Generador de tonos de los eventos del juego
//
// Adaptado del buzzer_controller del Proyecto 2: misma forma de generar
// la onda cuadrada (contador de semiperiodo) y de medir la duracion
// (contador de milisegundos con el tick), con los eventos del
// Proyecto 3:
//
//   1 Impacto             2 kHz                          100 ms
//   2 Fallo               500 Hz                         150 ms
//   3 Barco hundido       3 kHz -> 2 kHz -> 3 kHz        80 ms cada tono
//   4 Colocacion invalida 250 Hz                         250 ms
//   5 Victoria            2 kHz -> 2,5 kHz -> 3 kHz      150 ms cada tono
//
// Impacto (agudo y corto) y fallo (grave) se distinguen sin mirar la
// pantalla; hundido alterna dos tonos; la colocacion invalida es el mas
// grave y largo; la victoria sube de tono.
//
// Politica: un evento nuevo siempre reemplaza al que este sonando. En
// el juego un evento posterior es mas reciente y relevante (por
// ejemplo, hundido o victoria justo despues del impacto).
//
// La Nexys 4 no trae zumbador: la onda sale por el amplificador PWM de
// la salida de audio (AUD_PWM, AUD_SD).
// =====================================================================

module buzzer_controller #(
    parameter int   CLK_HZ           = 50_000_000,
    parameter logic AMP_ENABLE_LEVEL = 1'b1
) (
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic       tick_i,        // pulso de 1 ms
    input  logic [2:0] snd_event_i,   // evento a reproducir
    input  logic       snd_start_i,   // pulso de inicio
    output logic       aud_pwm_o,
    output logic       aud_sd_o,
    output logic       busy_o
);

    localparam logic [2:0] EV_NINGUNO  = 3'd0;
    localparam logic [2:0] EV_IMPACTO  = 3'd1;
    localparam logic [2:0] EV_FALLO    = 3'd2;
    localparam logic [2:0] EV_HUNDIDO  = 3'd3;
    localparam logic [2:0] EV_INVALIDA = 3'd4;
    localparam logic [2:0] EV_VICTORIA = 3'd5;

    // ciclos de reloj por semiperiodo de cada tono (redondeado)
    localparam int SP_3K0 = (CLK_HZ + 3000) / (2 * 3000);
    localparam int SP_2K5 = (CLK_HZ + 2500) / (2 * 2500);
    localparam int SP_2K0 = (CLK_HZ + 2000) / (2 * 2000);
    localparam int SP_500 = (CLK_HZ +  500) / (2 *  500);
    localparam int SP_250 = (CLK_HZ +  250) / (2 *  250);

    // el semiperiodo mas largo (250 Hz) fija el ancho del contador
    localparam int W_DIV = (SP_250 <= 1) ? 1 : $clog2(SP_250 + 1);

    logic              sonando_q;
    logic [2:0]        ev_q;
    logic [1:0]        tono_q;
    logic [W_DIV-1:0]  div_q;
    logic [7:0]        ms_q;
    logic              pwm_q;

    logic [W_DIV-1:0]  semiperiodo;
    logic [7:0]        duracion;
    logic              es_ultimo;

    always_comb begin
        semiperiodo = W_DIV'(SP_2K0);
        duracion    = 8'd1;
        es_ultimo   = 1'b1;
        case (ev_q)
            EV_IMPACTO: begin
                semiperiodo = W_DIV'(SP_2K0);
                duracion    = 8'd100;
            end
            EV_FALLO: begin
                semiperiodo = W_DIV'(SP_500);
                duracion    = 8'd150;
            end
            EV_HUNDIDO: begin
                duracion  = 8'd80;
                es_ultimo = (tono_q == 2'd2);
                semiperiodo = (tono_q == 2'd1) ? W_DIV'(SP_2K0) : W_DIV'(SP_3K0);
            end
            EV_INVALIDA: begin
                semiperiodo = W_DIV'(SP_250);
                duracion    = 8'd250;
            end
            EV_VICTORIA: begin
                duracion  = 8'd150;
                es_ultimo = (tono_q == 2'd2);
                case (tono_q)
                    2'd0:    semiperiodo = W_DIV'(SP_2K0);
                    2'd1:    semiperiodo = W_DIV'(SP_2K5);
                    default: semiperiodo = W_DIV'(SP_3K0);
                endcase
            end
            default: ;
        endcase
    end

    logic acepta;
    assign acepta = snd_start_i && (snd_event_i != EV_NINGUNO) &&
                    (snd_event_i <= EV_VICTORIA);

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            sonando_q <= 1'b0;
            ev_q      <= EV_NINGUNO;
            tono_q    <= 2'd0;
            div_q     <= '0;
            ms_q      <= '0;
            pwm_q     <= 1'b0;
        end else if (acepta) begin
            sonando_q <= 1'b1;
            ev_q      <= snd_event_i;
            tono_q    <= 2'd0;
            div_q     <= '0;
            ms_q      <= '0;
            pwm_q     <= 1'b0;
        end else if (sonando_q) begin
            // se invierte la salida cada semiperiodo
            if (div_q == semiperiodo - 1'b1) begin
                div_q <= '0;
                pwm_q <= ~pwm_q;
            end else begin
                div_q <= div_q + 1'b1;
            end

            // duracion de cada tono en milisegundos
            if (tick_i) begin
                if (ms_q == duracion - 8'd1) begin
                    ms_q  <= '0;
                    div_q <= '0;
                    pwm_q <= 1'b0;
                    if (es_ultimo) sonando_q <= 1'b0;
                    else           tono_q    <= tono_q + 2'd1;
                end else begin
                    ms_q <= ms_q + 8'd1;
                end
            end
        end
    end

    assign aud_pwm_o = pwm_q;
    assign aud_sd_o  = AMP_ENABLE_LEVEL;
    assign busy_o    = sonando_q;

endmodule
