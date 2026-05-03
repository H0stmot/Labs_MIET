module interrupt_controller(
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        exception_i,
  input  logic        irq_req_i,
  input  logic        mie_i,
  input  logic        mret_i,

  output logic        irq_ret_o,
  output logic [31:0] irq_cause_o,
  output logic        irq_o
);

  logic exc_h_q;
  logic irq_h_q;

  assign irq_cause_o = 32'h8000_0010;
  assign irq_ret_o = mret_i & ~exc_h_q;
  assign irq_o = (irq_req_i & mie_i) & ~(exc_h_q | irq_h_q);


  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      exc_h_q <= 1'b0;
    end else begin
      if (mret_i) begin
        exc_h_q <= 1'b0;
      end else if (exception_i) begin
        exc_h_q <= 1'b1;
      end
    end
  end


  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      irq_h_q <= 1'b0;
    end else begin
      if (irq_ret_o) begin
        irq_h_q <= 1'b0;
      end else if (irq_o) begin
        irq_h_q <= 1'b1;
      end
    end
  end

endmodule