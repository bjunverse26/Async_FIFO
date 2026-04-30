//==============================================================================
// File Name   : TbHandshakeCdc.sv
// Project     : Async FIFO
// Author      : Beomjun Kim
// Description : Self-checking directed testbench for HandshakeCdc.
// Notes       : Source and destination clocks are intentionally different so the
//               request/acknowledge synchronizers are exercised.
//==============================================================================

`timescale 1ns / 1ps

interface HandshakeCdcIf #(
    parameter int DATA_WIDTH = 8
);
    logic                  i_clk_src;
    logic                  i_rstn_src;
    logic                  i_valid_src;
    logic [DATA_WIDTH-1:0] i_data;
    logic                  i_clk_dst;
    logic                  i_rstn_dst;
    logic                  o_valid_dst;
    logic [DATA_WIDTH-1:0] o_data;
endinterface

module TbHandshakeCdc;

    localparam int DATA_WIDTH = 8;

    HandshakeCdcIf #(
        .DATA_WIDTH (DATA_WIDTH)
    ) cdc_if ();

    logic [DATA_WIDTH-1:0] r_expected_queue [$];
    int unsigned r_error_count;
    int unsigned r_receive_count;

    HandshakeCdc #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_dut (
        .i_clk_src    (cdc_if.i_clk_src),
        .i_rstn_src   (cdc_if.i_rstn_src),
        .i_valid_src  (cdc_if.i_valid_src),
        .i_data       (cdc_if.i_data),
        .i_clk_dst    (cdc_if.i_clk_dst),
        .i_rstn_dst   (cdc_if.i_rstn_dst),
        .o_valid_dst  (cdc_if.o_valid_dst),
        .o_data       (cdc_if.o_data)
    );

    initial begin
        cdc_if.i_clk_src = 1'b0;
        forever #5 cdc_if.i_clk_src = ~cdc_if.i_clk_src;
    end

    initial begin
        cdc_if.i_clk_dst = 1'b0;
        forever #11 cdc_if.i_clk_dst = ~cdc_if.i_clk_dst;
    end

    initial begin
        init_interface();
        apply_reset();
        send_word(8'hA5);
        send_word(8'h3C);
        send_word(8'hF0);
        wait_for_receives(3);
        report_summary();
    end

    task automatic init_interface();
        begin
            cdc_if.i_rstn_src  = 1'b1;
            cdc_if.i_rstn_dst  = 1'b1;
            cdc_if.i_valid_src = 1'b0;
            cdc_if.i_data      = '0;
            r_error_count      = 0;
            r_receive_count    = 0;
            r_expected_queue.delete();
        end
    endtask

    task automatic apply_reset();
        begin
            cdc_if.i_rstn_src = 1'b0;
            cdc_if.i_rstn_dst = 1'b0;
            repeat (4) @(posedge cdc_if.i_clk_src);
            cdc_if.i_rstn_src = 1'b1;
            cdc_if.i_rstn_dst = 1'b1;
            repeat (2) @(posedge cdc_if.i_clk_src);
        end
    endtask

    task automatic send_word(input logic [DATA_WIDTH-1:0] data);
        begin
            r_expected_queue.push_back(data);
            @(posedge cdc_if.i_clk_src);
            cdc_if.i_data      <= data;
            cdc_if.i_valid_src <= 1'b1;
            @(posedge cdc_if.i_clk_src);
            cdc_if.i_valid_src <= 1'b0;
            repeat (8) @(posedge cdc_if.i_clk_src);
        end
    endtask

    task automatic wait_for_receives(input int unsigned expected_count);
        int unsigned timeout;

        begin
            timeout = 0;
            while ((r_receive_count < expected_count) && (timeout < 200)) begin
                @(posedge cdc_if.i_clk_dst);
                timeout++;
            end

            if (r_receive_count != expected_count) begin
                $display("[FAIL] Receive timeout count=%0d expected=%0d",
                         r_receive_count,
                         expected_count);
                r_error_count++;
            end
        end
    endtask

    always_ff @(posedge cdc_if.i_clk_dst or negedge cdc_if.i_rstn_dst) begin
        if (!cdc_if.i_rstn_dst) begin
            r_receive_count <= 0;
        end else if (cdc_if.o_valid_dst) begin
            if (r_expected_queue.size() == 0) begin
                $display("[FAIL] Unexpected CDC output data=0x%02h", cdc_if.o_data);
                r_error_count++;
            end else begin
                logic [DATA_WIDTH-1:0] expected;

                expected = r_expected_queue.pop_front();
                if (cdc_if.o_data != expected) begin
                    $display("[FAIL] CDC data mismatch expected=0x%02h actual=0x%02h",
                             expected,
                             cdc_if.o_data);
                    r_error_count++;
                end else begin
                    $display("[PASS] CDC data received 0x%02h", cdc_if.o_data);
                end
            end

            r_receive_count <= r_receive_count + 1;
        end
    end

    task automatic report_summary();
        begin
            if (r_error_count == 0) begin
                $display("PASS: HandshakeCdc scenarios completed");
                $finish(0);
            end else begin
                $display("FAIL: error_count=%0d", r_error_count);
                $finish(1);
            end
        end
    endtask

endmodule
