//==============================================================================
// File Name   : FifoMem.sv
// Project     : Async FIFO
// Author      : Beomjun Kim
// Description : Dual-port storage array for the asynchronous FIFO.
// Notes       : Writes are synchronous to the write clock while reads are
//               combinational so the pointer logic controls empty/full safety.
//==============================================================================

`timescale 1ns / 1ps

module FifoMem #(
    parameter int DATA_WIDTH = 8,
    parameter int FIFO_ADDR  = 4
) (
    input  logic                         i_wclk,
    input  logic                         i_winc,
    input  logic                         i_wfull,
    input  logic [FIFO_ADDR-1:0]         i_waddr,
    input  logic [DATA_WIDTH-1:0]        i_wdata,
    input  logic [FIFO_ADDR-1:0]         i_raddr,
    output logic [DATA_WIDTH-1:0]        o_rdata
);

    localparam int FIFO_DEPTH = 1 << FIFO_ADDR;

    logic [DATA_WIDTH-1:0] r_mem [0:FIFO_DEPTH-1];

    always_ff @(posedge i_wclk) begin
        if (i_winc && !i_wfull) begin
            r_mem[i_waddr] <= i_wdata;
        end
    end

    assign o_rdata = r_mem[i_raddr];

endmodule
