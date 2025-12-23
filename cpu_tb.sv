`timescale 1ns/1ps

module cpu_tb;

    reg clk;
    reg rst;

    // DUT: Top-level CPU
    cpu_top dut (
        .clk(clk),
        .rst(rst)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, cpu_tb);

        clk = 0;
        rst = 1;
        #20 rst = 0;

        #500 $finish;
    end

endmodule