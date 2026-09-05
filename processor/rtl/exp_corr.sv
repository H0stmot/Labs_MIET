// Модуль вычисления порядка и сдвига результата FMA.
// На вход поступает модуль уже выровненной суммы A * B + C.
module exp_corr #(
    parameter EXP_W  = 8,
    parameter MANT_W = 23
)(
    input  wire signed [15:0]   base_exponent,
    input  wire [2*MANT_W+3:0] aligned_sum,
    output reg  signed [15:0]   exponent_unbiased,
    output reg  signed [15:0]   rounding_shift
);

    localparam BIAS = (1 << (EXP_W-1)) - 1;
    localparam EMIN = 1 - BIAS;
    localparam SUM_WIDTH = 2 * MANT_W + 4;

    integer leading_bit;
    integer index;

    always @* begin
        leading_bit = 0;

        for (index = 0; index < SUM_WIDTH; index = index + 1) begin
            if (aligned_sum[index]) begin
                leading_bit = index;
            end
        end

        exponent_unbiased = base_exponent +
                            leading_bit -
                            2 * MANT_W;

        if (exponent_unbiased >= EMIN) begin
            rounding_shift = leading_bit - MANT_W;
        end else begin
            rounding_shift = EMIN +
                             MANT_W -
                             base_exponent;
        end
    end

endmodule
