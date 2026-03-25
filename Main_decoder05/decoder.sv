module decoder (
  input  logic [31:0]  fetched_instr_i,
  output logic [1:0]   a_sel_o,
  output logic [2:0]   b_sel_o,
  output logic [4:0]   alu_op_o,
  output logic [2:0]   csr_op_o,
  output logic         csr_we_o,
  output logic         mem_req_o,
  output logic         mem_we_o,
  output logic [2:0]   mem_size_o,
  output logic         gpr_we_o,
  output logic [1:0]   wb_sel_o,
  output logic         illegal_instr_o,
  output logic         branch_o,
  output logic         jal_o,
  output logic         jalr_o,
  output logic         mret_o
);

  import decoder_pkg::*;

  // Выделяем поля из инструкции
  wire [6:0] opcode = fetched_instr_i[6:0];
  wire [2:0] func3  = fetched_instr_i[14:12];
  wire [6:0] func7  = fetched_instr_i[31:25];

  always_comb begin
    a_sel_o         = OP_A_RS1;       // По умолчанию первый операнд - регистр rs1
    b_sel_o         = OP_B_RS2;       // По умолчанию второй операнд - регистр rs2
    alu_op_o        = ALU_ADD;        // Базовая операция АЛУ - сложение
    csr_op_o        = 3'b000;
    csr_we_o        = 1'b0;           // Запись в CSR запрещена
    mem_req_o       = 1'b0;           // Обращение к памяти отключено
    mem_we_o        = 1'b0;           // Запись в память запрещена
    mem_size_o      = LDST_W;         // По умолчанию размер слова
    gpr_we_o        = 1'b0;           // Запись в РОН (GPR) запрещена
    wb_sel_o        = WB_EX_RESULT;   // По умолчанию пишем результат из АЛУ
    illegal_instr_o = 1'b0;           // Инструкция считается корректной
    branch_o        = 1'b0;           // Условный переход отключен
    jal_o           = 1'b0;           // Безусловный JAL отключен
    jalr_o          = 1'b0;           // Безусловный JALR отключен
    mret_o          = 1'b0;           // Возврат из прерывания отключен



    if (opcode[1:0] != 2'b11) begin // если младшие 2 бита не 11, то выставляем сигнал в 1
      illegal_instr_o = 1'b1;
    end else begin
      
      case (opcode[6:2]) // Анализируем 5 старших бит опкода
        // U: LUI 
        LUI_OPCODE: begin
          a_sel_o  = OP_A_ZERO;       // 0
          b_sel_o  = OP_B_IMM_U;      // imm << 12
          gpr_we_o = 1'b1;            // rd = 0 + (imm << 12)
        end

        // U: AUIPC
        AUIPC_OPCODE: begin
          a_sel_o  = OP_A_CURR_PC;    // PC
          b_sel_o  = OP_B_IMM_U;      // imm << 12
          gpr_we_o = 1'b1;            // rd = PC + (imm << 12)
        end

        // J: JAL
        JAL_OPCODE: begin
          jal_o    = 1'b1;
          gpr_we_o = 1'b1;            // Нужно сохранить адрес возврата
          a_sel_o  = OP_A_CURR_PC;
          b_sel_o  = OP_B_INCR;       // +4 для адреса возврата
        end

        // I: JALR
        JALR_OPCODE: begin
          if (func3 == 3'b000) begin
            jalr_o   = 1'b1;
            gpr_we_o = 1'b1;          // Нужно сохранить адрес возврата
            a_sel_o  = OP_A_CURR_PC;
            b_sel_o  = OP_B_INCR;
          end else begin
            illegal_instr_o = 1'b1;
          end
        end

        // B: условные переходы
        BRANCH_OPCODE: begin
          branch_o = 1'b1;
          case (func3)
            3'b000: alu_op_o = ALU_EQ;   // BEQ
            3'b001: alu_op_o = ALU_NE;   // BNE
            3'b100: alu_op_o = ALU_LTS;  // BLT
            3'b101: alu_op_o = ALU_GES;  // BGE
            3'b110: alu_op_o = ALU_LTU;  // BLTU
            3'b111: alu_op_o = ALU_GEU;  // BGEU
            default: illegal_instr_o = 1'b1;
          endcase
        end

        // I: чтение из памяти
        LOAD_OPCODE: begin
          mem_req_o = 1'b1;
          gpr_we_o  = 1'b1;
          wb_sel_o  = WB_LSU_DATA;   // Результат берем из LSU
          b_sel_o   = OP_B_IMM_I;    // Для вычисления адреса rs1 + imm
          case (func3)
            3'b000: mem_size_o = LDST_B;
            3'b001: mem_size_o = LDST_H;
            3'b010: mem_size_o = LDST_W;
            3'b100: mem_size_o = LDST_BU;
            3'b101: mem_size_o = LDST_HU;
            default: illegal_instr_o = 1'b1;
          endcase
        end

        // S: запись в память
        STORE_OPCODE: begin
          mem_req_o = 1'b1;
          mem_we_o  = 1'b1;          // Разрешаем запись в память
          b_sel_o   = OP_B_IMM_S;    // Для вычисления адреса rs1 + imm_s
          case (func3)
            3'b000: mem_size_o = LDST_B;
            3'b001: mem_size_o = LDST_H;
            3'b010: mem_size_o = LDST_W;
            default: illegal_instr_o = 1'b1;
          endcase
        end

        // I: АЛУ операции с константой
        OP_IMM_OPCODE: begin
          gpr_we_o = 1'b1;
          b_sel_o  = OP_B_IMM_I;
          case (func3)
            3'b000: alu_op_o = ALU_ADD;   // ADDI
            3'b010: alu_op_o = ALU_SLTS;  // SLTI
            3'b011: alu_op_o = ALU_SLTU;  // SLTIU
            3'b100: alu_op_o = ALU_XOR;   // XORI
            3'b110: alu_op_o = ALU_OR;    // ORI
            3'b111: alu_op_o = ALU_AND;   // ANDI
            3'b001: begin                 // SLLI
              if (func7 == 7'b0000000) alu_op_o = ALU_SLL;
              else illegal_instr_o = 1'b1;
            end
            3'b101: begin                 
              if      (func7 == 7'b0000000) alu_op_o = ALU_SRL; // SRLI
              else if (func7 == 7'b0100000) alu_op_o = ALU_SRA; // SRAI
              else illegal_instr_o = 1'b1;
            end
            default: illegal_instr_o = 1'b1;
          endcase
        end

        // R: АЛУ операции с регистрами
        OP_OPCODE: begin
          gpr_we_o = 1'b1;
          case (func3)
            3'b000: begin
              if      (func7 == 7'b0000000) alu_op_o = ALU_ADD; // ADD
              else if (func7 == 7'b0100000) alu_op_o = ALU_SUB; // SUB
              else illegal_instr_o = 1'b1;
            end
            3'b001: begin
              if (func7 == 7'b0000000) alu_op_o = ALU_SLL; else illegal_instr_o = 1'b1;
            end
            3'b010: begin
              if (func7 == 7'b0000000) alu_op_o = ALU_SLTS; else illegal_instr_o = 1'b1;
            end
            3'b011: begin
              if (func7 == 7'b0000000) alu_op_o = ALU_SLTU; else illegal_instr_o = 1'b1;
            end
            3'b100: begin
              if (func7 == 7'b0000000) alu_op_o = ALU_XOR; else illegal_instr_o = 1'b1;
            end
            3'b101: begin
              if      (func7 == 7'b0000000) alu_op_o = ALU_SRL; // SRL
              else if (func7 == 7'b0100000) alu_op_o = ALU_SRA; // SRA
              else illegal_instr_o = 1'b1;
            end
            3'b110: begin
              if (func7 == 7'b0000000) alu_op_o = ALU_OR; else illegal_instr_o = 1'b1;
            end
            3'b111: begin
              if (func7 == 7'b0000000) alu_op_o = ALU_AND; else illegal_instr_o = 1'b1;
            end
          endcase
        end

        // SYSTEM: ecall, ebreak, mret, CSR
        SYSTEM_OPCODE: begin
          case (func3)
            3'b000: begin // ecall, ebreak, mret
              if (fetched_instr_i[31:20] == 12'b001100000010) begin
                mret_o = 1'b1; // MRET
              end else if (fetched_instr_i[31:20] == 12'b000000000000) begin
                illegal_instr_o = 1'b1; // ECALL
              end else if (fetched_instr_i[31:20] == 12'b000000000001) begin
                illegal_instr_o = 1'b1; // EBREAK
              end else begin
                illegal_instr_o = 1'b1;
              end
            end
            // Ограничения: CSR инструкции не должны иметь func3 == 100
            3'b100: illegal_instr_o = 1'b1;
            
            default: begin
              csr_we_o = 1'b1;
              gpr_we_o = 1'b1;
              wb_sel_o = WB_CSR_DATA;
              csr_op_o = func3;
            end
          endcase
        end

        MISC_MEM_OPCODE: begin
          if (func3 != 3'b000) illegal_instr_o = 1'b1;
        end

        default: illegal_instr_o = 1'b1; // Неизвестный опкод
      endcase
    end


    // защита при некоректных инструкиях
    if (illegal_instr_o) begin
      branch_o  = 1'b0;
      jal_o     = 1'b0;
      jalr_o    = 1'b0;
      mem_req_o = 1'b0;
      mem_we_o  = 1'b0;
      gpr_we_o  = 1'b0;
      csr_we_o  = 1'b0;
      mret_o    = 1'b0;
    end
  end

endmodule
