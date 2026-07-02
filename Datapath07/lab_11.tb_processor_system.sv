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
    integer i;
    integer check_cycle;
    bit test_passed;

    processor_system DUT(
    .clk_i(clk),
    .rst_i(rst)
    );

    function automatic logic [31:0] test_instr(input logic [31:0] pc);
      case (pc[31:2])
        30'd0: test_instr = 32'h0000_00B7; // lui x1, 0x00000
        30'd1: test_instr = 32'h3FC0_02B7; // lui x5, 0x3fc00 = 1.5f
        30'd2: test_instr = 32'h4000_0337; // lui x6, 0x40000 = 2.0f
        30'd3: test_instr = 32'h0262_83B3; // real_mul x7, x5, x6
        30'd4: test_instr = 32'h0070_A023; // sw x7, 0(x1)
        default: test_instr = 32'h0000_006F; // jal x0, 0
      endcase
    endfunction

    always @(*) begin
      force DUT.instr = test_instr(DUT.instr_addr);
    end

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
        $display("\nREAL_MUL processor-system test has been started");

        DUT.irq_req = 0;
        rst = 1;
        test_passed = 1'b0;

        for (i = 0; i < 128; i = i + 1) begin
          DUT.data_memory.ram[i] = 32'h0000_0000;
        end

        // Clear GPRs because this register_file implementation does not reset them.
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
          $display("\nREAL_MUL DEBUG");
          $display("PC      = 0x%08h", DUT.core.PC_reg);
          $display("instr   = 0x%08h", DUT.instr);
          $display("stall   = %b", DUT.stall);
          $display("illegal = %b", DUT.core.illegal_instr);
          $display("trap    = %b", DUT.core.trap);
          $display("x5      = 0x%08h", DUT.core.reg_file.rf_mem[5]);
          $display("x6      = 0x%08h", DUT.core.reg_file.rf_mem[6]);
          $display("x7      = 0x%08h", DUT.core.reg_file.rf_mem[7]);
          $display("ram[0]  = 0x%08h", DUT.data_memory.ram[0]);
          $fatal(1, "REAL_MUL test failed: expected ram[0] = 0x%08h", REAL_MUL_EXPECTED);
        end

        $display("\n============================================================");
        $display("REAL_MUL TEST PASSED");
        $display("1.5 * 2.0 = 3.0");
        $display("Result in data_memory.ram[0] = 0x%08h", DUT.data_memory.ram[0]);
        $display("Module real_mul is fully working in the processor system.");
        $display("============================================================\n");
        $finish;
    end

endmodule
