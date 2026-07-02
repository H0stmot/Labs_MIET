`include "operand_analyzer.v"
`include "pre_res.v"
`include "rounding_module.v"
`include "exp_corr.v"

module real_mul #(
    parameter IS_DOUBLE = 0,
    parameter EXP_W = (IS_DOUBLE) ? 11 : 8,
    parameter MANT_W = (IS_DOUBLE) ? 52 : 23
) (
    input wire clk,
    input wire rst,
    input wire [63:0] op1,
    input wire [63:0] op2,
    output wire [63:0] result
);

    // Для одинарной точности используем младшие 32 бита
    wire [31:0] op_a = IS_DOUBLE ? op1[63:32] : op1[31:0];
    wire [31:0] op_b = IS_DOUBLE ? op2[63:32] : op2[31:0];
    
    // Проводники для специальных случаев
    wire [3:0] special_case;
    
    // Проводники для нормализованных операндов
    wire sign_a, sign_b;
    wire [EXP_W-1:0] exp_a, exp_b;
    wire [MANT_W-1:0] mant_a, mant_b;
    
    // Проводники для умножения мантисс
    wire [2*MANT_W+1:0] mantissa_product;
    wire [MANT_W:0] normalized_mant;
    wire [EXP_W-1:0] product_exp;
    wire exp_overflow;
    
    // Проводники для округления
    localparam TOTAL_WIDTH = (IS_DOUBLE) ? 106 : 48;
    localparam LOW_PART_WIDTH = (IS_DOUBLE) ? 53 : 24;
    
    wire [MANT_W-1:0] rounded_mant;
    wire rounding_overflow, rounding_precision, rounding_no_rounding;
    
    // Анализ операндов и специальных случаев
    operation_analyzer analyzer (
        .op_a(op_a),
        .op_b(op_b),
        .special_case(special_case)
    );
    
    // Обработка специальных случаев
    wire [31:0] result_special;
    pre_res #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) pre_result (
        .op_a(op_a),
        .op_b(op_b),
        .special_case(special_case),
        .result(result_special)
    );
    
    // Если есть специальный случай, используем результат из pre_res
    wire has_special_case = |special_case;
    
    // Извлечение компонентов для нормальных чисел
    assign sign_a = op_a[31];
    assign sign_b = op_b[31];
    assign exp_a = op_a[30:23];
    assign exp_b = op_b[30:23];
    assign mant_a = op_a[22:0];
    assign mant_b = op_b[22:0];
    
    // Добавление скрытых битов для нормализованных чисел
    wire a_is_normalized = (exp_a != 0);
    wire b_is_normalized = (exp_b != 0);
    
    wire [MANT_W:0] extended_mant_a = {a_is_normalized, mant_a};
    wire [MANT_W:0] extended_mant_b = {b_is_normalized, mant_b};
    
    // Умножение мантисс
    assign mantissa_product = extended_mant_a * extended_mant_b;
    
    // Нормализация результата умножения
    wire need_normalization = mantissa_product[2*MANT_W+1];
    
    assign normalized_mant = need_normalization ? 
                            mantissa_product[2*MANT_W:MANT_W] : 
                            mantissa_product[2*MANT_W-1:MANT_W-1];
    
    // Коррекция экспоненты
    exp_corr #(
        .IS_DOUBLE(IS_DOUBLE),
        .EXP_WIDTH(EXP_W),
        .MANT_WIDTH(MANT_W)
    ) exp_corrector (
        .overflow_flag(1'b0), // Пока не используется
        .mantissa_product(mantissa_product),
        .exponent_a(exp_a),
        .exponent_b(exp_b),
        .exponent_corrected(product_exp)
    );
    
    // Подготовка значения для округления
    wire [TOTAL_WIDTH-1:0] rounding_input;
    
    // Формируем значение для округления: [normalized_mant][остаток]
    assign rounding_input = {normalized_mant, mantissa_product[MANT_W-2:0], {(TOTAL_WIDTH-2*MANT_W-1){1'b0}}};
    
    // Округление
    rounding_module #(
        .IS_DOUBLE(IS_DOUBLE),
        .HIGH_PART_WIDTH(MANT_W),
        .LOW_PART_WIDTH(LOW_PART_WIDTH),
        .TOTAL_WIDTH(TOTAL_WIDTH)
    ) rounder (
        .round_mode(2'b11), // Округление к ближайшему четному по умолчанию
        .input_value(rounding_input),
        .sign_bit(sign_a ^ sign_b),
        .rounded(rounded_mant),
        .precision_flag(rounding_precision),
        .overflow_flag(rounding_overflow),
        .no_rounding_flag(rounding_no_rounding)
    );
    
    // Формирование окончательного результата
    wire [31:0] normal_result = {
        sign_a ^ sign_b,    // Знак результата
        product_exp,        // Экспонента
        rounded_mant        // Мантисса
    };
    
    // Выбор результата: специальный случай или нормальный результат
    wire [31:0] single_result = has_special_case ? result_special : normal_result;
    
    // Для double precision расширяем результат
    assign result = IS_DOUBLE ? {single_result, 32'b0} : {32'b0, single_result};

endmodule