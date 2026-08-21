`timescale 1ns / 1ps

module check #(
    parameter N = 4,
    parameter QUANTUM = 64,
    parameter PACKET_SIZE_WIDTH = 8
) (
    input                                   clk,
    input                                   resetn,
    input      [N-1:0]                      req,
    input      [N*PACKET_SIZE_WIDTH-1:0]    packet_size,
    input      [N-1:0]                      reset_ptr,
    input                                   flag1,
    output reg [N-1:0]                      next_check,
    output reg                              enable, 
    output reg [N*2-1:0]                    ptr
);

    reg [8:0] deficit_counter [N-1:0];
    integer i;

    always @(posedge clk) begin
        if (!resetn) begin
            enable <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                deficit_counter[i] <= 9'b0;
                ptr[i*2 +: 2]       <= 2'b00;
                next_check[i]      <= 1'b0;
            end
        end else begin
            enable <= (|req);
            for (i = 0; i < N; i = i + 1) begin
                if (reset_ptr[i]) begin
                    ptr[i*2 +: 2] <= 2'b00;
                end else if (req[i] && !flag1) begin
                    deficit_counter[i] <= deficit_counter[i] + QUANTUM;
                    if (deficit_counter[i] < packet_size[i*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH]) begin
                        next_check[i] <= 1'b0;
                        ptr[i*2 +: 2] <= ptr[i*2 +: 2] + 2'b01;
                    end else begin
                        deficit_counter[i] <= deficit_counter[i] - packet_size[i*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH];
                        next_check[i] <= 1'b1;
                        ptr[i*2 +: 2] <= 2'b00;
                    end
                end else begin
                    deficit_counter[i] <= 9'b0;
                    next_check[i]      <= 1'b0;
                end
            end
        end
    end

endmodule
