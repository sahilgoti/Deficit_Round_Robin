`timescale 1ns / 1ps

module top #(
   parameter N = 4,
   parameter QUANTUM = 64,
   parameter PACKET_SIZE_WIDTH = 8,
   parameter PTR_WIDTH = 2
) (
   input                                   clk,     
   input                                   resetn,  
   input    [N-1:0]                        req,    
   input    [N*PACKET_SIZE_WIDTH-1:0]      packet_size,
   output                                  busy,    
   output   [N-1:0]                        grant 
);

   wire [N-1:0]           eligible;
   wire [N*PTR_WIDTH-1:0] ptr;
   wire                   check_done, queue_done, round_done0, round_done1, round_done;
   wire                   decoder_en;
   wire [PTR_WIDTH-1:0]   decoder_in;
   wire [N-1:0]           ptr_reset;

   wire                   fifo_wr_en;
   wire [PTR_WIDTH-1:0]   fifo_din;
   wire                   fifo_full;
   wire                   fifo_rd_en;
   wire [PTR_WIDTH-1:0]   fifo_dout;
   wire                   fifo_empty;

   reg start_round;
   reg busy_reg;
   reg [1:0] top_state;
   localparam T_IDLE = 2'b00, T_WAIT = 2'b01;

   always @(posedge clk) begin
       if (!resetn) begin
           top_state   <= T_IDLE;
           start_round <= 1'b0;
           busy_reg    <= 1'b0;
       end else begin
           case (top_state)
               T_IDLE: begin
                   if (|req) begin
                       start_round <= 1'b1;
                       busy_reg    <= 1'b1;
                       top_state   <= T_WAIT;
                   end else begin
                       start_round <= 1'b0;
                       busy_reg    <= 1'b0;
                   end
               end

               T_WAIT: begin
                   start_round <= 1'b0;
                   if (round_done) begin
                       if (|req) begin
                           start_round <= 1'b1; 
                       end else begin
                           top_state   <= T_IDLE;
                           busy_reg    <= 1'b0;
                       end
                   end
               end

               default: begin
                   top_state   <= T_IDLE;
                   start_round <= 1'b0;
                   busy_reg    <= 1'b0;
               end
           endcase
       end
   end

   assign busy = busy_reg;

   check #(
       .N(N), 
       .QUANTUM(QUANTUM), 
       .PACKET_SIZE_WIDTH(PACKET_SIZE_WIDTH), 
       .PTR_WIDTH(PTR_WIDTH)
   ) check (
       .clk(clk), 
       .resetn(resetn), 
       .start_round(start_round), 
       .req(req),
       .packet_size(packet_size), 
       .ptr_reset(ptr_reset),
       .eligible(eligible), 
       .ptr(ptr), 
       .check_done(check_done),
       .round_done(round_done0)
   );

   priority_queuer #(
       .N(N), 
       .PTR_WIDTH(PTR_WIDTH)
   ) priority (
       .clk(clk), 
       .resetn(resetn), 
       .check_done(check_done), 
       .eligible(eligible),
       .ptr(ptr), 
       .fifo_wr_en(fifo_wr_en),
       .fifo_din(fifo_din),
       .fifo_full(fifo_full),
       .sequence(),
       .queue_done(queue_done)
   );

   fifo #(
       .DATA_WIDTH(PTR_WIDTH),
       .DEPTH(10),
       .CNT_WIDTH(4)
   ) sequence_fifo (
       .clk(clk),
       .resetn(resetn),
       .wr_en(fifo_wr_en),
       .rd_en(fifo_rd_en),
       .din(fifo_din),
       .dout(fifo_dout),
       .full(fifo_full),
       .empty(fifo_empty)
   );

   grant_ctrl #(
       .N(N),
       .PTR_WIDTH(PTR_WIDTH)
   ) grant_ctrl (
       .clk(clk), 
       .resetn(resetn), 
       .fifo_empty(fifo_empty),
       .fifo_dout(fifo_dout),
       .queue_done(queue_done),
       .fifo_rd_en(fifo_rd_en),
       .decoder_en(decoder_en),
       .decoder_in(decoder_in), 
       .ptr_reset(ptr_reset),
       .round_done(round_done1)
   );

   decoder #(
       .N(N), 
       .PTR_WIDTH(PTR_WIDTH)
   ) decoder (
       .enable(decoder_en), 
       .in(decoder_in), 
       .out(grant)
   );

   assign round_done = round_done0 | round_done1;
endmodule
