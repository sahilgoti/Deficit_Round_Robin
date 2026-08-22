`timescale 1ns / 1ps

module decoder #(
    parameter N     = 4,
    parameter PTR_WIDTH = 2
) (
    input                  enable,
    input      [PTR_WIDTH-1:0] in,
    output reg [N-1:0]     out
);

    always @(*) begin
        if (!enable) begin
            out = {N{1'b0}};
        end else begin
            out = (1'b1 << in);
        end
    end

endmodule
