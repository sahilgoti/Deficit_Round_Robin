`timescale 1ns / 1ps

module arbiter #(
    parameter N                 = 4,
    parameter QUANTUM           = 64,
    parameter PACKET_SIZE_WIDTH = 8,
    parameter COUNTER_WIDTH     = 16
) (
    input                               clk,
    input                               resetn,
    input      [N-1:0]                  req,
    input      [N*PACKET_SIZE_WIDTH-1:0] packet_size,
    output reg [N-1:0]                  grant,
    output reg                          busy
);

    wire [PACKET_SIZE_WIDTH-1:0] pkt_size [0:N-1];
    reg  [COUNTER_WIDTH-1:0]     deficit_counter [0:N-1];
    reg  [N-1:0]                 cur_eligible;
    reg  [N-1:0]                 replenish_eligible;
    reg  [N-1:0]                 active_eligible;
    integer                      rr_ptr;
    reg                          need_replenish;
    reg                          found;

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : UNPACK_PKT
            assign pkt_size[g] = packet_size[g*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH];
        end
    endgenerate

    integer i, offset, idx, k;

    // Combinational arbitration decision
    always @(*) begin
        busy = (|req);

        // 1. Evaluate eligibility with current deficit
        for (i = 0; i < N; i = i + 1) begin
            if (req[i] && (deficit_counter[i] >= pkt_size[i])) begin
                cur_eligible[i] = 1'b1;
            end else begin
                cur_eligible[i] = 1'b0;
            end

            if (req[i] && ((deficit_counter[i] + QUANTUM) >= pkt_size[i])) begin
                replenish_eligible[i] = 1'b1;
            end else begin
                replenish_eligible[i] = 1'b0;
            end
        end

        // 2. Replenish quantum if all active requesters lack deficit in current round
        need_replenish = (|req) && (cur_eligible == {N{1'b0}});
        active_eligible = need_replenish ? replenish_eligible : cur_eligible;

        // 3. Grant selection starting from current round-robin pointer
        // If current requester is still eligible, it retains the grant (multi-packet burst)
        grant = {N{1'b0}};
        found = 1'b0;
        for (offset = 0; offset < N; offset = offset + 1) begin
            idx = (rr_ptr + offset) % N;
            if (!found && active_eligible[idx]) begin
                grant = ({{(N-1){1'b0}}, 1'b1} << idx);
                found = 1'b1;
            end
        end
    end

    // Sequential state and deficit counter updates
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rr_ptr <= 0;
            for (k = 0; k < N; k = k + 1) begin
                deficit_counter[k] <= QUANTUM;
            end
        end else begin
            // Update rr_ptr to the currently served requester so it can burst if deficit allows
            for (k = 0; k < N; k = k + 1) begin
                if (grant[k]) begin
                    rr_ptr <= k;
                end
            end

            // Deficit counter update
            for (k = 0; k < N; k = k + 1) begin
                if (req[k]) begin
                    if (need_replenish) begin
                        if (grant[k]) begin
                            deficit_counter[k] <= deficit_counter[k] + QUANTUM - pkt_size[k];
                        end else begin
                            deficit_counter[k] <= deficit_counter[k] + QUANTUM;
                        end
                    end else begin
                        if (grant[k]) begin
                            deficit_counter[k] <= deficit_counter[k] - pkt_size[k];
                        end else begin
                            deficit_counter[k] <= deficit_counter[k];
                        end
                    end
                end else begin
                    deficit_counter[k] <= {COUNTER_WIDTH{1'b0}};
                end
            end
        end
    end

endmodule