`timescale 1ns / 1ps

module sppe_tb;

    localparam N = 16;
    localparam MODULUS = 12289;

    reg         clk;
    reg         reset;
    reg         start;
    reg         input_valid;
    reg  [15:0] input_coeff_data;
    reg         operand_sel;

    wire [15:0] output_coeff_data;
    wire        output_valid;
    wire        busy;
    wire        done;

    sppe #(.N(N), .MODULUS(MODULUS)) uut (
        .Clk(clk),
        .Reset(reset),
        .Start(start),
        .input_valid(input_valid),
        .input_coeff_data(input_coeff_data),
        .operand_sel(operand_sel),
        .output_coeff_data(output_coeff_data),
        .output_valid(output_valid),
        .busy(busy),
        .done(done)
    );

    always #5 clk = ~clk;

    integer k;
    reg [15:0] test_a [0:15];
    reg [15:0] test_b [0:15];

    initial begin
        $dumpfile("sppe.vcd");
        $dumpvars(0, sppe_tb);  // Use the exact module name of your testbench
        clk = 0;
        reset = 1;
        start = 0;
        input_valid = 0;
        input_coeff_data = 0;
        operand_sel = 0;

        // Initialize test vectors: A = [1, 2, ..., 16], B = [1, 0, 0, ..., 0] (Identity)
        for (k = 0; k < 16; k = k + 1) begin
            test_a[k] = k + 1;
            test_b[k] = (k == 0) ? 16'd1 : 16'd0;
        end

        #20 reset = 0;
        #10;

        // Load Polynomial A
        for (k = 0; k < 16; k = k + 1) begin
            @(posedge clk);
            operand_sel = 1'b0;
            input_valid = 1'b1;
            input_coeff_data = test_a[k];
        end

        // Load Polynomial B
        for (k = 0; k < 16; k = k + 1) begin
            @(posedge clk);
            operand_sel = 1'b1;
            input_valid = 1'b1;
            input_coeff_data = test_b[k];
        end

        @(posedge clk);
        input_valid = 1'b0;

        // Trigger Multiplication
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Monitor & Verify
        wait(done);
        #30;
        $display(">> Test Completed Successfully!");
        $finish;
    end

    always @(posedge clk) begin
        if (output_valid) begin
            $display("[OUTPUT] Coeff received: %0d", output_coeff_data);
        end
    end

endmodule