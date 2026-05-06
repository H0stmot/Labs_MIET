module processor_core (
  input  logic        clk_i,
  input  logic        rst_i,

  input  logic        stall_i,
  input  logic [31:0] instr_i,
  input  logic [31:0] mem_rd_i,
  input  logic        irq_req_i,    // Новый порт запроса прерывания

  output logic [31:0] instr_addr_o,
  output logic [31:0] mem_addr_o,
  output logic [ 2:0] mem_size_o,
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [31:0] mem_wd_o,
  output logic        irq_ret_o     // Новый порт возврата из прерывания
);

  import decoder_pkg::*; 

  logic [31:0] PC_reg;
  logic [31:0] PC_next;

  // Сигналы декодера
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

  // Оригинальные сигналы памяти 
  logic        dec_mem_req;
  logic        dec_mem_we;

  // Сигналы подсистемы прерываний и CSR
  logic        irq;
  logic        trap;
  logic [31:0] csr_wd;
  logic [31:0] mie;
  logic [31:0] mepc;
  logic [31:0] mtvec;
  logic [31:0] irq_cause;
  logic [31:0] mcause_mux;

  // Сигналы регистрового файла
  logic [31:0] RD1;
  logic [31:0] RD2;
  logic [31:0] wb_data;
  logic        rf_we;   

  // Сигналы АЛУ
  logic [31:0] alu_a;
  logic [31:0] alu_b;
  logic [31:0] alu_result;
  logic        alu_flag;

  // Константы
  logic [31:0] imm_I;
  logic [31:0] imm_U;
  logic [31:0] imm_S;
  logic [31:0] imm_B;
  logic [31:0] imm_J;
  logic [31:0] imm_Z; // Добавлена новая константа

  assign imm_I = { {20{instr_i[31]}}, instr_i[31:20] };
  assign imm_U = { instr_i[31:12], 12'h000 };
  assign imm_S = { {20{instr_i[31]}}, instr_i[31:25], instr_i[11:7] };
  assign imm_B = { {19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0 };
  assign imm_J = { {11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0 };
  
  // imm_Z расширяется нулями, а не знаковым битом
  assign imm_Z = { 27'b0, instr_i[19:15] };

  // Логика исключений
  assign trap = irq | illegal_instr;
  assign mcause_mux = illegal_instr ? 32'h0000_0002 : irq_cause;

  // Маскирование запросов к памяти при исключениях
  assign mem_req_o = dec_mem_req & ~trap;
  assign mem_we_o  = dec_mem_we  & ~trap;

  decoder main_decoder (
    .fetched_instr_i (instr_i),
    .a_sel_o         (a_sel),
    .b_sel_o         (b_sel),
    .alu_op_o        (alu_op),
    .csr_op_o        (csr_op),         
    .csr_we_o        (csr_we),       
    .mem_req_o       (dec_mem_req),      
    .mem_we_o        (dec_mem_we),      
    .mem_size_o      (mem_size_o),     
    .gpr_we_o        (gpr_we),
    .wb_sel_o        (wb_sel),
    .illegal_instr_o (illegal_instr),  
    .branch_o        (branch),
    .jal_o           (jal),
    .jalr_o          (jalr),
    .mret_o          (mret)            
  );

  // Запись в регистровый файл блокируется при stall или trap
  assign rf_we = gpr_we & (~stall_i) & (~trap); 

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

  // Выбор операнда a 
  always_comb begin
    case (a_sel)
      OP_A_RS1:     alu_a = RD1;      
      OP_A_CURR_PC: alu_a = PC_reg;   
      OP_A_ZERO:    alu_a = 32'b0;    
      default:      alu_a = 32'b0;
    endcase
  end

  // Выбор операнда b
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

  // Мультиплексор записи
  always_comb begin
    case (wb_sel)
      WB_EX_RESULT: wb_data = alu_result; 
      WB_LSU_DATA:  wb_data = mem_rd_i;   
      2'b10:        wb_data = csr_wd;     // Вывод данных из CSR (значение 2)
      default:      wb_data = alu_result;
    endcase
  end

  logic [31:0] pc_adder_mux1;
  logic [31:0] pc_adder_mux2;
  logic [31:0] pc_adder_res;
  logic [31:0] jalr_target;
  logic [31:0] sum;
  logic [31:0] pc_mret;

  // Логика следующего адреса PC
  assign pc_adder_mux1 = jal ? imm_J : imm_B;
  assign pc_adder_mux2 = ((branch & alu_flag) | jal) ? pc_adder_mux1 : 32'd4;
  assign pc_adder_res  = PC_reg + pc_adder_mux2;
  
  assign sum = RD1 + imm_I;
  assign jalr_target = { sum[31:1], 1'b0 };
  
  // Добавлены мультиплексоры для обработки прерываний trap и возврата mret
  assign pc_mret = mret ? mepc : (jalr ? jalr_target : pc_adder_res);
  assign PC_next = trap ? mtvec : pc_mret;

  // Логика обновления PC
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      PC_reg <= 32'b0;          
    end else if (!stall_i | trap | mret) begin // PC также должен обновиться при trap/mret
      PC_reg <= PC_next;       
    end
  end

  assign instr_addr_o = PC_reg;

  // Интеграция контроллера прерываний
  interrupt_controller irq_ctrl (
    .clk_i       (clk_i),
    .rst_i       (rst_i),
    .exception_i (illegal_instr),
    .irq_req_i   (irq_req_i),
    .mie_i       (mie[3]),       // MIE-бит
    .mret_i      (mret),
    .irq_ret_o   (irq_ret_o),
    .irq_cause_o (irq_cause),
    .irq_o       (irq)
  );

  // Интеграция регистров CSR
  csr_controller csr_ctrl (
    .clk_i          (clk_i),
    .rst_i          (rst_i),
    .trap_i         (trap),
    .opcode_i       (csr_op),
    .addr_i         (instr_i[31:20]),
    .pc_i           (PC_reg),
    .mcause_i       (mcause_mux),
    .rs1_data_i     (RD1),
    .imm_data_i     (imm_Z),
    .write_enable_i (csr_we),
    .read_data_o    (csr_wd),
    .mie_o          (mie),
    .mepc_o         (mepc),
    .mtvec_o        (mtvec)
  );

endmodule