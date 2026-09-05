// Модуль формирования результата для специальных случаев IEEE-754.
module pre_res #(
    parameter EXP_W  = 8,
    parameter MANT_W = 23
)(
    input  wire [EXP_W+MANT_W:0] op_a,
    input  wire [EXP_W+MANT_W:0] op_b,
    input  wire [EXP_W+MANT_W:0] op_c,
    input  wire [4:0]            special_case,
    output wire                  has_special_case,
    output wire                  invalid_flag,
    output wire [EXP_W+MANT_W:0] result
);

    localparam WIDTH = EXP_W + MANT_W + 1;

    wire product_sign;
    wire [WIDTH-1:0] quiet_nan;
    wire [WIDTH-1:0] product_infinity;
    wire [WIDTH-1:0] operand_c_infinity;

    assign product_sign = op_a[WIDTH-1] ^ op_b[WIDTH-1];

    // Для NaN используется единое каноническое представление quiet NaN.
    assign quiet_nan = {
        1'b0,
        {EXP_W{1'b1}},
        1'b1,
        {(MANT_W-1){1'b0}}
    };

    assign product_infinity = {
        product_sign,
        {EXP_W{1'b1}},
        {MANT_W{1'b0}}
    };

    assign operand_c_infinity = {
        op_c[WIDTH-1],
        {EXP_W{1'b1}},
        {MANT_W{1'b0}}
    };

    assign has_special_case = |special_case;
    assign invalid_flag = special_case[4] ||
                          special_case[3] ||
                          special_case[2];

    assign result = (special_case[4] ||
                     special_case[3] ||
                     special_case[2]) ? quiet_nan :
                    special_case[1] ? product_infinity :
                    special_case[0] ? operand_c_infinity :
                    {WIDTH{1'b0}};

endmodule
