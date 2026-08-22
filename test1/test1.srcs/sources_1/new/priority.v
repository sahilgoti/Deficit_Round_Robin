`timescale 1ns / 1ps

module priority_queuer #(
    parameter N = 4,
    parameter PTR_WIDTH = 2
) (
    input                               clk,
    input                               resetn,
    input                               check_done,
    input      [N-1:0]                  eligible,
    input      [N*PTR_WIDTH-1:0]        ptr,
    output reg                          fifo_wr_en,
    output reg [PTR_WIDTH-1:0]          fifo_din,
    input                               fifo_full,
    output reg [PTR_WIDTH*N-1:0]        sequence,
    output reg                          queue_done
);

    localparam IDLE = 2'b00;
    localparam PUSH = 2'b01;

    reg [1:0] state;

    integer i, j, rank_j;
    reg [PTR_WIDTH*N-1:0] next_sequence;
    reg [PTR_WIDTH:0] total_eligible;
    reg [PTR_WIDTH*N-1:0] seq_buf;
    reg [PTR_WIDTH:0] num_buf;
    reg [PTR_WIDTH:0] push_cnt;

    always @(*) begin
        next_sequence = {(PTR_WIDTH*N){1'b0}};
        total_eligible = 0;

        for (j = 0; j < N; j = j + 1) begin
            if (eligible[j]) begin
                total_eligible = total_eligible + 1;
                rank_j = 0;
                for (i = 0; i < N; i = i + 1) begin
                    if (eligible[i] && (i != j)) begin
                        if ((ptr[i*PTR_WIDTH +: PTR_WIDTH] > ptr[j*PTR_WIDTH +: PTR_WIDTH]) || 
                            ((ptr[i*PTR_WIDTH +: PTR_WIDTH] == ptr[j*PTR_WIDTH +: PTR_WIDTH]) && (i < j))) begin
                            rank_j = rank_j + 1;
                        end
                    end
                end
                if (rank_j < N) begin
                    next_sequence[rank_j*PTR_WIDTH +: PTR_WIDTH] = j[PTR_WIDTH-1:0];
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            state      <= IDLE;
            queue_done <= 1'b0;
            sequence   <= {(PTR_WIDTH*N){1'b0}};
            fifo_wr_en <= 1'b0;
            fifo_din   <= {PTR_WIDTH{1'b0}};
            push_cnt   <= 0;
            seq_buf    <= {(PTR_WIDTH*N){1'b0}};
            num_buf    <= 0;
        end else begin
            case (state)
                IDLE: begin
                    queue_done <= 1'b0;
                    fifo_wr_en <= 1'b0;
                    if (check_done) begin
                        if (|eligible) begin
                            sequence   <= next_sequence;
                            seq_buf    <= next_sequence;
                            num_buf    <= total_eligible;
                            push_cnt   <= 0;
                            state      <= PUSH;
                        end else begin
                            state      <= IDLE;
                        end
                    end
                end

                PUSH: begin
                    if (push_cnt < num_buf && !fifo_full) begin
                        fifo_wr_en <= 1'b1;
                        fifo_din   <= seq_buf[push_cnt*PTR_WIDTH +: PTR_WIDTH];
                        push_cnt   <= push_cnt + 1;
                        if (push_cnt == num_buf - 1) begin
                            queue_done <= 1'b1;
                            state      <= IDLE;
                        end
                    end else begin
                        fifo_wr_en <= 1'b0;
                        queue_done <= 1'b1;
                        state      <= IDLE;
                    end
                end

                default: begin
                    state      <= IDLE;
                    queue_done <= 1'b0;
                    fifo_wr_en <= 1'b0;
                end
            endcase
        end
    end

endmodule



