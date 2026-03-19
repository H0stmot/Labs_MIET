module CYBERcobra (
  input  logic         clk_i,
  input  logic         rst_i,
  input  logic [15:0]  sw_i,
  output logic [31:0]  out_o
);
  
  reg [31:0] PC; // Счетчик инструкций (их адрес в памяти инструкций)
  
  
  wire [31:0] instruction; // Сама инструкция, считанная по адресу
  
  // Подключение памяти инструкций
  instr_mem inst_mem (
    .read_addr_i(PC), 
    .read_data_o(instruction)
  );
 
  wire B            = instruction[30]; // бит условного перехода
  wire J            = instruction[31]; // бит безусловного перехода
  wire WE           = ~(B | J);        // сигнал разрешения записи в регистровый файл
  
  wire [1:0]  WS    = instruction[29:28]; // биты управления откуда подтягиваются данные
                                          // WS == 0: загрузка константы
                                          // WS == 1: загрузка результата АЛУ
                                          // WS == 2: загрузка данных с внешних устройств
  wire [4:0]  ALUop = instruction[27:23]; // коды операций на АЛУ
  wire [4:0]  RA1   = instruction[22:18]; // первый адрес чтения из регистрового файла
  wire [4:0]  RA2   = instruction[17:13]; // второй адрес чтения из регистрового файла
  
  wire [31:0] offset_cost = {{22{instruction[12]}}, instruction[12:5], 2'b0}; // 32-битная знакорасширенная константа смещения для условного/безусловного перехода
  
  wire [31:0] constant    = {{9{instruction[27]}}, instruction[27:5]}; // 32-битная знакорасширенная константа для загрузки в регистровый файл
  
  wire [4:0]  WA          = instruction[4:0]; // адрес регистра для записи
  
  wire [31:0] RD1, RD2;
  wire [31:0] alu_result;
  wire flag;
  
  reg [31:0] write_data;
  
  always_comb begin
    case (WS)
      2'b00:   write_data = constant;      // запись константы
      2'b01:   write_data = alu_result;    // запись результата АЛУ
      2'b10:   write_data = {16'b0, sw_i}; // запись с внешних устройств 
      default: write_data = 32'b0;         // дефолтное значение
    endcase
  end
  
  // Регистровый файл
  register_file reg_file (
    .clk_i(clk_i),
    .write_enable_i(WE),
    .write_addr_i(WA),
    .read_addr1_i(RA1),
    .read_addr2_i(RA2),
    .write_data_i(write_data),  
    .read_data1_o(RD1),
    .read_data2_o(RD2)
  );
  
  // АЛУ для вычислений
  alu alu_compute (
    .a_i(RD1),
    .b_i(RD2),
    .alu_op_i(ALUop),
    .result_o(alu_result),
    .flag_o(flag)
  );
  
  // Логика обновления счетчика команд PC
  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      PC <= 32'b0;
    end else begin
      if ((B && flag) || J) begin
        PC <= PC + offset_cost;  // переход
      end else begin
        PC <= PC + 32'd4;        // последовательное выполнение
      end
    end
  end
  
  assign out_o = RD1; // Значение на выходе out_o определяется содержимым ячейки памяти по адресу RA1
  
endmodule
