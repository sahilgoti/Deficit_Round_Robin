`timescale 1ns / 1ps

module priority #(
    parameter N = 4
) (
    input               clk,
    input               resetn,
    input  [N-1:0]      next_check,
    input  [N*2-1:0]    ptr,
    input               enable,
    output [N-1:0]      grant,
    output reg [N-1:0]  reset_ptr,
    output reg          flag1
);

    reg [N-1:0]             grant_done;
    reg                     wr_en;
    reg [$clog2(N)-1:0]     din;
    wire [$clog2(N)-1:0]    dout;
    wire                    full;
    wire                    empty;
    integer                 i, j;

    always @(posedge clk) begin
        if (!resetn) begin
            grant_done <= {N{1'b0}};
            reset_ptr  <= {N{1'b0}};
            flag1      <= 1'b0;
            wr_en      <= 1'b0;
            din        <= {$clog2(N){1'b0}};
        end else if (!enable) begin
            grant_done <= {N{1'b0}};
            reset_ptr  <= {N{1'b0}};
            flag1      <= 1'b0;
            wr_en      <= 1'b0;
            din        <= {$clog2(N){1'b0}};
        end else begin
            flag1 <= 1'b1;
            wr_en <= 1'b0;
            for (j = N-1; j >= 0; j = j - 1) begin
                for (i = 0; i < N; i = i + 1) begin
                    if (!grant_done[i] && next_check[i] && (ptr[i*2 +: 2] == j)) begin
                        wr_en         <= 1'b1;
                        din           <= i[$clog2(N)-1:0];
                        grant_done[i] <= 1'b1;
                        reset_ptr[i]  <= 1'b1;
                    end else begin
                        reset_ptr[i]  <= 1'b0;
                    end
                end
                grant_done <= {N{1'b0}};
            end
            flag1 <= 1'b0;
        end
    end

    fifo #(
        .DATA_WIDTH($clog2(N)),
        .DEPTH(4)
    ) fifo1 (
        .clk(clk),
        .resetn(resetn),
        .wr_en(wr_en),
        .rd_en(1'b1),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );

    decoder #(
        .N(N),
        .WIDTH($clog2(N))
    ) decoder1 (
        .enable(wr_en),
        .in(dout),
        .out(grant)
    );

endmodule