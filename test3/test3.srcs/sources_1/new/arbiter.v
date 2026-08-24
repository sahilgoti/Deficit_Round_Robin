`timescale 1ns / 1ps

module arbiter #(
    parameter N = 4,
    parameter QUANTUM = 64,
    parameter PACKET_SIZE_WIDTH = 8
) (
    input                                   clk,
    input                                   resetn,
    input      [N-1:0]                      req,
    input      [N*PACKET_SIZE_WIDTH-1:0]    packet_size,
    output reg [N-1:0]                      grant,
    output reg                              busy,
    output reg [N-1:0]                      next_check,
    output reg [N-1:0]                      grant_done
);

    localparam DEFICIT_WIDTH = 12;

    reg [DEFICIT_WIDTH-1:0] deficit_counter [0:N-1];
    integer rr_ptr;
    integer i, offset, idx;

    reg [N-1:0]                 can_serve_current;
    reg                         need_quantum;
    reg [DEFICIT_WIDTH-1:0]     avail_deficit [0:N-1];
    reg [PACKET_SIZE_WIDTH-1:0] pkt_size [0:N-1];
    reg [N-1:0]                 eligible;
    reg                         found;
    integer                     g_sel;

    always @(*) begin
        need_quantum = 1'b1;
        for (i = 0; i < N; i = i + 1) begin
            pkt_size[i] = packet_size[i*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH];
            if (req[i] && (deficit_counter[i] >= pkt_size[i])) begin
                can_serve_current[i] = 1'b1;
                need_quantum = 1'b0; 
            end else begin
                can_serve_current[i] = 1'b0;
            end
        end

        for (i = 0; i < N; i = i + 1) begin
            if (req[i]) begin
                if (need_quantum) begin
                    avail_deficit[i] = deficit_counter[i] + QUANTUM;
                end else begin
                    avail_deficit[i] = deficit_counter[i];
                end
                eligible[i] = (avail_deficit[i] >= pkt_size[i]);
            end else begin
                avail_deficit[i] = {DEFICIT_WIDTH{1'b0}};
                eligible[i]      = 1'b0;
            end
        end

        found = 1'b0;
        g_sel = 0;
        for (offset = 0; offset < N; offset = offset + 1) begin
            idx = (rr_ptr + offset) % N;

            if (!found && eligible[idx]) begin
                found = 1'b1;
                g_sel = idx;
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            grant      <= {N{1'b0}};
            busy       <= 1'b0;
            next_check <= {N{1'b0}};
            grant_done <= {N{1'b0}};
            rr_ptr     <= 0;
            for (i = 0; i < N; i = i + 1) begin
                deficit_counter[i] <= {DEFICIT_WIDTH{1'b0}};
            end
        end else begin
            busy       <= (|req);
            next_check <= eligible;

            if (found && (|req)) begin
                grant                  <= (1'b1 << g_sel);
                grant_done             <= (1'b1 << g_sel);
                deficit_counter[g_sel] <= avail_deficit[g_sel] - pkt_size[g_sel];

                for (i = 0; i < N; i = i + 1) begin
                    if (i != g_sel) begin
                        if (req[i]) begin
                            deficit_counter[i] <= avail_deficit[i];
                        end else begin
                            deficit_counter[i] <= {DEFICIT_WIDTH{1'b0}};
                        end
                    end
                end

                rr_ptr <= (g_sel + 1) % N;
            end else begin
                grant      <= {N{1'b0}};
                grant_done <= {N{1'b0}};
                for (i = 0; i < N; i = i + 1) begin
                    if (!req[i]) begin
                        deficit_counter[i] <= {DEFICIT_WIDTH{1'b0}};
                    end
                end
            end
        end
    end

endmodule