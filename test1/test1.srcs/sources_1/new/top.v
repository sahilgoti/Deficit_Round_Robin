`timescale 1ns / 1ps

module top #(
   parameter N = 4,
   parameter QUANTUM = 64,
   parameter PACKET_SIZE_WIDTH = 8
) (
   input                                   clk,     
   input                                   resetn,  
   input    [N-1:0]                        req,    
   input    [N*PACKET_SIZE_WIDTH-1:0]      packet_size,
   output                                  busy,    
   output   [N-1:0]                        grant 
);

   wire [N-1:0]   next_check;
   wire [N*2-1:0] ptr;
   wire           enable;
   wire [N-1:0]   reset_ptr;
   wire           flag1;

   check #(
       .N(N),
       .QUANTUM(QUANTUM),
       .PACKET_SIZE_WIDTH(PACKET_SIZE_WIDTH)
   ) check_inst (
       .clk(clk),
       .resetn(resetn),
       .req(req),
       .packet_size(packet_size),
       .reset_ptr(reset_ptr),
       .flag1(flag1),
       .next_check(next_check),
       .enable(enable),
       .ptr(ptr)
   );

   priority #(
       .N(N)
   ) priority_inst (
       .clk(clk),
       .resetn(resetn),
       .next_check(next_check),
       .ptr(ptr),
       .enable(enable),
       .grant(grant),
       .reset_ptr(reset_ptr),
       .flag1(flag1)
   );

   assign busy = enable & (|req);

endmodule