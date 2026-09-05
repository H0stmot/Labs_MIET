module lab_11_tb_processor_system();

    reg clk;
    reg rst;
    reg irq_req;
    wire irq_ret;
    integer i;
    integer check_cycle;
    integer errors;

    processor_system DUT(
      .clk_i     (clk),
      .rst_i     (rst),
      .irq_req_i (irq_req),
      .irq_ret_o (irq_ret)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    task check_ram;
      input integer addr;
      input [31:0] expected_data;
      begin
        if (DUT.data_memory.ram[addr] !== expected_data) begin
          $display("Ошибка: ram[%0d] = %08h, ожидалось %08h",
                   addr, DUT.data_memory.ram[addr], expected_data);
          errors = errors + 1;
        end
      end
    endtask

    initial begin
      irq_req = 0;
      rst = 1;
      errors = 0;

      for (i = 0; i < 128; i = i + 1)
        DUT.data_memory.ram[i] = 32'h0000_0000;

      // В регистровом файле нет отдельного входа сброса
      for (i = 0; i < 32; i = i + 1)
        DUT.core.reg_file.rf_mem[i] = 32'h0000_0000;

      #40;
      rst = 0;

      // Последняя метка появляется после обработки EBREAK
      for (check_cycle = 0; check_cycle < 300; check_cycle = check_cycle + 1) begin
        @(posedge clk);
        if (DUT.data_memory.ram[8] === 32'h0000_0002)
          check_cycle = 300;
      end

      check_ram(0, 32'hFFFF_FFEB); // MUL: -7 * 3 = -21
      check_ram(1, 32'hFFFF_FFFF); // MULH
      check_ram(2, 32'hFFFF_FFFF); // MULHSU
      check_ram(3, 32'h0000_0002); // MULHU
      check_ram(4, 32'h4040_0000); // FM: 1.5 * 2.0 = 3.0
      check_ram(5, 32'h0000_0001); // возврат после ECALL
      check_ram(6, 32'h0000_000B); // mcause ECALL
      check_ram(7, 32'h0000_0003); // mcause EBREAK
      check_ram(8, 32'h0000_0002); // возврат после EBREAK

      if (errors != 0)
        $fatal(1, "Системный тест завершился с ошибками: %0d", errors);

      $display("\nСистемный тест пройден");
      $display("Проверены MUL, MULH, MULHSU, MULHU, FM, ECALL и EBREAK\n");
      $finish;
    end

endmodule
