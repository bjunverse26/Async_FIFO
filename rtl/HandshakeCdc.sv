//==============================================================================
// File Name   : HandshakeCdc.sv
// Project     : Async FIFO
// Author      : Beomjun Kim
// Description : Single-word request/acknowledge clock-domain crossing helper.
// Notes       : The source holds data stable while request is high; the
//               destination captures once and returns acknowledge to release the
//               source-side request.
//==============================================================================

`timescale 1ns / 1ps

module HandshakeCdc #(
    parameter int DATA_WIDTH = 8
) (
    input  logic                     i_clk_src,
    input  logic                     i_rstn_src,
    input  logic                     i_valid_src,
    input  logic [DATA_WIDTH-1:0]    i_data,

    input  logic                     i_clk_dst,
    input  logic                     i_rstn_dst,
    output logic                     o_valid_dst,
    output logic [DATA_WIDTH-1:0]    o_data
);

    logic [DATA_WIDTH-1:0] r_data_hold;
    logic                  r_request_src;
    logic                  r_ack_dst;
    logic                  r_sync1_request_src;
    logic                  r_sync2_request_src;
    logic                  r_sync1_ack_dst;
    logic                  r_sync2_ack_dst;

    always_ff @(posedge i_clk_src or negedge i_rstn_src) begin
        if (!i_rstn_src) begin
            r_data_hold   <= '0;
            r_request_src <= 1'b0;
        end else if (!r_request_src && i_valid_src) begin
            r_data_hold   <= i_data;
            r_request_src <= 1'b1;
        end else if (r_request_src && r_sync2_ack_dst) begin
            r_request_src <= 1'b0;
        end
    end

    always_ff @(posedge i_clk_dst or negedge i_rstn_dst) begin
        if (!i_rstn_dst) begin
            r_sync1_request_src <= 1'b0;
            r_sync2_request_src <= 1'b0;
        end else begin
            r_sync1_request_src <= r_request_src;
            r_sync2_request_src <= r_sync1_request_src;
        end
    end

    always_ff @(posedge i_clk_dst or negedge i_rstn_dst) begin
        if (!i_rstn_dst) begin
            o_valid_dst <= 1'b0;
            o_data      <= '0;
            r_ack_dst   <= 1'b0;
        end else begin
            o_valid_dst <= 1'b0;

            if (!r_ack_dst && r_sync2_request_src) begin
                o_valid_dst <= 1'b1;
                o_data      <= r_data_hold;
                r_ack_dst   <= 1'b1;
            end else if (!r_sync2_request_src) begin
                r_ack_dst <= 1'b0;
            end
        end
    end

    always_ff @(posedge i_clk_src or negedge i_rstn_src) begin
        if (!i_rstn_src) begin
            r_sync1_ack_dst <= 1'b0;
            r_sync2_ack_dst <= 1'b0;
        end else begin
            r_sync1_ack_dst <= r_ack_dst;
            r_sync2_ack_dst <= r_sync1_ack_dst;
        end
    end

endmodule
