`timescale 1ns / 1ps

module decoder #(
    parameter N     = 4,
    parameter WIDTH = $clog2(N)
) (
    input                  enable,
    input      [WIDTH-1:0] in,
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
