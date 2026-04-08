module processor_core (
  input  logic        clk_i,
  input  logic        rst_i,

  input  logic        stall_i,
  input  logic [31:0] instr_i,
  input  logic [31:0] mem_rd_i,

  output logic [31:0] instr_addr_o,
  output logic [31:0] mem_addr_o,
  output logic [ 2:0] mem_size_o,
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [31:0] mem_wd_o
);

import decoder_pkg::*; 

  logic [31:0] PC_reg;
  logic [31:0] PC_next;

  // сигналы декодера
  logic [1:0]  a_sel;
  logic [2:0]  b_sel;
  logic [4:0]  alu_op;
  logic        gpr_we;
  logic [1:0]  wb_sel;
  logic        branch;
  logic        jal;
  logic        jalr;
  logic [2:0]  csr_op;
  logic        csr_we;
  logic        illegal_instr;
  logic        mret;

  // сигналы регистрового файла
  logic [31:0] RD1;
  logic [31:0] RD2;
  logic [31:0] wb_data;
  logic        rf_we;   

  // сигналы АЛУ
  logic [31:0] alu_a;
  logic [31:0] alu_b;
  logic [31:0] alu_result;
  logic        alu_flag;

  logic [31:0] imm_I;
  logic [31:0] imm_U;
  logic [31:0] imm_S;
  logic [31:0] imm_B;
  logic [31:0] imm_J;


  assign imm_I = { {20{instr_i[31]}}, instr_i[31:20] };
  assign imm_U = { instr_i[31:12], 12'h000 };
  assign imm_S = { {20{instr_i[31]}}, instr_i[31:25], instr_i[11:7] };
  assign imm_B = { {19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0 };
  assign imm_J = { {11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0 };


  decoder main_decoder (
    .fetched_instr_i (instr_i),
    .a_sel_o         (a_sel),
    .b_sel_o         (b_sel),
    .alu_op_o        (alu_op),
    .csr_op_o        (csr_op),         
    .csr_we_o        (csr_we),       
    .mem_req_o       (mem_req_o),      
    .mem_we_o        (mem_we_o),      
    .mem_size_o      (mem_size_o),     
    .gpr_we_o        (gpr_we),
    .wb_sel_o        (wb_sel),
    .illegal_instr_o (illegal_instr),  
    .branch_o        (branch),
    .jal_o           (jal),
    .jalr_o          (jalr),
    .mret_o          (mret)            
  );

  
  assign rf_we = gpr_we & (~stall_i); // запись в регистровый файл разрешена

  register_file reg_file (
    .clk_i          (clk_i),
    .write_enable_i (rf_we),
    .write_addr_i   (instr_i[11:7]),  // WA
    .read_addr1_i   (instr_i[19:15]), // RA1
    .read_addr2_i   (instr_i[24:20]), // RA2
    .write_data_i   (wb_data),        // WD
    .read_data1_o   (RD1),
    .read_data2_o   (RD2)
  );


  assign mem_wd_o = RD2;


  //выбор операнда a 
  always_comb begin
    case (a_sel)
      OP_A_RS1:     alu_a = RD1;      
      OP_A_CURR_PC: alu_a = PC_reg;   
      OP_A_ZERO:    alu_a = 32'b0;    
      default:      alu_a = 32'b0;
    endcase
  end

  //выбор операнда b
  always_comb begin
    case (b_sel)
      OP_B_RS2:   alu_b = RD2;        
      OP_B_IMM_I: alu_b = imm_I;      
      OP_B_IMM_U: alu_b = imm_U;      
      OP_B_IMM_S: alu_b = imm_S;      
      OP_B_INCR:  alu_b = 32'd4;      
      default:    alu_b = 32'b0;
    endcase
  end

  alu core_alu (
    .a_i      (alu_a),
    .b_i      (alu_b),
    .alu_op_i (alu_op),
    .flag_o   (alu_flag),
    .result_o (alu_result)
  );

  assign mem_addr_o = alu_result;


  // мультиплексор на выбор между результатом АЛУ и данными из памяти
  always_comb begin
    case (wb_sel)
      WB_EX_RESULT: wb_data = alu_result; 
      WB_LSU_DATA:  wb_data = mem_rd_i;   
      default:      wb_data = alu_result;
    endcase
  end


  logic [31:0] pc_adder_mux1;
  logic [31:0] pc_adder_mux2;
  logic [31:0] pc_adder_res;
  logic [31:0] jalr_target;

  // мультиплексоры для PC
  assign pc_adder_mux1 = jal ? imm_J : imm_B;
  assign pc_adder_mux2 = ((branch & alu_flag) | jal) ? pc_adder_mux1 : 32'd4;
  assign pc_adder_res = PC_reg + pc_adder_mux2;
  logic [31:0] sum;
  assign sum = RD1 + imm_I;
  assign jalr_target = { sum[31:1], 1'b0 };
  assign PC_next = jalr ? jalr_target : pc_adder_res;

  // логика обновления PC
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      PC_reg <= 32'b0;          
    end else if (!stall_i) begin
      PC_reg <= PC_next;       
    end
  end

  assign instr_addr_o = PC_reg;

endmodule
