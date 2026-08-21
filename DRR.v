`timescale 1ns / 1ps

module DRR #(
    parameter N          = 4,
    parameter QUANTUM    = 64,
    parameter PKT_W      = 8,
    parameter DEFICIT_W  = 10 
)(
    input  wire                   clk,
    input  wire                   resetn,
    input  wire [N-1:0]           req,
    input  wire [(N*PKT_W)-1:0]   packet_size,
    output reg  [N-1:0]           grant,
    output reg                    busy
);

    // Unpack packet sizes
    wire [PKT_W-1:0] size [0:N-1];
    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : UNPACK_SIZES
            assign size[g] = packet_size[(g*PKT_W) +: PKT_W];
        end
    endgenerate

    // Internal Deficit Counters and Pointer
    reg [DEFICIT_W-1:0] deficit [0:N-1];
    reg [$clog2(N)-1:0] ptr;

    // FSM States
    localparam S_IDLE  = 1'b0;
    localparam S_SERVE = 1'b1;
    reg state;

    integer i;

    // Combinational evaluation for current turn
    wire [DEFICIT_W-1:0] current_deficit_accum = deficit[ptr] + QUANTUM;
    wire                 has_enough_credits    = (current_deficit_accum >= { {(DEFICIT_W-PKT_W){1'b0}}, size[ptr] });

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= S_IDLE;
            ptr   <= {($clog2(N)){1'b0}};
            grant <= {N{1'b0}};
            busy  <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                deficit[i] <= {DEFICIT_W{1'b0}};
            end
        end else begin
            case (state)
                S_IDLE: begin
                    grant <= {N{1'b0}};
                    busy  <= 1'b0;

                    if (req[ptr]) begin
                        if (has_enough_credits) begin
                            // GRANT: Deduct packet size, set one-hot grant, assert busy
                            grant[ptr]   <= 1'b1;
                            busy         <= 1'b1;
                            deficit[ptr] <= current_deficit_accum - { {(DEFICIT_W-PKT_W){1'b0}}, size[ptr] };
                            state        <= S_SERVE;
                        end else begin
                            // SKIP: Accumulate quantum for future round, advance pointer
                            deficit[ptr] <= current_deficit_accum;
                            ptr          <= (ptr == N - 1) ? 0 : ptr + 1'b1;
                        end
                    end else begin
                        // Inactive requester: advance pointer
                        ptr <= (ptr == N - 1) ? 0 : ptr + 1'b1;
                    end
                end

                S_SERVE: begin
                    // Complete grant cycle, release bus, and advance pointer
                    grant <= {N{1'b0}};
                    busy  <= 1'b0;
                    ptr   <= (ptr == N - 1) ? 0 : ptr + 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule