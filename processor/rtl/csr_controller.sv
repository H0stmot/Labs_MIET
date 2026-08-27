module csr_controller(
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        trap_i,

  input  logic [ 2:0] opcode_i,

  input  logic [11:0] addr_i,
  input  logic [31:0] pc_i,
  input  logic [31:0] mcause_i,
  input  logic [31:0] rs1_data_i,
  input  logic [31:0] imm_data_i,
  input  logic        write_enable_i,

  output logic [31:0] read_data_o,
  output logic [31:0] mie_o,
  output logic [31:0] mepc_o,
  output logic [31:0] mtvec_o
);

  import csr_pkg::*;

  logic [31:0] operation;
  logic [31:0] mscratch_reg; 
  logic [31:0] mcause_reg;  

  always_comb begin
    case(addr_i)
      12'h304: read_data_o = mie_o;
      12'h305: read_data_o = mtvec_o;
      12'h340: read_data_o = mscratch_reg;
      12'h341: read_data_o = mepc_o;
      12'h342: read_data_o = mcause_reg;
      default: read_data_o = '0;
    endcase
  end

  // мультиплексор выбора операции
  always_comb begin
    case(opcode_i)
      3'b001: operation = rs1_data_i;
      3'b010: operation = rs1_data_i | read_data_o;
      3'b011: operation = ~rs1_data_i & read_data_o;
      3'b101: operation = imm_data_i;
      3'b110: operation = imm_data_i | read_data_o;
      3'b111: operation = ~imm_data_i & read_data_o;
      default: operation = '0;
    endcase
  end

  // демультиплексор сигналов разрешения записи 
  logic we_mie, we_mtvec, we_mscratch, we_mepc, we_mcause;

  always_comb begin
    we_mie      = write_enable_i & (addr_i == 12'h304);
    we_mtvec    = write_enable_i & (addr_i == 12'h305);
    we_mscratch = write_enable_i & (addr_i == 12'h340);
    we_mepc     = (write_enable_i & (addr_i == 12'h341)) | trap_i;
    we_mcause   = (write_enable_i & (addr_i == 12'h342)) | trap_i;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin 
      mie_o        <= '0;
      mtvec_o      <= '0;
      mscratch_reg <= '0;
      mepc_o       <= '0;
      mcause_reg   <= '0;
    end else begin
      if (we_mie)      mie_o        <= operation;
      if (we_mtvec)    mtvec_o      <= operation;
      if (we_mscratch) mscratch_reg <= operation;
      if (we_mepc)     mepc_o       <= trap_i ? pc_i     : operation;
      if (we_mcause)   mcause_reg   <= trap_i ? mcause_i : operation;
    end
  end

endmodule