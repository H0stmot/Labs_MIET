module instr_mem #(
  parameter INIT_FILE  = "programs/program.mem",
  parameter INIT_WORDS = 6
)
(
  input  logic [31:0] read_addr_i,
  output logic [31:0] read_data_o
);

  import memory_pkg::INSTR_MEM_SIZE_BYTES;
  import memory_pkg::INSTR_MEM_SIZE_WORDS;

  logic [31:0] ROM [0:INSTR_MEM_SIZE_WORDS-1];  // создать память с
                                            // <INSTR_MEM_SIZE_WORDS>
                                            // 32-битных ячеек

  initial begin
    $readmemh(INIT_FILE, ROM, 0, INIT_WORDS-1); // загрузить используемые слова
  end                                       // файла program.mem

  // Реализация асинхронного порта на чтение, где на выход идёт ячейка памяти
  // инструкций, расположенная по адресу read_addr_i, в котором отброшены два
  // младших бита, а также биты, двоичный вес которых превышает размер памяти
  // данных в байтах.
  // Два младших бита отброшены, чтобы обеспечить выровненный доступ к памяти,
  // в то время как старшие биты отброшены, чтобы не дать обращаться в память
  // по адресам несуществующих ячеек (вместо этого будут выданы данные ячеек,
  // расположенных по младшим адресам).
  assign read_data_o = ROM[read_addr_i[$clog2(INSTR_MEM_SIZE_BYTES)-1:2]];

endmodule
