/* -----------------------------------------------------------------------------
* Project Name   : Architectures of Processor Systems (APS) lab work
* Organization   : National Research University of Electronic Technology (MIET)
* Department     : Institute of Microdevices and Control Systems
* Author(s)      : Andrei Solodovnikov
* Email(s)       : hepoh@org.miet.ru

See https://github.com/MPSU/APS/blob/master/LICENSE file for licensing details.
* ------------------------------------------------------------------------------
*/
module lab_11_tb_processor_system();

    localparam logic [31:0] REAL_MUL_EXPECTED = 32'h4040_0000; // 3.0f

    reg clk;
    reg rst;
    reg irq_req;
    wire irq_ret;
    integer i;
    integer check_cycle;
    bit test_passed;

    processor_system DUT(
      .clk_i     (clk),
      .rst_i     (rst),
      .irq_req_i (irq_req),
      .irq_ret_o (irq_ret)
    );

    initial begin
      repeat(1000) begin
        @(posedge clk);
      end
      $fatal(1, "REAL_MUL watchdog: ram[0]=0x%08h PC=0x%08h instr=0x%08h stall=%b illegal=%b trap=%b",
             DUT.data_memory.ram[0], DUT.core.PC_reg, DUT.instr,
             DUT.stall, DUT.core.illegal_instr, DUT.core.trap);
    end

    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        $display("\nЗапуск системного теста REAL_MUL");

        irq_req = 0;
        rst = 1;
        test_passed = 1'b0;

        for (i = 0; i < 128; i = i + 1) begin
          DUT.data_memory.ram[i] = 32'h0000_0000;
        end

        // В этой версии register_file нет сброса, поэтому очищаем регистры здесь
        for (i = 0; i < 32; i = i + 1) begin
          DUT.core.reg_file.rf_mem[i] = 32'h0000_0000;
        end

        #40;
        rst = 0;

        for (check_cycle = 0; check_cycle < 100; check_cycle = check_cycle + 1) begin
          @(posedge clk);
          if (DUT.data_memory.ram[0] === REAL_MUL_EXPECTED) begin
            test_passed = 1'b1;
            check_cycle = 100;
          end
        end

        if (!test_passed) begin
          $display("\nОтладочная информация REAL_MUL");
          $display("PC      = 0x%08h", DUT.core.PC_reg);
          $display("instr   = 0x%08h", DUT.instr);
          $display("stall   = %b", DUT.stall);
          $display("illegal = %b", DUT.core.illegal_instr);
          $display("trap    = %b", DUT.core.trap);
          $display("x5      = 0x%08h", DUT.core.reg_file.rf_mem[5]);
          $display("x6      = 0x%08h", DUT.core.reg_file.rf_mem[6]);
          $display("x7      = 0x%08h", DUT.core.reg_file.rf_mem[7]);
          $display("ram[0]  = 0x%08h", DUT.data_memory.ram[0]);
          $fatal(1, "Ошибка REAL_MUL: ожидалось ram[0] = 0x%08h", REAL_MUL_EXPECTED);
        end

        $display("\n============================================================");
        $display("ТЕСТ REAL_MUL ПРОЙДЕН");
        $display("1.5 * 2.0 = 3.0");
        $display("Результат в data_memory.ram[0] = 0x%08h", DUT.data_memory.ram[0]);
        $display("============================================================\n");
        $finish;
    end

endmodule
