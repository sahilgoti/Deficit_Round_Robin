`timescale 1ns / 1ps

module fifo #(
    parameter DATA_WIDTH = 2,
    parameter DEPTH      = 10,
    parameter CNT_WIDTH  = 4
) (
    input                       clk,
    input                       resetn,
    input                       wr_en,
    input                       rd_en,
    input      [DATA_WIDTH-1:0] din,
    output     [DATA_WIDTH-1:0] dout,
    output                      full,
    output                      empty
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    reg [CNT_WIDTH-1:0] wr_ptr;
    reg [CNT_WIDTH-1:0] rd_ptr;
    reg [CNT_WIDTH:0]   count;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    assign dout = mem[rd_ptr];

    always @(posedge clk) begin
        if (!resetn) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: begin 
                    mem[wr_ptr] <= din;
                    wr_ptr      <= (wr_ptr == DEPTH - 1) ? {CNT_WIDTH{1'b0}} : wr_ptr + 1'b1;
                    count       <= count + 1'b1;
                end
                2'b01: begin 
                    rd_ptr <= (rd_ptr == DEPTH - 1) ? {CNT_WIDTH{1'b0}} : rd_ptr + 1'b1;
                    count  <= count - 1'b1;
                end
                2'b11: begin 
                    mem[wr_ptr] <= din;
                    wr_ptr      <= (wr_ptr == DEPTH - 1) ? {CNT_WIDTH{1'b0}} : wr_ptr + 1'b1;
                    rd_ptr      <= (rd_ptr == DEPTH - 1) ? {CNT_WIDTH{1'b0}} : rd_ptr + 1'b1;
                end
            endcase
        end
    end

endmodule


