//==============================================================================
// File Name   : TbAsyncFifo.sv
// Project     : Async FIFO
// Author      : Beomjun Kim
// Description : Self-checking directed testbench for AsyncFifo.
// Notes       : Write and read clocks use different periods, and a queue-based
//               scoreboard checks ordering across the clock-domain boundary.
//==============================================================================

`timescale 1ns / 1ps

//==============================================================================
// Testbench Interface
//==============================================================================

interface AsyncFifoIf #(
    parameter int DATA_WIDTH = 8
);
    logic                  i_wclk;
    logic                  i_wrst_n;
    logic                  i_winc;
    logic [DATA_WIDTH-1:0] i_wdata;
    logic                  o_wfull;
    logic                  i_rclk;
    logic                  i_rrst_n;
    logic                  i_rinc;
    logic [DATA_WIDTH-1:0] o_rdata;
    logic                  o_rempty;
endinterface

module TbAsyncFifo;

    //==============================================================================
    // Testbench Parameters And State
    //==============================================================================

    localparam int DATA_WIDTH = 8;
    localparam int FIFO_ADDR  = 4;
    localparam int DEPTH      = 1 << FIFO_ADDR;

    //==============================================================================
    // Interface Instance
    //==============================================================================

    AsyncFifoIf #(
        .DATA_WIDTH (DATA_WIDTH)
    ) fifo_if ();

    logic [DATA_WIDTH-1:0] r_expected_queue [$];
    int unsigned r_error_count;
    int unsigned r_read_count;

    //==============================================================================
    // DUT Instantiation
    //==============================================================================

    AsyncFifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_ADDR  (FIFO_ADDR)
    ) u_dut (
        .i_wclk   (fifo_if.i_wclk),
        .i_wrst_n (fifo_if.i_wrst_n),
        .i_winc   (fifo_if.i_winc),
        .i_wdata  (fifo_if.i_wdata),
        .o_wfull  (fifo_if.o_wfull),
        .i_rclk   (fifo_if.i_rclk),
        .i_rrst_n (fifo_if.i_rrst_n),
        .i_rinc   (fifo_if.i_rinc),
        .o_rdata  (fifo_if.o_rdata),
        .o_rempty (fifo_if.o_rempty)
    );

    //==============================================================================
    // Clock Generation
    //==============================================================================

    initial begin
        fifo_if.i_wclk = 1'b0;
        forever #5 fifo_if.i_wclk = ~fifo_if.i_wclk;
    end

    initial begin
        fifo_if.i_rclk = 1'b0;
        forever #11 fifo_if.i_rclk = ~fifo_if.i_rclk;
    end

    //==============================================================================
    // Test Sequence
    //==============================================================================

    initial begin
        init_interface();
        apply_reset();
        run_fill_case();
        run_drain_case();
        run_interleaved_case();
        report_summary();
    end

    //==============================================================================
    // Initialization And Reset Tasks
    //==============================================================================

    task automatic init_interface();
        begin
            fifo_if.i_wrst_n = 1'b1;
            fifo_if.i_rrst_n = 1'b1;
            fifo_if.i_winc   = 1'b0;
            fifo_if.i_rinc   = 1'b0;
            fifo_if.i_wdata  = '0;
            r_error_count    = 0;
            r_read_count     = 0;
            r_expected_queue.delete();
        end
    endtask

    task automatic apply_reset();
        begin
            fifo_if.i_wrst_n = 1'b0;
            fifo_if.i_rrst_n = 1'b0;
            repeat (4) @(posedge fifo_if.i_wclk);
            fifo_if.i_wrst_n = 1'b1;
            fifo_if.i_rrst_n = 1'b1;
            repeat (4) @(posedge fifo_if.i_wclk);
        end
    endtask

    //==============================================================================
    // Bus Driver Tasks
    //==============================================================================

    task automatic write_data(input logic [DATA_WIDTH-1:0] data);
        begin
            @(posedge fifo_if.i_wclk);
            if (!fifo_if.o_wfull) begin
                fifo_if.i_wdata <= data;
                fifo_if.i_winc  <= 1'b1;
                r_expected_queue.push_back(data);
            end else begin
                fifo_if.i_winc <= 1'b0;
                $display("[INFO] Write skipped because FIFO is full");
            end

            @(posedge fifo_if.i_wclk);
            fifo_if.i_winc <= 1'b0;
        end
    endtask

    task automatic read_one();
        begin
            @(posedge fifo_if.i_rclk);
            fifo_if.i_rinc <= !fifo_if.o_rempty;
            @(posedge fifo_if.i_rclk);
            fifo_if.i_rinc <= 1'b0;
        end
    endtask

    //==============================================================================
    // Directed Test Scenarios
    //==============================================================================

    task automatic run_fill_case();
        logic [DATA_WIDTH-1:0] write_value;

        begin
            for (int i = 0; i < DEPTH; i = i + 1) begin
                write_value = i[DATA_WIDTH-1:0];
                write_data(write_value);
            end

            repeat (6) @(posedge fifo_if.i_wclk);
            if (!fifo_if.o_wfull) begin
                $display("[FAIL] FIFO did not assert full after %0d writes", DEPTH);
                r_error_count++;
            end else begin
                $display("[PASS] FIFO full asserted");
            end
        end
    endtask

    task automatic run_drain_case();
        begin
            while (r_read_count < DEPTH) begin
                read_one();
            end

            repeat (6) @(posedge fifo_if.i_rclk);
            if (!fifo_if.o_rempty) begin
                $display("[FAIL] FIFO did not assert empty after drain");
                r_error_count++;
            end else begin
                $display("[PASS] FIFO empty asserted");
            end
        end
    endtask

    task automatic run_interleaved_case();
        logic [DATA_WIDTH-1:0] write_value;

        begin
            for (int i = 0; i < 8; i = i + 1) begin
                write_value = 8'h80 + i[DATA_WIDTH-1:0];
                write_data(write_value);
                if ((i % 2) == 1) begin
                    read_one();
                end
            end

            while (r_expected_queue.size() != 0) begin
                read_one();
            end
        end
    endtask

    //==============================================================================
    // Scoreboard Monitor
    //==============================================================================

    always_ff @(posedge fifo_if.i_rclk or negedge fifo_if.i_rrst_n) begin
        if (!fifo_if.i_rrst_n) begin
            r_read_count <= 0;
        end else if (fifo_if.i_rinc && !fifo_if.o_rempty) begin
            if (r_expected_queue.size() == 0) begin
                $display("[FAIL] Unexpected FIFO read data=0x%02h", fifo_if.o_rdata);
                r_error_count++;
            end else begin
                logic [DATA_WIDTH-1:0] expected;

                expected = r_expected_queue.pop_front();
                if (fifo_if.o_rdata != expected) begin
                    $display("[FAIL] FIFO read mismatch expected=0x%02h actual=0x%02h",
                             expected,
                             fifo_if.o_rdata);
                    r_error_count++;
                end else begin
                    $display("[PASS] FIFO read data=0x%02h", fifo_if.o_rdata);
                end
            end

            r_read_count <= r_read_count + 1;
        end
    end

    //==============================================================================
    // Summary Reporting
    //==============================================================================

    task automatic report_summary();
        begin
            if (r_error_count == 0) begin
                $display("PASS: AsyncFifo scenarios completed");
                $finish(0);
            end else begin
                $display("FAIL: error_count=%0d", r_error_count);
                $finish(1);
            end
        end
    endtask

endmodule
