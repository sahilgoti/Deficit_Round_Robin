`timescale 1ns / 1ps

module check #(
    parameter N = 4,
    parameter QUANTUM = 64,
    parameter PACKET_SIZE_WIDTH = 8,
    parameter PTR_WIDTH = 2
) (
    input                                   clk,
    input                                   resetn,
    input                                   start_round,
    input      [N-1:0]                      req,
    input      [N*PACKET_SIZE_WIDTH-1:0]    packet_size,
    input      [N-1:0]                      ptr_reset,
    output reg [N-1:0]                      eligible,
    output reg [N*PTR_WIDTH-1:0]            ptr,
    output reg                              check_done,
    output reg                              round_done
);
    reg [15:0] deficit_counter [N-1:0];
    integer i;
    reg [1:0] state;
    localparam IDLE = 2'b00, ADD = 2'b01, EVAL = 2'b10, DONE = 2'b11;

    always @(posedge clk) begin
        if (!resetn) begin
            state      <= IDLE;
            check_done <= 1'b0;
            eligible   <= {N{1'b0}};
            round_done <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                deficit_counter[i] <= 16'b0;
                ptr[i*PTR_WIDTH +: PTR_WIDTH] <= {PTR_WIDTH{1'b0}};
            end
        end else begin
            for (i = 0; i < N; i = i + 1) begin
                if (ptr_reset[i]) begin
                    ptr[i*PTR_WIDTH +: PTR_WIDTH] <= {PTR_WIDTH{1'b0}};
                end
            end

            case (state)
                IDLE: begin
                    check_done <= 1'b0;
                    eligible   <= {N{1'b0}};
                    round_done <= 1'b0;
                    if (start_round && (|req)) begin
                        state <= ADD;
                    end
                end

                ADD: begin
                    for (i = 0; i < N; i = i + 1) begin
                        if (req[i]) begin
                            deficit_counter[i] <= deficit_counter[i] + QUANTUM;
                        end
                    end
                    state <= EVAL;
                end

                EVAL: begin
                    for (i = 0; i < N; i = i + 1) begin
                        if (req[i]) begin
                            if (deficit_counter[i] >= packet_size[i*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH]) begin
                                deficit_counter[i] <= deficit_counter[i] - packet_size[i*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH];
                                eligible[i] <= 1'b1;
                            end else begin
                                eligible[i] <= 1'b0;
                                if (ptr[i*PTR_WIDTH +: PTR_WIDTH] != {PTR_WIDTH{1'b1}}) begin
                                    ptr[i*PTR_WIDTH +: PTR_WIDTH] <= ptr[i*PTR_WIDTH +: PTR_WIDTH] + 1'b1;
                                end
                            end
                        end else begin
                            eligible[i] <= 1'b0;
                            deficit_counter[i] <= 16'b0;
                            ptr[i*PTR_WIDTH +: PTR_WIDTH] <= {PTR_WIDTH{1'b0}};
                        end
                    end
                    state <= DONE;
                end

                DONE: begin
                    if (|eligible) begin
                        check_done <= 1'b1;
                    end else begin
                        round_done <= 1'b1;
                    end
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    check_done <= 1'b0;
                    round_done <= 1'b0;
                end
            endcase
        end
    end
endmodule
