module data_mem
import memory_pkg::DATA_MEM_SIZE_BYTES;
import memory_pkg::DATA_MEM_SIZE_WORDS;
(
  input  logic        clk_i,
  input  logic        mem_req_i,
  input  logic        write_enable_i,
  input  logic [ 3:0] byte_enable_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] write_data_i,
  output logic [31:0] read_data_o,
  output logic        ready_o
);

    logic [31:0] ram [0:DATA_MEM_SIZE_WORDS-1]; // основная память
    wire [31:0] word_addr;          // Перед тем как обратиться к ячейке памяти, 
    assign word_addr = addr_i >> 2; // значение с addr_i необходимо преобразовать (делить на 4)
    
    always @(posedge clk_i) begin
        if (mem_req_i) begin 
            if (write_enable_i) begin
                case (byte_enable_i) // записываем только в те байты указанной ячейки, 
                                     // которым соответствуют биты сигнала byte_enable_i, равные 1
                    4'b0000 : ; 
                    4'b0001 : ram[word_addr][7:0]  <= write_data_i[7:0];
                    4'b0010 : ram[word_addr][15:8] <= write_data_i[15:8];
                    4'b0011 : ram[word_addr][15:0] <= write_data_i[15:0];                 
                    4'b0100 : ram[word_addr][23:16] <= write_data_i[23:16];
                    4'b0101 : begin
                                ram[word_addr][23:16] <= write_data_i[23:16];
                                ram[word_addr][7:0]   <= write_data_i[7:0];
                              end
                    4'b0110 : begin
                                ram[word_addr][23:16] <= write_data_i[23:16];
                                ram[word_addr][15:8]  <= write_data_i[15:8];
                              end
                    4'b0111 : ram[word_addr][23:0] <= write_data_i[23:0];
                    4'b1000 : ram[word_addr][31:24] <= write_data_i[31:24];
                    4'b1001 : begin
                                ram[word_addr][31:24] <= write_data_i[31:24];
                                ram[word_addr][7:0]   <= write_data_i[7:0];
                              end
                    4'b1010 : begin
                                ram[word_addr][31:24] <= write_data_i[31:24];
                                ram[word_addr][15:8]  <= write_data_i[15:8];
                              end
                    4'b1011 : begin
                                ram[word_addr][31:24] <= write_data_i[31:24];
                                ram[word_addr][15:0]  <= write_data_i[15:0];
                              end                                         
                    4'b1100 : begin
                                ram[word_addr][31:24] <= write_data_i[31:24];
                                ram[word_addr][23:16] <= write_data_i[23:16];
                              end
                    4'b1101 : begin
                                ram[word_addr][31:24] <= write_data_i[31:24];
                                ram[word_addr][23:16] <= write_data_i[23:16];
                                ram[word_addr][7:0]   <= write_data_i[7:0];
                              end
                    4'b1110 : begin
                                ram[word_addr][31:24] <= write_data_i[31:24];
                                ram[word_addr][23:16] <= write_data_i[23:16];
                                ram[word_addr][15:8]  <= write_data_i[15:8];
                              end
                    4'b1111 : ram[word_addr] <= write_data_i; 
                endcase
            end else begin
                read_data_o <= ram[word_addr];
            end
        end
    end
    
    // У памяти есть дополнительный выход ready_o, который всегда равен единице
    assign ready_o = 1'b1;

endmodule
