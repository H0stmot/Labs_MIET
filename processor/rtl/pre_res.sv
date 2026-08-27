


module pre_res #(
    parameter EXP_W = 8,     // Ширина экспоненты
    parameter MANT_W = 23    // Ширина мантиссы (без скрытого бита)
) (
    input wire [31:0] op_a,          // Операнд A
    input wire [31:0] op_b,          // Операнд B
    input wire [3:0] special_case,   // Вектор признаков из модуля анализа:
                                     // [3] - case 1: NaN
                                     // [2] - case 2: 0 * inf
                                     // [1] - case 3: 0 * число
                                     // [0] - case 4: inf * число
    
    output wire [31:0] result        // Результат
);

    // Извлечение компонентов операндов
    wire sign_a = op_a[31];
    wire sign_b = op_b[31];
    wire [EXP_W-1:0] exp_a = op_a[30:23];
    wire [EXP_W-1:0] exp_b = op_b[30:23];
    wire [MANT_W-1:0] mant_a = op_a[22:0];
    wire [MANT_W-1:0] mant_b = op_b[22:0];
    
    // Вычисление знака результата (XOR знаков операндов)
    wire result_sign = sign_a ^ sign_b;
    
    // Константы
    wire [EXP_W-1:0] exp_all_ones = {EXP_W{1'b1}};
    wire [EXP_W-1:0] exp_all_zeros = {EXP_W{1'b0}};
    wire [MANT_W-1:0] mant_all_zeros = {MANT_W{1'b0}};
    wire [MANT_W-1:0] mant_nan_pattern = {1'b1, {MANT_W-1{1'b0}}};
    
    // Case 1: NaN - берем первый операнд, устанавливаем старший бит мантиссы в 1
    wire [31:0] case1_result = {
        op_a[31],       // sign
        op_a[30:23],    // exponent
        {1'b1, op_a[21:0]} // mantissa with MSB set to 1
    };
    
    // Case 2: 0 * inf - s=1, exp=все_единицы, frac=1_0...0
    wire [31:0] case2_result = {
        1'b1,           // sign = 1 (negative)
        exp_all_ones,   // exponent = all ones
        mant_nan_pattern // mantissa = 1 followed by zeros
    };
    
    // Case 3: 0 * число - ноль со знаком
    wire [31:0] case3_result = {
        result_sign,    // sign from XOR
        exp_all_zeros,  // exponent = all zeros
        mant_all_zeros  // mantissa = all zeros
    };
    
    // Case 4: inf * число - бесконечность со знаком
    wire [31:0] case4_result = {
        result_sign,    // sign from XOR
        exp_all_ones,   // exponent = all ones
        mant_all_zeros  // mantissa = all zeros
    };
    
    // Выбор результата на основе приоритета случаев
    assign result = special_case[3] ? case1_result :  // NaN имеет наивысший приоритет
                   special_case[2] ? case2_result :  // 0 * inf
                   special_case[1] ? case3_result :  // 0 * число
                   special_case[0] ? case4_result :  // inf * число
                   {result_sign, exp_all_zeros, mant_all_zeros}; // default

endmodule







