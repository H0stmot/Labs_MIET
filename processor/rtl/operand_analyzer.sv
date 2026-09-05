// Модуль анализа одного операнда IEEE-754.
// Определяет класс числа и отдельно формирует знак, порядок и мантиссу.
module operand_analyzer #(
    parameter EXP_W  = 8,
    parameter MANT_W = 23
)(
    input  wire [EXP_W+MANT_W:0] operand,
    output wire                  is_zero,
    output wire                  is_normalized,
    output wire                  is_denormalized,
    output wire                  is_infinity,
    output wire                  is_nan,
    output wire                  is_snan,
    output wire                  is_qnan,
    output wire                  sign,
    output wire [EXP_W-1:0]      exponent,
    output wire [MANT_W-1:0]     mantissa
);

    localparam WIDTH = EXP_W + MANT_W + 1;

    wire exponent_all_zero;
    wire exponent_all_one;
    wire mantissa_all_zero;

    assign sign = operand[WIDTH-1];
    assign exponent = operand[WIDTH-2 -: EXP_W];
    assign mantissa = operand[MANT_W-1:0];

    assign exponent_all_zero = (exponent == {EXP_W{1'b0}});
    assign exponent_all_one = (exponent == {EXP_W{1'b1}});
    assign mantissa_all_zero = (mantissa == {MANT_W{1'b0}});

    assign is_zero = exponent_all_zero && mantissa_all_zero;
    assign is_denormalized = exponent_all_zero && !mantissa_all_zero;
    assign is_normalized = !exponent_all_zero && !exponent_all_one;
    assign is_infinity = exponent_all_one && mantissa_all_zero;
    assign is_nan = exponent_all_one && !mantissa_all_zero;
    assign is_snan = is_nan && !mantissa[MANT_W-1];
    assign is_qnan = is_nan && mantissa[MANT_W-1];

endmodule


// Модуль совместного анализа трех операндов FMA: A * B + C.
// Вектор special_case описывает случаи, которые не должны поступать
// в основной тракт умножения и сложения.
module operation_analyzer #(
    parameter EXP_W  = 8,
    parameter MANT_W = 23
)(
    input  wire [EXP_W+MANT_W:0] op_a,
    input  wire [EXP_W+MANT_W:0] op_b,
    input  wire [EXP_W+MANT_W:0] op_c,
    output wire [4:0]            special_case
);

    wire a_zero;
    wire a_infinity;
    wire a_nan;
    wire b_zero;
    wire b_infinity;
    wire b_nan;
    wire c_infinity;
    wire c_nan;
    wire sign_a;
    wire sign_b;
    wire sign_c;

    operand_analyzer #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) analyzer_a (
        .operand(op_a),
        .is_zero(a_zero),
        .is_normalized(),
        .is_denormalized(),
        .is_infinity(a_infinity),
        .is_nan(a_nan),
        .is_snan(),
        .is_qnan(),
        .sign(sign_a),
        .exponent(),
        .mantissa()
    );

    operand_analyzer #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) analyzer_b (
        .operand(op_b),
        .is_zero(b_zero),
        .is_normalized(),
        .is_denormalized(),
        .is_infinity(b_infinity),
        .is_nan(b_nan),
        .is_snan(),
        .is_qnan(),
        .sign(sign_b),
        .exponent(),
        .mantissa()
    );

    operand_analyzer #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) analyzer_c (
        .operand(op_c),
        .is_zero(),
        .is_normalized(),
        .is_denormalized(),
        .is_infinity(c_infinity),
        .is_nan(c_nan),
        .is_snan(),
        .is_qnan(),
        .sign(sign_c),
        .exponent(),
        .mantissa()
    );

    wire product_infinity;
    wire invalid_zero_multiply_infinity;
    wire invalid_infinity_subtraction;

    assign product_infinity = (a_infinity || b_infinity) &&
                              !(a_zero || b_zero);

    assign invalid_zero_multiply_infinity =
        (a_zero || b_zero) && (a_infinity || b_infinity);

    assign invalid_infinity_subtraction =
        product_infinity && c_infinity &&
        ((sign_a ^ sign_b) != sign_c);

    assign special_case[4] = a_nan || b_nan || c_nan;
    assign special_case[3] = invalid_zero_multiply_infinity;
    assign special_case[2] = invalid_infinity_subtraction;
    assign special_case[1] = product_infinity;
    assign special_case[0] = c_infinity;

endmodule
