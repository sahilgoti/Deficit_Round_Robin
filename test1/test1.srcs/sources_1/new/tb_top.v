`timescale 1ns / 1ps

module tb_top;

    parameter N                 = 4;
    parameter QUANTUM           = 64;
    parameter PACKET_SIZE_WIDTH = 8;
    parameter PTR_WIDTH         = 2;

    reg                                  clk;
    reg                                  resetn;
    reg     [N-1:0]                      req;
    reg     [N*PACKET_SIZE_WIDTH-1:0]    packet_size;
    wire                                 busy;
    wire    [N-1:0]                      grant;

    top #(
        .N(N),
        .QUANTUM(QUANTUM),
        .PACKET_SIZE_WIDTH(PACKET_SIZE_WIDTH),
        .PTR_WIDTH(PTR_WIDTH)
    ) uut (
        .clk(clk),
        .resetn(resetn),
        .req(req),
        .packet_size(packet_size),
        .busy(busy),
        .grant(grant)
    );

    always #5 clk = ~clk;

    reg [PACKET_SIZE_WIDTH-1:0] q0 [0:3];
    reg [PACKET_SIZE_WIDTH-1:0] q2 [0:0];
    reg [PACKET_SIZE_WIDTH-1:0] q3 [0:0];
    integer i0, i2, i3;

    initial begin
        $dumpfile("drr.vcd");
        $dumpvars(0, tb_top);

        q0[0] = 8'd30;  q0[1] = 8'd50;  q0[2] = 8'd60;  q0[3] = 8'd20;
        q2[0] = 8'd255;
        q3[0] = 8'd90;

        clk         = 0;
        resetn      = 0;
        req         = 4'b0000;
        packet_size = { (N*PACKET_SIZE_WIDTH){1'b0} };

        i0 = 0; i2 = 0; i3 = 0;

        #20;
        resetn = 1;
        #10;

        $display("==========================================================================");
        $display("   DRR Multi-Packet Stream Simulation Testbench");
        $display("==========================================================================");

        packet_size[0*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = q0[0];
        req[0] = 1'b1;

        packet_size[1*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = 8'd0;
        req[1] = 1'b0;

        packet_size[2*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = q2[0];
        req[2] = 1'b1;

        packet_size[3*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] = q3[0];
        req[3] = 1'b1;

        fork
            // Requester 0 stream handler (4 packets: 30, 50, 60, 20)
            begin
                while (i0 < 4) begin
                    wait(grant[0] == 1'b1);
                    @(posedge clk);
                    i0 = i0 + 1;
                    if (i0 < 4) begin
                        packet_size[0*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH] <= q0[i0];
                        $display("   -> Requester 0 Granted Pkt %d (size = %d)", i0, q0[i0]);
                    end else begin
                        req[0] <= 1'b0;
                        $display("   -> Requester 0 Queue Empty.");
                    end
                end
            end

            // Requester 2 stream handler (1 large packet: 255)
            begin
                while (i2 < 1) begin
                    wait(grant[2] == 1'b1);
                    @(posedge clk);
                    i2 = i2 + 1;
                    req[2] <= 1'b0;
                    $display("   -> Requester 2 Granted Large Packet (255). Queue Empty.");
                end
            end

            // Requester 3 stream handler (1 packet: 90)
            begin
                while (i3 < 1) begin
                    wait(grant[3] == 1'b1);
                    @(posedge clk);
                    i3 = i3 + 1;
                    req[3] <= 1'b0;
                    $display("   -> Requester 3 Granted Packet (90). Queue Empty.");
                end
            end

        join

        // Wait for busy signal to deassert after all packet rounds finish
        wait(busy == 1'b0);
        #20;

        $display("==========================================================================");
        $display("   All Packets Successfully Transmitted and Granted!");
        $display("   BUSY signal deasserted. Test Passed.");
        $display("==========================================================================");
        $finish;
    end

endmodule

