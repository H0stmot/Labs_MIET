module exp_corr  #(
    parameter IS_DOUBLE  = 0,
    parameter EXP_WIDTH  = IS_DOUBLE == 1 ? 11 : 8,
    parameter MANT_WIDTH = IS_DOUBLE == 1 ? 52 : 23
)(
    input  wire                              overflow_flag,
    input  wire [2*MANT_WIDTH+1:0]           mantissa_product,
    input  wire [EXP_WIDTH-1:0]              exponent_a,
    input  wire [EXP_WIDTH-1:0]              exponent_b,
    output wire [EXP_WIDTH-1:0]              exponent_corrected
);

    // Вычисляем bias в зависимости от типа
    localparam BIAS = IS_DOUBLE ? 1023 : 127;
    
    // Сумма экспонент
    wire [EXP_WIDTH:0] exponent_sum;
    assign exponent_sum = exponent_a + exponent_b - BIAS;
    
    // Определяем паттерны старших битов мантиссы
    wire msb_pattern_01 = (mantissa_product[2*MANT_WIDTH+1:2*MANT_WIDTH] == 2'b01);
    wire msb_pattern_10 = (mantissa_product[2*MANT_WIDTH+1:2*MANT_WIDTH] == 2'b10);
    wire msb_pattern_11 = (mantissa_product[2*MANT_WIDTH+1:2*MANT_WIDTH] == 2'b11);
    
    // Корректирующее значение для экспоненты
    wire [1:0] exponent_correction;
    assign exponent_correction = msb_pattern_01 ? {1'b0, overflow_flag} :           // +1 если старшие биты 01 и есть округление
                                 msb_pattern_10 ?  2'b01 :                          // +1 если старшие биты 10
                                 msb_pattern_11 ? (overflow_flag ? 2'b10 : 2'b01) : // +1 если старшие биты 11 и нет округления или +2 если оно есть
                                                   2'b00;                           // +0 
    
    // Корректированная экспонента
    assign exponent_corrected = exponent_sum + exponent_correction;

endmodule 