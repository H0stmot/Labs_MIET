module register_file(
  input  logic        clk_i,
  input  logic        write_enable_i,

  input  logic [ 4:0] write_addr_i,
  input  logic [ 4:0] read_addr1_i,
  input  logic [ 4:0] read_addr2_i,

  input  logic [31:0] write_data_i,
  output logic [31:0] read_data1_o,
  output logic [31:0] read_data2_o
);
  
  logic [31:0] rf_mem [31:0]; // пам€ть регистрового файла

  always @(posedge clk_i) begin // запись в пам€ть по разрешаещему сигналу
    if (write_enable_i && (write_addr_i != 5'b0)) begin // реализаци€ 0 по нулевому адресу через условие на запись
        rf_mem[write_addr_i] <= write_data_i; // €чейка rf_mem[0] всегда остаетс€ равной 0
    end
  end
  assign read_data1_o = rf_mem[read_addr1_i]; // асинхронное чтение по первому адресу
  assign read_data2_o = rf_mem[read_addr2_i]; // асинхронное чтение по второму адресу
  
  // реализаци€ чтени€ 0 по нулевому адресу через мульиплексор
  /*always_comb begin // асинхронное чтение по первому адресу
    if (read_addr1_i)
        read_data1_o = rf_mem[read_addr1_i];
    else
        read_data1_o = '0; // по 0 адресу всегда выводитьс€ 0
  end
  
  always_comb begin // асинхронное чтение по первому адресу
    if (read_addr1_i)
        read_data2_o = rf_mem[read_addr2_i];
    else
        read_data2_o = '0;
  end*/
endmodule
