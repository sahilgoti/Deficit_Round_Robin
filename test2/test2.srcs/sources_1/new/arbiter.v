`timescale 1ns / 1ps

module arbiter #(
    parameter N = 4,
    parameter QUANTUM = 64,
    parameter PACKET_SIZE_WIDTH = 8,
    parameter DEFICIT_COUNTER_WIDTH = 12
) (
    input                                   clk,
    input                                   resetn,
    input      [N-1:0]                      fifo_empty,
    input      [N*PACKET_SIZE_WIDTH-1:0]    fifo_dout,
    output reg [N-1:0]                      fifo_rd_en,
    output reg [N-1:0]                      grant,
    output reg                              busy,
    output reg [1:0]                        current_req,
    output reg                              round_done
);

    reg [DEFICIT_COUNTER_WIDTH-1:0] deficit_counter [N-1:0];
    reg [2:0] checked_count;
    reg [2:0] state;

    localparam IDLE        = 3'b000;
    localparam START_TURN  = 3'b001;
    localparam CHECK_PACKET = 3'b010;
    localparam NEXT_PACKET  = 3'b011;
    localparam CHECK_NEXT  = 3'b100;
    localparam ROUND_DONE  = 3'b101;

    wire [PACKET_SIZE_WIDTH-1:0] current_pkt_size;
    assign current_pkt_size = fifo_dout[current_req * PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH];

    integer i;

    always @(posedge clk) begin
        if (!resetn) begin
            state         <= IDLE;
            current_req   <= 2'b00;
            checked_count <= 3'b000;
            fifo_rd_en    <= {N{1'b0}};
            grant         <= {N{1'b0}};
            busy          <= 1'b0;
            round_done    <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                deficit_counter[i] <= {DEFICIT_COUNTER_WIDTH{1'b0}};
            end
        end else begin
            case (state)
                IDLE: begin
                    grant      <= {N{1'b0}};
                    fifo_rd_en <= {N{1'b0}};
                    round_done <= 1'b0;
                    
                    if (|(~fifo_empty)) begin
                        busy          <= 1'b1;
                        checked_count <= 3'b000;
                        state         <= START_TURN;
                    end else begin
                        busy <= 1'b0;
                    end
                end

                START_TURN: begin
                    grant      <= {N{1'b0}};
                    fifo_rd_en <= {N{1'b0}};

                    if (checked_count >= N) begin
                        state <= ROUND_DONE;
                    end else if (!fifo_empty[current_req]) begin
                        deficit_counter[current_req] <= deficit_counter[current_req] + QUANTUM;
                        state <= CHECK_PACKET;
                    end else begin
                        deficit_counter[current_req] <= {DEFICIT_COUNTER_WIDTH{1'b0}};
                        checked_count <= checked_count + 1'b1;
                        current_req   <= (current_req == N - 1) ? 2'b00 : current_req + 1'b1;
                        state         <= START_TURN;
                    end
                end

                CHECK_PACKET: begin
                    if (!fifo_empty[current_req] && (current_pkt_size <= deficit_counter[current_req])) begin
                        grant[current_req]      <= 1'b1;
                        fifo_rd_en[current_req] <= 1'b1;
                        deficit_counter[current_req] <= deficit_counter[current_req] - current_pkt_size;
                        state <= NEXT_PACKET;
                    end else begin
                        grant      <= {N{1'b0}};
                        fifo_rd_en <= {N{1'b0}};
                        checked_count <= checked_count + 1'b1;
                        current_req   <= (current_req == N - 1) ? 2'b00 : current_req + 1'b1;
                        state         <= START_TURN;
                    end
                end

                NEXT_PACKET: begin
                    grant      <= {N{1'b0}};
                    fifo_rd_en <= {N{1'b0}};
                    state      <= CHECK_NEXT;
                end

                CHECK_NEXT: begin
                    if (!fifo_empty[current_req] && (current_pkt_size <= deficit_counter[current_req])) begin
                        state <= CHECK_PACKET;
                    end else begin
                        checked_count <= checked_count + 1'b1;
                        current_req   <= (current_req == N - 1) ? 2'b00 : current_req + 1'b1;
                        state         <= START_TURN;
                    end
                end

                ROUND_DONE: begin
                    grant      <= {N{1'b0}};
                    fifo_rd_en <= {N{1'b0}};
                    round_done <= 1'b1;
                    busy       <= 1'b0;
                    state      <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
