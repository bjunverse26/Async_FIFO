//==============================================================================
// File Name   : AsyncFifo.sv
// Project     : Async FIFO
// Author      : Beomjun Kim
// Description : Dual-clock asynchronous FIFO using Gray-coded read/write
//               pointers and two-flop pointer synchronizers.
// Notes       : Only Gray pointers cross clock domains, reducing multi-bit CDC
//               ambiguity while preserving binary addressing locally.
//==============================================================================

`timescale 1ns / 1ps

module AsyncFifo #(
    parameter int DATA_WIDTH = 8,
    parameter int FIFO_ADDR  = 4
) (
    input  logic                         i_wclk,
    input  logic                         i_wrst_n,
    input  logic                         i_winc,
    input  logic [DATA_WIDTH-1:0]        i_wdata,
    output logic                         o_wfull,

    input  logic                         i_rclk,
    input  logic                         i_rrst_n,
    input  logic                         i_rinc,
    output logic [DATA_WIDTH-1:0]        o_rdata,
    output logic                         o_rempty
);

    logic [FIFO_ADDR:0]   w_wptr;
    logic [FIFO_ADDR:0]   w_rptr;
    logic [FIFO_ADDR:0]   r_sync1_wptr;
    logic [FIFO_ADDR:0]   r_sync2_wptr;
    logic [FIFO_ADDR:0]   r_sync1_rptr;
    logic [FIFO_ADDR:0]   r_sync2_rptr;
    logic [FIFO_ADDR-1:0] w_waddr;
    logic [FIFO_ADDR-1:0] w_raddr;

    always_ff @(posedge i_rclk or negedge i_rrst_n) begin
        if (!i_rrst_n) begin
            r_sync1_wptr <= '0;
            r_sync2_wptr <= '0;
        end else begin
            r_sync1_wptr <= w_wptr;
            r_sync2_wptr <= r_sync1_wptr;
        end
    end

    always_ff @(posedge i_wclk or negedge i_wrst_n) begin
        if (!i_wrst_n) begin
            r_sync1_rptr <= '0;
            r_sync2_rptr <= '0;
        end else begin
            r_sync1_rptr <= w_rptr;
            r_sync2_rptr <= r_sync1_rptr;
        end
    end

    WptrFull #(
        .FIFO_ADDR (FIFO_ADDR)
    ) u_wptr_full (
        .i_wclk      (i_wclk),
        .i_wrst_n    (i_wrst_n),
        .i_winc      (i_winc),
        .i_sync_rptr (r_sync2_rptr),
        .o_waddr     (w_waddr),
        .o_wptr      (w_wptr),
        .o_wfull     (o_wfull)
    );

    RptrEmpty #(
        .FIFO_ADDR (FIFO_ADDR)
    ) u_rptr_empty (
        .i_rclk      (i_rclk),
        .i_rrst_n    (i_rrst_n),
        .i_rinc      (i_rinc),
        .i_sync_wptr (r_sync2_wptr),
        .o_raddr     (w_raddr),
        .o_rptr      (w_rptr),
        .o_rempty    (o_rempty)
    );

    FifoMem #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_ADDR  (FIFO_ADDR)
    ) u_fifo_mem (
        .i_wclk  (i_wclk),
        .i_winc  (i_winc),
        .i_wfull (o_wfull),
        .i_waddr (w_waddr),
        .i_wdata (i_wdata),
        .i_raddr (w_raddr),
        .o_rdata (o_rdata)
    );

endmodule
