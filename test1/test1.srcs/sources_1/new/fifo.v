`timescale 1ns / 1ps

module fifo #(
    parameter DATA_WIDTH = 2,
    parameter DEPTH      = 4
) (
    input                       clk,
    input                       resetn,
    input                       wr_en,
    input                       rd_en,
    input      [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout,
    output                      full,
    output                      empty
);

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Internal pointers and count
    reg [$clog2(DEPTH)-1:0] wr_ptr;
    reg [$clog2(DEPTH)-1:0] rd_ptr;
    reg [$clog2(DEPTH):0]   count;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    always @(posedge clk) begin
        if (!resetn) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
            dout   <= {DATA_WIDTH{1'b0}};
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: begin // Write only
                    mem[wr_ptr] <= din;
                    wr_ptr      <= wr_ptr + 1'b1;
                    count       <= count + 1'b1;
                end
                2'b01: begin // Read only
                    dout   <= mem[rd_ptr];
                    rd_ptr <= rd_ptr + 1'b1;
                    count  <= count - 1'b1;
                end
                2'b11: begin // Write and Read simultaneously
                    mem[wr_ptr] <= din;
                    dout        <= mem[rd_ptr];
                    wr_ptr      <= wr_ptr + 1'b1;
                    rd_ptr      <= rd_ptr + 1'b1;
                end
                default: ; // No op
            endcase
        end
    end

endmodule
