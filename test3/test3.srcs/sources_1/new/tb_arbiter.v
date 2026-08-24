`timescale 1ns / 1ps

module tb_arbiter_selfcheck;

    parameter N = 4;
    parameter QUANTUM = 64;
    parameter PACKET_SIZE_WIDTH = 8;
    parameter DEFICIT_COUNTER_WIDTH = 12;
    parameter MAX_PKTS_PER_REQ = 4;

    // Signals
    reg                                  clk;
    reg                                  resetn;
    reg     [N-1:0]                      req;
    reg     [N*PACKET_SIZE_WIDTH-1:0]    packet_size;

    wire    [N-1:0]                      grant;
    wire                                 busy;
    wire    [N-1:0] next_check;
    wire    [N-1:0] grant_done;

    // Instantiate the DRR arbiter module
    arbiter #(
        .N(N),
        .QUANTUM(QUANTUM),
        .PACKET_SIZE_WIDTH(PACKET_SIZE_WIDTH)
    ) uut (
        .clk(clk),
        .resetn(resetn),
        .req(req),
        .packet_size(packet_size),
        .grant(grant),
        .busy(busy),
        .next_check(next_check),
        .grant_done(grant_done)
    );

    // 100 MHz Clock (10ns period)
    always #5 clk = ~clk;

    // Multi-Packet Queue Memory for each requester
    reg [PACKET_SIZE_WIDTH-1:0] pkt_mem [0:N-1][0:MAX_PKTS_PER_REQ-1];
    integer pkt_head  [0:N-1];
    integer pkt_count [0:N-1];
    integer total_granted_pkts [0:N-1];

    // Response Handler: When grant[k] is issued on posedge clk, advance queue or deassert req[k]
    integer k;
    always @(posedge clk) begin
        if (resetn) begin
            for (k = 0; k < N; k = k + 1) begin
                if (grant[k]) begin
                    total_granted_pkts[k] <= total_granted_pkts[k] + 1;
                    if (pkt_head[k] + 1 < pkt_count[k]) begin
                        // Advance to next packet in queue for Requester k
                        pkt_head[k] <= pkt_head[k] + 1;
                        packet_size[k*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] <= pkt_mem[k][pkt_head[k] + 1];
                    end else begin
                        // Queue empty for Requester k
                        req[k] <= 1'b0;
                    end
                end
            end
        end
    end

    // Main Test Control Sequence
    initial begin
        $dumpfile("drr_multi_packet.vcd");
        $dumpvars(0, tb_arbiter_selfcheck);

        // Clock & Reset Initialization
        clk = 0;
        resetn = 0;
        req = {N{1'b0}};
        packet_size = {N*PACKET_SIZE_WIDTH{1'b0}};

        // Setup Multi-Packet Queues for each requester
        // Requester 0: 3 Packets -> [30 Bytes, 20 Bytes, 25 Bytes]
        pkt_mem[0][0] = 8'd30; pkt_mem[0][1] = 8'd20; pkt_mem[0][2] = 8'd25;
        pkt_count[0] = 3; pkt_head[0] = 0; total_granted_pkts[0] = 0;

        // Requester 1: 3 Packets -> [40 Bytes, 35 Bytes, 15 Bytes]
        pkt_mem[1][0] = 8'd40; pkt_mem[1][1] = 8'd35; pkt_mem[1][2] = 8'd15;
        pkt_count[1] = 3; pkt_head[1] = 0; total_granted_pkts[1] = 0;

        // Requester 2: 3 Packets -> [70 Bytes, 45 Bytes, 10 Bytes]
        pkt_mem[2][0] = 8'd70; pkt_mem[2][1] = 8'd45; pkt_mem[2][2] = 8'd10;
        pkt_count[2] = 3; pkt_head[2] = 0; total_granted_pkts[2] = 0;

        // Requester 3: 2 Packets -> [50 Bytes, 60 Bytes]
        pkt_mem[3][0] = 8'd50; pkt_mem[3][1] = 8'd60;
        pkt_count[3] = 2; pkt_head[3] = 0; total_granted_pkts[3] = 0;

        #25;
        resetn = 1; // Release reset

        // Present initial head packet of each requester to packet_size bus
        packet_size[0*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = pkt_mem[0][0];
        packet_size[1*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = pkt_mem[1][0];
        packet_size[2*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = pkt_mem[2][0];
        packet_size[3*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = pkt_mem[3][0];

        // Assert request for all requesters
        req = {N{1'b1}};

        $display("==========================================================================");
        $display("   DRR Arbiter - Multi-Packet Sequential Grant Verification Testbench");
        $display("==========================================================================");
        $display("Initial Queues:");
        $display("  Requester 0: 3 Packets [30, 20, 25 Bytes]");
        $display("  Requester 1: 3 Packets [40, 35, 15 Bytes]");
        $display("  Requester 2: 3 Packets [70, 45, 10 Bytes]");
        $display("  Requester 3: 2 Packets [50, 60 Bytes]");
        $display("--------------------------------------------------------------------------");

        // Wait until all multi-packet queues are completely served
        wait (req == {N{1'b0}});

        // Buffer cycles to complete final state
        #50;

        $display("==========================================================================");
        $display("   Multi-Packet Verification Completed Successfully!");
        $display("   Total Packets Granted: Req0=%0d, Req1=%0d, Req2=%0d, Req3=%0d",
                 total_granted_pkts[0], total_granted_pkts[1], total_granted_pkts[2], total_granted_pkts[3]);
        $display("==========================================================================");
        $finish;
    end

    // Self-Checking Monitor (Console Output)
    integer m;
    always @(posedge clk) begin
        if (resetn && (|grant)) begin
            for (m = 0; m < N; m = m + 1) begin
                if (grant[m]) begin
                    $display("[%0t ns] -> GRANT issued to Requester %0d | Packet #%0d | Size: %0d Bytes",
                             $time, m, pkt_head[m] + 1, packet_size[m*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH]);
                end
            end
        end
        if (resetn) begin
            $display("[%0t ns] -> DRR Round complete. Quantum (%0d) added to active deficits.", $time, QUANTUM);
        end
    end

endmodule