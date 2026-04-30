//==============================================================================
// File Name   : RptrEmpty.sv
// Project     : Async FIFO
// Author      : Beomjun Kim
// Description : Read-domain binary/Gray pointer generator and empty detector.
// Notes       : Empty is predicted from the next Gray pointer so the read side
//               blocks reads that would move beyond synchronized write data.
//==============================================================================

`timescale 1ns / 1ps

module RptrEmpty #(
    parameter int FIFO_ADDR = 4
) (
    input  logic                     i_rclk,
    input  logic                     i_rrst_n,
    input  logic                     i_rinc,
    input  logic [FIFO_ADDR:0]       i_sync_wptr,
    output logic [FIFO_ADDR-1:0]     o_raddr,
    output logic [FIFO_ADDR:0]       o_rptr,
    output logic                     o_rempty
);

    logic [FIFO_ADDR:0] r_rbin;
    logic [FIFO_ADDR:0] w_rbin_next;
    logic [FIFO_ADDR:0] w_rgray_next;
    logic               w_rempty_next;

    assign w_rbin_next   = r_rbin + (i_rinc && !o_rempty);
    assign w_rgray_next  = (w_rbin_next >> 1) ^ w_rbin_next;
    assign o_raddr       = r_rbin[FIFO_ADDR-1:0];
    assign w_rempty_next = (w_rgray_next == i_sync_wptr);

    always_ff @(posedge i_rclk or negedge i_rrst_n) begin
        if (!i_rrst_n) begin
            r_rbin <= '0;
            o_rptr <= '0;
        end else begin
            r_rbin <= w_rbin_next;
            o_rptr <= w_rgray_next;
        end
    end

    always_ff @(posedge i_rclk or negedge i_rrst_n) begin
        if (!i_rrst_n) begin
            o_rempty <= 1'b1;
        end else begin
            o_rempty <= w_rempty_next;
        end
    end

endmodule
