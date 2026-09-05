// Четырехступенчатый конвейерный умножитель IEEE-754.
// format: 00 - FP16, 01 - FP32, 10 - FP64, 11 - ошибка формата.
module real_mul (
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] op1,
    input  wire [63:0] op2,
    input  wire [1:0]  format,
    input  wire [1:0]  round_mode,
    input  wire        valid_in,
    output wire        ready_in,
    output wire        valid_out,
    output wire [63:0] result,
    output wire        invalid,
    output wire        overflow,
    output wire        underflow,
    output wire        inexact
);

    // Первая ступень: регистрация входной команды.
    reg [63:0] operand_a_stage_1;
    reg [63:0] operand_b_stage_1;
    reg [1:0] format_stage_1;
    reg [1:0] round_mode_stage_1;
    reg valid_stage_1;

    // Параллельное вычисление результата каждого формата.
    wire [15:0] result_fp16;
    wire [31:0] result_fp32;
    wire [63:0] result_fp64;
    wire [3:0] flags_fp16;
    wire [3:0] flags_fp32;
    wire [3:0] flags_fp64;

    fp_mul_datapath #(
        .EXP_W(5),
        .MANT_W(10)
    ) datapath_fp16 (
        .op_a(operand_a_stage_1[15:0]),
        .op_b(operand_b_stage_1[15:0]),
        .op_c(16'b0),
        .round_mode(round_mode_stage_1),
        .result(result_fp16),
        .flags(flags_fp16)
    );

    fp_mul_datapath #(
        .EXP_W(8),
        .MANT_W(23)
    ) datapath_fp32 (
        .op_a(operand_a_stage_1[31:0]),
        .op_b(operand_b_stage_1[31:0]),
        .op_c(32'b0),
        .round_mode(round_mode_stage_1),
        .result(result_fp32),
        .flags(flags_fp32)
    );

    fp_mul_datapath #(
        .EXP_W(11),
        .MANT_W(52)
    ) datapath_fp64 (
        .op_a(operand_a_stage_1),
        .op_b(operand_b_stage_1),
        .op_c(64'b0),
        .round_mode(round_mode_stage_1),
        .result(result_fp64),
        .flags(flags_fp64)
    );

    reg [63:0] selected_result;
    reg [3:0] selected_flags;

    // Вторая ступень получает результат выбранного формата.
    always @* begin
        case (format_stage_1)
            2'b00: begin
                selected_result = {48'b0, result_fp16};
                selected_flags = flags_fp16;
            end
            2'b01: begin
                selected_result = {32'b0, result_fp32};
                selected_flags = flags_fp32;
            end
            2'b10: begin
                selected_result = result_fp64;
                selected_flags = flags_fp64;
            end
            default: begin
                selected_result = 64'h7FF8000000000000;
                selected_flags = 4'b1000;
            end
        endcase
    end

    reg [63:0] result_stage_2;
    reg [63:0] result_stage_3;
    reg [63:0] result_stage_4;
    reg [3:0] flags_stage_2;
    reg [3:0] flags_stage_3;
    reg [3:0] flags_stage_4;
    reg valid_stage_2;
    reg valid_stage_3;
    reg valid_stage_4;

    // Регистры всех четырех ступеней конвейера.
    // После заполнения конвейер принимает новую команду каждый такт.
    always @(posedge clk) begin
        if (rst) begin
            operand_a_stage_1 <= 64'b0;
            operand_b_stage_1 <= 64'b0;
            format_stage_1 <= 2'b0;
            round_mode_stage_1 <= 2'b0;
            valid_stage_1 <= 1'b0;
            result_stage_2 <= 64'b0;
            result_stage_3 <= 64'b0;
            result_stage_4 <= 64'b0;
            flags_stage_2 <= 4'b0;
            flags_stage_3 <= 4'b0;
            flags_stage_4 <= 4'b0;
            valid_stage_2 <= 1'b0;
            valid_stage_3 <= 1'b0;
            valid_stage_4 <= 1'b0;
        end else begin
            valid_stage_1 <= valid_in;

            if (valid_in) begin
                operand_a_stage_1 <= op1;
                operand_b_stage_1 <= op2;
                format_stage_1 <= format;
                round_mode_stage_1 <= round_mode;
            end

            valid_stage_2 <= valid_stage_1;

            if (valid_stage_1) begin
                result_stage_2 <= selected_result;
                flags_stage_2 <= selected_flags;
            end

            valid_stage_3 <= valid_stage_2;

            if (valid_stage_2) begin
                result_stage_3 <= result_stage_2;
                flags_stage_3 <= flags_stage_2;
            end

            valid_stage_4 <= valid_stage_3;

            if (valid_stage_3) begin
                result_stage_4 <= result_stage_3;
                flags_stage_4 <= flags_stage_3;
            end
        end
    end

    assign ready_in = !rst;
    assign valid_out = valid_stage_4;
    assign result = result_stage_4;
    assign invalid = flags_stage_4[3];
    assign overflow = flags_stage_4[2];
    assign underflow = flags_stage_4[1];
    assign inexact = flags_stage_4[0];

endmodule


// Комбинационная часть умножителя одного параметризуемого формата.
module fp_mul_datapath #(
    parameter EXP_W  = 8,
    parameter MANT_W = 23
)(
    input  wire [EXP_W+MANT_W:0] op_a,
    input  wire [EXP_W+MANT_W:0] op_b,
    input  wire [EXP_W+MANT_W:0] op_c,
    input  wire [1:0]            round_mode,
    output reg  [EXP_W+MANT_W:0] result,
    output reg  [3:0]            flags
);

    localparam WIDTH = EXP_W + MANT_W + 1;
    localparam BIAS = (1 << (EXP_W-1)) - 1;
    localparam EMIN = 1 - BIAS;
    localparam EMAX = BIAS;
    localparam SUM_WIDTH = 2 * MANT_W + 4;

    wire sign_a;
    wire sign_b;
    wire sign_c;
    wire [EXP_W-1:0] exponent_a;
    wire [EXP_W-1:0] exponent_b;
    wire [EXP_W-1:0] exponent_c;
    wire [MANT_W-1:0] mantissa_a;
    wire [MANT_W-1:0] mantissa_b;
    wire [MANT_W-1:0] mantissa_c;

    operand_analyzer #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) analyzer_a (
        .operand(op_a),
        .is_zero(),
        .is_normalized(),
        .is_denormalized(),
        .is_infinity(),
        .is_nan(),
        .is_snan(),
        .is_qnan(),
        .sign(sign_a),
        .exponent(exponent_a),
        .mantissa(mantissa_a)
    );

    operand_analyzer #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) analyzer_b (
        .operand(op_b),
        .is_zero(),
        .is_normalized(),
        .is_denormalized(),
        .is_infinity(),
        .is_nan(),
        .is_snan(),
        .is_qnan(),
        .sign(sign_b),
        .exponent(exponent_b),
        .mantissa(mantissa_b)
    );

    operand_analyzer #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) analyzer_c (
        .operand(op_c),
        .is_zero(),
        .is_normalized(),
        .is_denormalized(),
        .is_infinity(),
        .is_nan(),
        .is_snan(),
        .is_qnan(),
        .sign(sign_c),
        .exponent(exponent_c),
        .mantissa(mantissa_c)
    );

    wire [4:0] special_case;
    wire has_special_case;
    wire invalid_special;
    wire [WIDTH-1:0] special_result;

    operation_analyzer #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) operation_analysis (
        .op_a(op_a),
        .op_b(op_b),
        .op_c(op_c),
        .special_case(special_case)
    );

    pre_res #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) special_result_builder (
        .op_a(op_a),
        .op_b(op_b),
        .op_c(op_c),
        .special_case(special_case),
        .has_special_case(has_special_case),
        .invalid_flag(invalid_special),
        .result(special_result)
    );

    wire [MANT_W:0] extended_mantissa_a;
    wire [MANT_W:0] extended_mantissa_b;
    wire [MANT_W:0] extended_mantissa_c;
    wire [2*MANT_W+1:0] mantissa_product;

    assign extended_mantissa_a = (exponent_a == 0) ?
                                 {1'b0, mantissa_a} :
                                 {1'b1, mantissa_a};

    assign extended_mantissa_b = (exponent_b == 0) ?
                                 {1'b0, mantissa_b} :
                                 {1'b1, mantissa_b};

    assign extended_mantissa_c = (exponent_c == 0) ?
                                 {1'b0, mantissa_c} :
                                 {1'b1, mantissa_c};

    assign mantissa_product = extended_mantissa_a *
                              extended_mantissa_b;

    integer exponent_a_unbiased;
    integer exponent_b_unbiased;
    integer exponent_c_unbiased;
    integer product_exponent;
    integer common_exponent;
    integer product_shift;
    integer operand_c_shift;
    integer index;

    reg [SUM_WIDTH-1:0] product_aligned;
    reg [SUM_WIDTH-1:0] operand_c_aligned;
    reg product_sticky;
    reg operand_c_sticky;
    reg signed [SUM_WIDTH:0] product_signed;
    reg signed [SUM_WIDTH:0] operand_c_signed;
    reg signed [SUM_WIDTH:0] sum_signed;
    reg [SUM_WIDTH-1:0] sum_magnitude;
    reg sum_sign;

    always @* begin
        exponent_a_unbiased = (exponent_a == 0) ?
                              EMIN : exponent_a - BIAS;

        exponent_b_unbiased = (exponent_b == 0) ?
                              EMIN : exponent_b - BIAS;

        exponent_c_unbiased = (exponent_c == 0) ?
                              EMIN : exponent_c - BIAS;

        product_exponent = exponent_a_unbiased +
                           exponent_b_unbiased;

        common_exponent = (product_exponent >= exponent_c_unbiased) ?
                          product_exponent :
                          exponent_c_unbiased;

        product_shift = common_exponent - product_exponent;
        operand_c_shift = common_exponent - exponent_c_unbiased;

        product_aligned = {{(SUM_WIDTH-(2*MANT_W+2)){1'b0}},
                           mantissa_product};

        operand_c_aligned = {{(SUM_WIDTH-(2*MANT_W+1)){1'b0}},
                             extended_mantissa_c,
                             {MANT_W{1'b0}}};

        product_sticky = 1'b0;
        operand_c_sticky = 1'b0;

        if (product_shift >= SUM_WIDTH) begin
            product_sticky = |product_aligned;
            product_aligned = {SUM_WIDTH{1'b0}};
        end else if (product_shift > 0) begin
            for (index = 0; index < SUM_WIDTH; index = index + 1) begin
                if (index < product_shift) begin
                    product_sticky = product_sticky |
                                     product_aligned[index];
                end
            end

            product_aligned = product_aligned >> product_shift;
        end

        if (operand_c_shift >= SUM_WIDTH) begin
            operand_c_sticky = |operand_c_aligned;
            operand_c_aligned = {SUM_WIDTH{1'b0}};
        end else if (operand_c_shift > 0) begin
            for (index = 0; index < SUM_WIDTH; index = index + 1) begin
                if (index < operand_c_shift) begin
                    operand_c_sticky = operand_c_sticky |
                                       operand_c_aligned[index];
                end
            end

            operand_c_aligned = operand_c_aligned >> operand_c_shift;
        end

        product_aligned[0] = product_aligned[0] |
                             product_sticky;

        operand_c_aligned[0] = operand_c_aligned[0] |
                               operand_c_sticky;

        product_signed = $signed({1'b0, product_aligned});
        operand_c_signed = $signed({1'b0, operand_c_aligned});

        if (sign_a ^ sign_b) begin
            product_signed = -product_signed;
        end

        if (sign_c) begin
            operand_c_signed = -operand_c_signed;
        end

        sum_signed = product_signed + operand_c_signed;
        sum_sign = (sum_signed < 0);

        if (sum_sign) begin
            sum_magnitude = -sum_signed;
        end else begin
            sum_magnitude = sum_signed;
        end
    end

    wire signed [15:0] exponent_unbiased;
    wire signed [15:0] rounding_shift;
    wire signed [15:0] common_exponent_short;

    assign common_exponent_short = common_exponent;

    exp_corr #(
        .EXP_W(EXP_W),
        .MANT_W(MANT_W)
    ) exponent_corrector (
        .base_exponent(common_exponent_short),
        .aligned_sum(sum_magnitude),
        .exponent_unbiased(exponent_unbiased),
        .rounding_shift(rounding_shift)
    );

    wire [MANT_W+1:0] rounded_value;
    wire rounding_inexact;

    rounding_module #(
        .MANT_W(MANT_W)
    ) rounder (
        .round_mode(round_mode),
        .sign_bit(sum_sign),
        .input_value(sum_magnitude),
        .shift_value(rounding_shift),
        .rounded_value(rounded_value),
        .inexact_flag(rounding_inexact)
    );

    integer final_exponent;
    reg [MANT_W+1:0] normalized_rounded_value;
    reg [EXP_W-1:0] final_exponent_field;

    always @* begin
        result = {WIDTH{1'b0}};
        flags = 4'b0000;
        final_exponent = exponent_unbiased;
        normalized_rounded_value = rounded_value;
        final_exponent_field = {EXP_W{1'b0}};

        if (has_special_case) begin
            result = special_result;
            flags[3] = invalid_special;
        end else if (sum_magnitude == 0) begin
            result = {
                (round_mode == 2'b10),
                {EXP_W{1'b0}},
                {MANT_W{1'b0}}
            };
        end else if (exponent_unbiased < EMIN) begin
            if (rounded_value[MANT_W]) begin
                result = {
                    sum_sign,
                    {{(EXP_W-1){1'b0}}, 1'b1},
                    {MANT_W{1'b0}}
                };
            end else begin
                result = {
                    sum_sign,
                    {EXP_W{1'b0}},
                    rounded_value[MANT_W-1:0]
                };
            end

            flags[1] = rounding_inexact &&
                       (result[WIDTH-2:MANT_W] == 0);

            flags[0] = rounding_inexact;
        end else begin
            if (rounded_value[MANT_W+1]) begin
                normalized_rounded_value = rounded_value >> 1;
                final_exponent = exponent_unbiased + 1;
            end

            if (final_exponent > EMAX) begin
                flags[2] = 1'b1;
                flags[0] = 1'b1;

                if ((round_mode == 2'b00) ||
                    ((round_mode == 2'b01) && sum_sign) ||
                    ((round_mode == 2'b10) && !sum_sign)) begin
                    result = {
                        sum_sign,
                        {{(EXP_W-1){1'b1}}, 1'b0},
                        {MANT_W{1'b1}}
                    };
                end else begin
                    result = {
                        sum_sign,
                        {EXP_W{1'b1}},
                        {MANT_W{1'b0}}
                    };
                end
            end else begin
                final_exponent_field = final_exponent + BIAS;

                result = {
                    sum_sign,
                    final_exponent_field,
                    normalized_rounded_value[MANT_W-1:0]
                };

                flags[0] = rounding_inexact;
            end
        end
    end

endmodule
