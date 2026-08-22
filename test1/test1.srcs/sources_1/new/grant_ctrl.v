`timescale 1ns / 1ps

module grant_ctrl #(
    parameter N = 4,
    parameter PTR_WIDTH = 2
) (
    input                       clk,
    input                       resetn,
    input                       fifo_empty,
    input      [PTR_WIDTH-1:0]  fifo_dout,
    input                       queue_done,
    output reg                  fifo_rd_en,
    output reg                  decoder_en,
    output reg [PTR_WIDTH-1:0]  decoder_in,
    output reg [N-1:0]          ptr_reset,
    output reg                  round_done
);
    reg [1:0] state;
    localparam IDLE = 2'b00, GRANT_PULSE = 2'b01, CHECK_FIFO = 2'b10, DONE = 2'b11;

    always @(posedge clk) begin
        if (!resetn) begin
            state      <= IDLE;
            fifo_rd_en <= 1'b0;
            decoder_en <= 1'b0;
            decoder_in <= {PTR_WIDTH{1'b0}};
            ptr_reset  <= {N{1'b0}};
            round_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    round_done <= 1'b0;
                    decoder_en <= 1'b0;
                    fifo_rd_en <= 1'b0;
                    ptr_reset  <= {N{1'b0}};
                    if (!fifo_empty) begin
                        fifo_rd_en <= 1'b1;
                        decoder_in <= fifo_dout;
                        decoder_en <= 1'b1;
                        ptr_reset  <= (1'b1 << fifo_dout);
                        state      <= GRANT_PULSE;
                    end
                end

                GRANT_PULSE: begin
                    fifo_rd_en <= 1'b0;
                    decoder_en <= 1'b0;
                    ptr_reset  <= {N{1'b0}};
                    state      <= CHECK_FIFO;
                end

                CHECK_FIFO: begin
                    if (!fifo_empty) begin
                        fifo_rd_en <= 1'b1;
                        decoder_in <= fifo_dout;
                        decoder_en <= 1'b1;
                        ptr_reset  <= (1'b1 << fifo_dout);
                        state      <= GRANT_PULSE;
                    end else begin
                        decoder_en <= 1'b0;
                        fifo_rd_en <= 1'b0;
                        ptr_reset  <= {N{1'b0}};
                        state      <= DONE;
                    end
                end

                DONE: begin
                    decoder_en <= 1'b0;
                    fifo_rd_en <= 1'b0;
                    ptr_reset  <= {N{1'b0}};
                    round_done <= 1'b1;
                    state      <= IDLE;
                end

                default: begin
                    state      <= IDLE;
                    fifo_rd_en <= 1'b0;
                    decoder_en <= 1'b0;
                    ptr_reset  <= {N{1'b0}};
                    round_done <= 1'b0;
                end
            endcase
        end
    end
endmodule


