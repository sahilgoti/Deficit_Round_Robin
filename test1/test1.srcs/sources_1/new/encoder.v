`timescale 1ns / 1ps

module encoder #(
    parameter N     = 4,
    parameter WIDTH = $clog2(N)
) (
    input  [N-1:0]         in,
    output reg [WIDTH-1:0] out,
    output reg             valid
);

    integer i;

    always @(*) begin
        out   = {WIDTH{1'b0}};
        valid = 1'b0;
        for (i = 0; i < N; i = i + 1) begin
            if (in[i]) begin
                out   = i[WIDTH-1:0];
                valid = 1'b1;
            end
        end
    end

endmodule
