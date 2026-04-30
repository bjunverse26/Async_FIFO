//==============================================================================
// File Name   : WptrFull.sv
// Project     : Async FIFO
// Author      : Beomjun Kim
// Description : Write-domain binary/Gray pointer generator and full detector.
// Notes       : Full is predicted from the next Gray pointer so the write side
//               blocks the write that would otherwise collide with unread data.
//==============================================================================

`timescale 1ns / 1ps

module WptrFull #(
    parameter int FIFO_ADDR = 4
) (
    input  logic                     i_wclk,
    input  logic                     i_wrst_n,
    input  logic                     i_winc,
    input  logic [FIFO_ADDR:0]       i_sync_rptr,
    output logic [FIFO_ADDR-1:0]     o_waddr,
    output logic [FIFO_ADDR:0]       o_wptr,
    output logic                     o_wfull
);

    logic [FIFO_ADDR:0] r_wbin;
    logic [FIFO_ADDR:0] w_wbin_next;
    logic [FIFO_ADDR:0] w_wgray_next;
    logic               w_wfull_next;

    assign w_wbin_next  = r_wbin + (i_winc && !o_wfull);
    assign w_wgray_next = (w_wbin_next >> 1) ^ w_wbin_next;
    assign o_waddr      = r_wbin[FIFO_ADDR-1:0];

    assign w_wfull_next = (w_wgray_next[FIFO_ADDR]     != i_sync_rptr[FIFO_ADDR])
                        && (w_wgray_next[FIFO_ADDR-1] != i_sync_rptr[FIFO_ADDR-1])
                        && (w_wgray_next[FIFO_ADDR-2:0] == i_sync_rptr[FIFO_ADDR-2:0]);

    always_ff @(posedge i_wclk or negedge i_wrst_n) begin
        if (!i_wrst_n) begin
            r_wbin <= '0;
            o_wptr <= '0;
        end else begin
            r_wbin <= w_wbin_next;
            o_wptr <= w_wgray_next;
        end
    end

    always_ff @(posedge i_wclk or negedge i_wrst_n) begin
        if (!i_wrst_n) begin
            o_wfull <= 1'b0;
        end else begin
            o_wfull <= w_wfull_next;
        end
    end

endmodule
