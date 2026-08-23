`timescale 1ns / 1ps

module top #(
    parameter N = 4,
    parameter QUANTUM = 64,
    parameter PACKET_SIZE_WIDTH = 8,
    parameter FIFO_DEPTH = 16,
    parameter DEFICIT_COUNTER_WIDTH = 9
) (
    input                                   clk,
    input                                   resetn,
    input      [N-1:0]                      req,        
    input      [N*PACKET_SIZE_WIDTH-1:0]    packet_size,
    output     [N-1:0]                      fifo_full,    
    output     [N-1:0]                      fifo_empty,   
    output     [N-1:0]                      grant,        
    output                                  busy,         
    output                                  round_done,   
    output     [1:0]                        current_req
);

    wire [N*PACKET_SIZE_WIDTH-1:0] fifo_dout;
    wire [N-1:0]                   fifo_rd_en;
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : gen_fifos
            fifo #(
                .DATA_WIDTH(PACKET_SIZE_WIDTH),
                .DEPTH(FIFO_DEPTH),
                .CNT_WIDTH(5)
            ) u_fifo (
                .clk(clk),
                .resetn(resetn),
                .wr_en(req[i]),
                .rd_en(fifo_rd_en[i]),
                .din(packet_size[i*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH]),
                .dout(fifo_dout[i*PACKET_SIZE_WIDTH +: PACKET_SIZE_WIDTH]),
                .full(fifo_full[i]),
                .empty(fifo_empty[i])
            );
        end
    endgenerate

    arbiter #(
        .N(N),
        .QUANTUM(QUANTUM),
        .PACKET_SIZE_WIDTH(PACKET_SIZE_WIDTH),
        .DEFICIT_COUNTER_WIDTH(DEFICIT_COUNTER_WIDTH)
    ) u_arbiter (
        .clk(clk),
        .resetn(resetn),
        .fifo_empty(fifo_empty),
        .fifo_dout(fifo_dout),
        .fifo_rd_en(fifo_rd_en),
        .grant(grant),
        .busy(busy),
        .round_done(round_done),
        .current_req(current_req)
    );

endmodule
