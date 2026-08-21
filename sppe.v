`timescale 1ns / 1ps

module sppe #(
    parameter N = 16,
    parameter MODULUS = 12289
)(
    input  wire        Clk,
    input  wire        Reset,
    input  wire        Start,
    input  wire        input_valid,
    input  wire [15:0] input_coeff_data,
    input  wire        operand_sel,        // 0: Poly A, 1: Poly B
    output reg  [15:0] output_coeff_data,
    output reg         output_valid,
    output reg         busy,
    output reg         done
);

    reg [15:0] a_mem [0:N-1];
    reg [15:0] b_mem [0:N-1];
    reg [15:0] c_mem [0:N-1];

    reg [3:0] in_idx_a;
    reg [3:0] in_idx_b;
    reg [3:0] i_idx, j_idx;
    reg [4:0] out_idx;
    reg [31:0] accum;

    localparam IDLE    = 3'd0,
               COMPUTE = 3'd1,
               REDUCE  = 3'd2,
               STREAM  = 3'd3,
               FINISH  = 3'd4;

    reg [2:0] state;

    always @(posedge Clk or posedge Reset) begin
        if (Reset) begin
            in_idx_a <= 4'd0;
            in_idx_b <= 4'd0;
        end else if (input_valid && !busy) begin
            if (operand_sel == 1'b0) begin
                a_mem[in_idx_a] <= input_coeff_data % MODULUS;
                in_idx_a <= in_idx_a + 1'b1;
            end else begin
                b_mem[in_idx_b] <= input_coeff_data % MODULUS;
                in_idx_b <= in_idx_b + 1'b1;
            end
        end
    end

    always @(posedge Clk or posedge Reset) begin
        if (Reset) begin
            state             <= IDLE;
            busy              <= 1'b0;
            done              <= 1'b0;
            output_valid      <= 1'b0;
            output_coeff_data <= 16'd0;
            i_idx             <= 4'd0;
            j_idx             <= 4'd0;
            out_idx           <= 5'd0;
            accum             <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done         <= 1'b0;
                    output_valid <= 1'b0;
                    if (Start) begin
                        busy    <= 1'b1;
                        i_idx   <= 4'd0;
                        j_idx   <= 4'd0;
                        accum   <= 32'd0;
                        state   <= COMPUTE;
                    end else begin
                        busy    <= 1'b0;
                    end
                end

                COMPUTE: begin
                    if (j_idx <= i_idx) begin
                        accum <= accum + (a_mem[j_idx] * b_mem[i_idx - j_idx]);
                    end else begin
                        accum <= accum + ((MODULUS - a_mem[j_idx]) * b_mem[N + i_idx - j_idx]);
                    end

                    if (j_idx == N - 1) begin
                        j_idx <= 4'd0;
                        state <= REDUCE;
                    end else begin
                        j_idx <= j_idx + 1'b1;
                    end
                end

                REDUCE: begin
                    c_mem[i_idx] <= accum % MODULUS;
                    accum        <= 32'd0;
                    if (i_idx == N - 1) begin
                        out_idx <= 5'd0;
                        state   <= STREAM;
                    end else begin
                        i_idx   <= i_idx + 1'b1;
                        state   <= COMPUTE;
                    end
                end

                STREAM: begin
                    if (out_idx < N) begin
                        output_coeff_data <= c_mem[out_idx[3:0]];
                        output_valid      <= 1'b1;
                        out_idx           <= out_idx + 1'b1;
                    end else begin
                        output_valid      <= 1'b0;
                        done              <= 1'b1;
                        state             <= FINISH;
                    end
                end

                FINISH: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule