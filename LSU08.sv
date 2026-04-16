
import decoder_pkg::*;

module lsu(
  input logic clk_i,
  input logic rst_i,

  // Интерфейс с ядром
  input  logic        core_req_i,
  input  logic        core_we_i,
  input  logic [ 2:0] core_size_i,
  input  logic [31:0] core_addr_i,
  input  logic [31:0] core_wd_i,
  output logic [31:0] core_rd_o,
  output logic        core_stall_o,

  // Интерфейс с памятью
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [ 3:0] mem_be_o,
  output logic [31:0] mem_addr_o,
  output logic [31:0] mem_wd_o,
  input  logic [31:0] mem_rd_i,
  input  logic        mem_ready_i
);

  assign mem_req_o = core_req_i;
  assign mem_we_o = core_we_i;
  assign mem_addr_o = core_addr_i;

  logic stall_reg;
  
  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      stall_reg <= 1'b0;
    end else begin
      stall_reg <= core_req_i & (~mem_ready_i | stall_reg);
    end
  end
  
  assign core_stall_o = stall_reg;
  
 
  logic [1:0] byte_offset;
  assign byte_offset = core_addr_i[1:0];
  

  always_comb begin
    case (core_size_i)
      LDST_B: begin  
        mem_be_o = 4'b0001 << byte_offset;
      end
      LDST_H: begin  
        if (byte_offset[1] == 1'b0)  
          mem_be_o = 4'b0011;
        else                         
          mem_be_o = 4'b1100;
      end
      LDST_W: begin  
        mem_be_o = 4'b1111;
      end
      default: mem_be_o = 4'b0000;
    endcase
  end
  

  always_comb begin
    case (core_size_i)
      LDST_B: begin
        mem_wd_o = {4{core_wd_i[7:0]}}; 
      end
      LDST_H: begin
        mem_wd_o = {2{core_wd_i[15:0]}}; 
      end
      LDST_W: begin
        mem_wd_o = core_wd_i;             
      end
      default: begin
        mem_wd_o = 32'b0;
      end
    endcase
  end
  

  logic [31:0] read_data;
  logic [31:0] extended_data;
  
  always_comb begin
    case (core_size_i)
      LDST_B: begin  
        case (byte_offset)
          2'b00: extended_data = { {24{mem_rd_i[7]}}, mem_rd_i[7:0] };
          2'b01: extended_data = { {24{mem_rd_i[15]}}, mem_rd_i[15:8] };
          2'b10: extended_data = { {24{mem_rd_i[23]}}, mem_rd_i[23:16] };
          2'b11: extended_data = { {24{mem_rd_i[31]}}, mem_rd_i[31:24] };
          default: extended_data = 32'b0;
        endcase
        read_data = extended_data;
      end
      
      LDST_BU: begin  
        case (byte_offset)
          2'b00: extended_data = { 24'b0, mem_rd_i[7:0] };
          2'b01: extended_data = { 24'b0, mem_rd_i[15:8] };
          2'b10: extended_data = { 24'b0, mem_rd_i[23:16] };
          2'b11: extended_data = { 24'b0, mem_rd_i[31:24] };
          default: extended_data = 32'b0;
        endcase
        read_data = extended_data;
      end
      
      LDST_H: begin  
        if (byte_offset[1] == 1'b0) begin 
          extended_data = { {16{mem_rd_i[15]}}, mem_rd_i[15:0] };
        end else begin  
          extended_data = { {16{mem_rd_i[31]}}, mem_rd_i[31:16] };
        end
        read_data = extended_data;
      end
      
      LDST_HU: begin  
        if (byte_offset[1] == 1'b0) begin  
          extended_data = { 16'b0, mem_rd_i[15:0] };
        end else begin  
          extended_data = { 16'b0, mem_rd_i[31:16] };
        end
        read_data = extended_data;
      end
      
      LDST_W: begin  
        read_data = mem_rd_i;
      end
      
      default: begin
        read_data = 32'b0;
      end
    endcase
  end
  
  assign core_rd_o = read_data;

endmodule
