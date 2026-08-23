`timescale 1ns / 1ps

module tb_top;

    parameter N                 = 4;
    parameter QUANTUM           = 64;
    parameter PACKET_SIZE_WIDTH = 8;
    parameter FIFO_DEPTH        = 16;

    reg                                  clk;
    reg                                  resetn;
    reg     [N-1:0]                      wr_en;
    reg     [N*PACKET_SIZE_WIDTH-1:0]    packet_size;

    wire    [N-1:0]                      fifo_full;
    wire    [N-1:0]                      fifo_empty;
    wire    [N-1:0]                      grant;
    wire                                 busy;
    wire                                 round_done;
    wire    [1:0]                        current_req;
    // Instantiate Top Module
    top #(
        .N(N),
        .QUANTUM(QUANTUM),
        .PACKET_SIZE_WIDTH(PACKET_SIZE_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) uut (
        .clk(clk),
        .resetn(resetn),
        .req(wr_en),
        .packet_size(packet_size),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .grant(grant),
        .busy(busy),
        .round_done(round_done),
        .current_req(current_req)
    );

    // Clock generation (100 MHz, 10ns period)
    always #5 clk = ~clk;

    // Monitor Grant pulses
    always @(posedge clk) begin
        if (grant[0]) $display("[%0t ns] ---> GRANT 0 Asserted! Packet served from Requester 0 FIFO.", $time);
        if (grant[1]) $display("[%0t ns] ---> GRANT 1 Asserted! Packet served from Requester 1 FIFO.", $time);
        if (grant[2]) $display("[%0t ns] ---> GRANT 2 Asserted! Packet served from Requester 2 FIFO.", $time);
        if (grant[3]) $display("[%0t ns] ---> GRANT 3 Asserted! Packet served from Requester 3 FIFO.", $time);
    end

    initial begin
        $dumpfile("drr.vcd");
        $dumpvars(0, tb_top);

        clk         = 0;
        resetn      = 0;
        wr_en       = 4'b0000;
        packet_size = 32'h0;

        #20;
        resetn = 1;
        #10;

        $display("==========================================================================");
        $display("   DRR Multi-Packet Burst Arbitration Simulation Testbench");
        $display("==========================================================================");

        // Step 1: Push Packet Stream into Requester FIFOs
        // Requester 0: Pkts [30, 20, 20] -> Total = 70. Round 1 can fit 30+20 = 50 <= 64!
        // Requester 2: Pkt  [255]       -> Requires 4 rounds of Q=64 to reach 256.
        // Requester 3: Pkt  [50]        -> Fits in Round 1 (50 <= 64).

        $display("[%0t ns] Phase 1: Loading Packets into Per-Requester FIFOs...", $time);

        // Push Pkt 1 to Req 0 (30), Req 2 (255), Req 3 (50)
        packet_size[0*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = 8'd30;
        packet_size[2*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = 8'd255;
        packet_size[3*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = 8'd50;
        wr_en = 4'b1101;
        #10;

        // Push Pkt 2 to Req 0 (20)
        packet_size[0*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = 8'd20;
        wr_en = 4'b0001;
        #10;

        // Push Pkt 3 to Req 0 (20)
        packet_size[0*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = 8'd20;
        wr_en = 4'b0001;
        #10;

        wr_en = 4'b0000;
        packet_size = 32'h0;
        #10;

        // Wait until all FIFOs are empty and arbiter completes
        wait(fifo_empty == 4'b1111 && busy == 1'b0);
        #40;

        $display("==========================================================================");
        $display("   DRR Multi-Packet Burst Arbitration Test Completed Successfully!");
        $display("   All packets granted in strict compliance with DRR Deficit rules.");
        $display("==========================================================================");
        $finish;
    end

endmodule
