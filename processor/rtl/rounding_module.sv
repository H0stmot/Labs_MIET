// Модуль округления произведения мантисс.
// Режимы: 00 - к нулю, 01 - к +inf, 10 - к -inf,
// 11 - к ближайшему четному числу.
module rounding_module #(
    parameter MANT_W = 23
)(
    input  wire [1:0]          round_mode,
    input  wire                sign_bit,
    input  wire [2*MANT_W+3:0] input_value,
    input  wire signed [15:0]  shift_value,
    output reg  [MANT_W+1:0]   rounded_value,
    output reg                 inexact_flag
);

    localparam PRODUCT_WIDTH = 2 * MANT_W + 4;

    reg [MANT_W:0] kept_value;
    reg guard_bit;
    reg sticky_bit;
    reg increment_needed;
    integer index;

    always @* begin
        kept_value = {MANT_W+1{1'b0}};
        guard_bit = 1'b0;
        sticky_bit = 1'b0;
        increment_needed = 1'b0;

        if (shift_value <= 0) begin
            kept_value = input_value << (-shift_value);
        end else if (shift_value >= PRODUCT_WIDTH) begin
            kept_value = {MANT_W+1{1'b0}};
            sticky_bit = |input_value;
        end else begin
            kept_value = input_value >> shift_value;
            guard_bit = input_value[shift_value-1];

            for (index = 0; index < PRODUCT_WIDTH; index = index + 1) begin
                if (index < shift_value-1) begin
                    sticky_bit = sticky_bit | input_value[index];
                end
            end
        end

        inexact_flag = guard_bit || sticky_bit;

        case (round_mode)
            2'b00: begin
                increment_needed = 1'b0;
            end
            2'b01: begin
                increment_needed = !sign_bit && inexact_flag;
            end
            2'b10: begin
                increment_needed = sign_bit && inexact_flag;
            end
            default: begin
                increment_needed = guard_bit &&
                                   (sticky_bit || kept_value[0]);
            end
        endcase

        rounded_value = {1'b0, kept_value} + increment_needed;
    end

endmodule
