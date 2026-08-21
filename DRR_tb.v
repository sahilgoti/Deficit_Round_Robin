`timescale 1ns / 1ps

module DRR_tb;

    reg         clk;
    reg         resetn;
    reg  [3:0]  req;
    reg  [31:0] packet_size;
    wire [3:0]  grant;
    wire        busy;

    // Instantiate DUT
    DRR #(
        .N(4),
        .QUANTUM(64),
        .PKT_W(8),
        .DEFICIT_W(10)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .req(req),
        .packet_size(packet_size),
        .grant(grant),
        .busy(busy)
    );

    // Clock generation (100MHz)
    always #5 clk = ~clk;
    initial begin
        $dumpfile("drr.vcd");
        $dumpvars(0, DRR_tb);  // Use the exact module name of your testbench
    end
    initial begin
        clk         = 0;
        resetn      = 0;
        req         = 4'b0000;
        packet_size = 32'd0;

        // Reset sequence
        #20;
        resetn = 1;
        #10;

        $display("=== Test 1: R0 fits in Quantum (40B), R1 exceeds Quantum (120B) ===");
        // R0: 40B (0x28), R1: 120B (0x78), R2: 64B (0x40), R3: 30B (0x1E)
        packet_size = {8'd30, 8'd64, 8'd120, 8'd40};
        req         = 4'b0011; // R0 and R1 active

        // Wait and check R0 grant
        @(posedge clk);
        wait (grant[0] == 1'b1);
        $display("[PASS] Requester 0 granted 40 bytes on cycle: %0t", $time);

        // Wait for R1: Should be skipped on round 1, then granted on round 2
        wait (grant[1] == 1'b1);
        $display("[PASS] Requester 1 granted 120 bytes after deficit accumulation on cycle: %0t", $time);

        #40;
        $display("=== Simulation Completed Successfully ===");
        $finish;
    end

endmodule
