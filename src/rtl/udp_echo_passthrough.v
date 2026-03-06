`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/27/2026 08:51:01 PM
// Design Name: 
// Module Name: udp_echo_passthrough
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module udp_echo_passthrough (
    input  wire        clk,
    input  wire        rst,

    // UDP RX from ethernet_io_top
    input  wire        udp_rx_hdr_valid,
    output wire        udp_rx_hdr_ready,
    input  wire [31:0] udp_rx_src_ip,
    input  wire [15:0] udp_rx_src_port,
    input  wire [15:0] udp_rx_dest_port,
    input  wire [7:0]  udp_rx_tdata,
    input  wire        udp_rx_tvalid,
    output wire        udp_rx_tready,
    input  wire        udp_rx_tlast,

    // UDP TX to ethernet_io_top
    output wire        udp_tx_hdr_valid,
    input  wire        udp_tx_hdr_ready,
    output wire [31:0] udp_tx_dest_ip,
    output wire [15:0] udp_tx_src_port,
    output wire [15:0] udp_tx_dest_port,
    output wire [7:0]  udp_tx_tdata,
    output wire        udp_tx_tvalid,
    input  wire        udp_tx_tready,
    output wire        udp_tx_tlast
);

    // ========================================================================
    // Simple Echo Logic: RX -> TX with port swapping
    // ========================================================================
    // Mirror header
    assign udp_tx_hdr_valid = udp_rx_hdr_valid;
    assign udp_rx_hdr_ready = udp_tx_hdr_ready;

    // Swap source and destination (echo back to sender)
    assign udp_tx_dest_ip   = udp_rx_src_ip;
    assign udp_tx_src_port  = udp_rx_dest_port;
    assign udp_tx_dest_port = udp_rx_src_port;

    // Mirror payload bytes
    assign udp_tx_tdata  = udp_rx_tdata;
    assign udp_tx_tvalid = udp_rx_tvalid;
    assign udp_rx_tready = udp_tx_tready;
    assign udp_tx_tlast  = udp_rx_tlast;

endmodule

