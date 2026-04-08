module processor_system(
  input  logic        clk_i,
  input  logic        rst_i
);

  logic [31:0] instr_addr;
  logic [31:0] instr;

  
  logic        mem_req;
  logic        mem_we;
  logic [2:0]  mem_size; 
  logic [31:0] mem_addr;
  logic [31:0] mem_wd;
  logic [31:0] mem_rd;


  logic stall;
  logic stall_next;

  assign stall_next = mem_req & (~stall);

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      stall <= 1'b0;
    end else begin
      stall <= stall_next;
    end
  end

  processor_core core (
    .clk_i        (clk_i),
    .rst_i        (rst_i),
    .stall_i      (stall),      
    .instr_addr_o (instr_addr), 
    .instr_i      (instr),      
    .mem_rd_i     (mem_rd),     
    .mem_addr_o   (mem_addr),   
    .mem_size_o   (mem_size),   
    .mem_req_o    (mem_req),    
    .mem_we_o     (mem_we),    
    .mem_wd_o     (mem_wd)      
  );


  instr_mem instruction_memory (
    .read_addr_i (instr_addr), 
    .read_data_o (instr)       
  );


  data_mem data_memory (
    .clk_i          (clk_i),       
    .mem_req_i      (mem_req),    
    .write_enable_i (mem_we),      
    .byte_enable_i  (4'b1111),     
    .addr_i         (mem_addr),    
    .write_data_i   (mem_wd),      
    .read_data_o    (mem_rd),      
    .ready_o        ()             
  );
endmodule
