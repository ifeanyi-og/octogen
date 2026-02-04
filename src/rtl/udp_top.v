`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2026 08:46:05 PM
// Design Name: 
// Module Name: udp_top
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

module udp_top (
    input  wire        axis_clk,
    input  wire        axis_rst,

    // PHY pins
    input  wire [3:0]  rgmii_rd,
    input  wire        rgmii_rx_ctl,
    input  wire        rgmii_rxc,
    output wire [3:0]  rgmii_td,
    output wire        rgmii_tx_ctl,
    output wire        rgmii_txc,

    // Clocks
    input  wire        gtx_clk,
    input  wire        ref_clk,

    // UDP RX (network → user logic)
    output wire        udp_rx_hdr_valid,
    input  wire        udp_rx_hdr_ready,
    output wire [31:0] udp_rx_src_ip,
    output wire [15:0] udp_rx_src_port,
    output wire [15:0] udp_rx_dest_port,
    output wire [7:0]  udp_rx_tdata,
    output wire        udp_rx_tvalid,
    input  wire        udp_rx_tready,
    output wire        udp_rx_tlast,
    
    // UDP TX (user logic → network)
    input  wire        udp_tx_hdr_valid,
    output wire        udp_tx_hdr_ready,
    input  wire [31:0] udp_tx_dest_ip,
    input  wire [15:0] udp_tx_src_port,
    input  wire [15:0] udp_tx_dest_port,
    input  wire [7:0]  udp_tx_tdata,
    input  wire        udp_tx_tvalid,
    output wire        udp_tx_tready,
    input  wire        udp_tx_tlast
);

    // ----------------------------------------------------------------
    // Local configuration
    // ----------------------------------------------------------------
    localparam [47:0] LOCAL_MAC    = 48'h02_00_00_00_00_01;
    localparam [31:0] LOCAL_IP     = {8'd192,8'd168,8'd1,8'd50};
    localparam [31:0] GATEWAY_IP   = {8'd192,8'd168,8'd1,8'd1};
    localparam [31:0] SUBNET_MASK  = {8'd255,8'd255,8'd255,8'd0};

    // ----------------------------------------------------------------
    // Internal AXIS signals (MAC side, 32-bit)
    // ----------------------------------------------------------------
    wire [31:0] mac_rx_tdata;
    wire [3:0]  mac_rx_tkeep;
    wire        mac_rx_tvalid;
    wire        mac_rx_tready;
    wire        mac_rx_tlast;

    wire [31:0] mac_tx_tdata;
    wire [3:0]  mac_tx_tkeep;
    wire        mac_tx_tvalid;
    wire        mac_tx_tready;
    wire        mac_tx_tlast;

    // ----------------------------------------------------------------
    // Internal AXIS signals (UDP stack side, 8-bit)
    // ----------------------------------------------------------------
    wire [7:0]  rx8_tdata;
    wire        rx8_tvalid;
    wire        rx8_tready;
    wire        rx8_tlast;

    wire [7:0]  tx8_tdata;
    wire        tx8_tvalid;
    wire        tx8_tready;
    wire        tx8_tlast;
    wire        tx8_tkeep;

    // ----------------------------------------------------------------
    // Ethernet BD wrapper (AXI 1G/2.5G subsystem wrapper)
    // AXI-Lite + TXC are tied off here
    // ----------------------------------------------------------------
    wire        s_axi_0_arready;
    wire        s_axi_0_awready;
    wire        s_axi_0_bvalid;
    wire [1:0]  s_axi_0_bresp;
    wire [31:0] s_axi_0_rdata;
    wire        s_axi_0_rvalid;
    wire [1:0]  s_axi_0_rresp;
    wire        s_axi_0_wready;
    wire [0:0]  phy_rst_n_0;

    ethernet eth_inst (
        .axis_clk_0(axis_clk),
        .gtx_clk_0(gtx_clk),

        // RX from PHY
        .m_axis_rxd_0_tdata (mac_rx_tdata),
        .m_axis_rxd_0_tkeep (mac_rx_tkeep),
        .m_axis_rxd_0_tlast (mac_rx_tlast),
        .m_axis_rxd_0_tready(mac_rx_tready),
        .m_axis_rxd_0_tvalid(mac_rx_tvalid),

        // TX to PHY
        .s_axis_txd_0_tdata (mac_tx_tdata),
        .s_axis_txd_0_tkeep (mac_tx_tkeep),
        .s_axis_txd_0_tlast (mac_tx_tlast),
        .s_axis_txd_0_tready(mac_tx_tready),
        .s_axis_txd_0_tvalid(mac_tx_tvalid),

        // PHY pins
        .rgmii_0_rd     (rgmii_rd),
        .rgmii_0_rx_ctl (rgmii_rx_ctl),
        .rgmii_0_rxc    (rgmii_rxc),
        .rgmii_0_td     (rgmii_td),
        .rgmii_0_tx_ctl (rgmii_tx_ctl),
        .rgmii_0_txc    (rgmii_txc),

        // Clocks
        .ref_clk_0      (ref_clk),

        // AXI-Lite (tied off)
        .s_axi_0_araddr (18'd0),
        .s_axi_0_arready(s_axi_0_arready),
        .s_axi_0_arvalid(1'b0),
        .s_axi_0_awaddr (18'd0),
        .s_axi_0_awready(s_axi_0_awready),
        .s_axi_0_awvalid(1'b0),
        .s_axi_0_bready (1'b0),
        .s_axi_0_bresp  (s_axi_0_bresp),
        .s_axi_0_bvalid (s_axi_0_bvalid),
        .s_axi_0_rdata  (s_axi_0_rdata),
        .s_axi_0_rready (1'b0),
        .s_axi_0_rresp  (s_axi_0_rresp),
        .s_axi_0_rvalid (s_axi_0_rvalid),
        .s_axi_0_wdata  (32'd0),
        .s_axi_0_wready (s_axi_0_wready),
        .s_axi_0_wstrb  (4'd0),
        .s_axi_0_wvalid (1'b0),
        .s_axi_lite_clk_0(axis_clk),

        // TXC valid (not used)
        .s_axis_txc_tvalid_0(1'b0),

        // PHY reset (unused)
        .phy_rst_n_0(phy_rst_n_0)
    );

    // ----------------------------------------------------------------
    // Width converter: 32 → 8 (RX path)
    // ----------------------------------------------------------------
    axis_dwidth_converter_32to8 rx_conv (
        .aclk          (axis_clk),
        .aresetn       (~axis_rst),

        .s_axis_tdata  (mac_rx_tdata),
        .s_axis_tkeep  (mac_rx_tkeep),
        .s_axis_tvalid (mac_rx_tvalid),
        .s_axis_tready (mac_rx_tready),
        .s_axis_tlast  (mac_rx_tlast),

        .m_axis_tdata  (rx8_tdata),
        .m_axis_tvalid (rx8_tvalid),
        .m_axis_tready (rx8_tready),
        .m_axis_tlast  (rx8_tlast)
    );

    // ----------------------------------------------------------------
    // Width converter: 8 → 32 (TX path)
    // ----------------------------------------------------------------
    axis_dwidth_converter_8to32 tx_conv (
        .aclk          (axis_clk),
        .aresetn       (~axis_rst),

        .s_axis_tdata  (tx8_tdata),
        .s_axis_tkeep  (tx8_tkeep),
        .s_axis_tvalid (tx8_tvalid),
        .s_axis_tready (tx8_tready),
        .s_axis_tlast  (tx8_tlast),

        .m_axis_tdata  (mac_tx_tdata),
        .m_axis_tkeep  (mac_tx_tkeep),
        .m_axis_tvalid (mac_tx_tvalid),
        .m_axis_tready (mac_tx_tready),
        .m_axis_tlast  (mac_tx_tlast)
    );

    // ----------------------------------------------------------------
    // UDP/IP stack
    // ----------------------------------------------------------------
    udp_complete udp_inst (
        .clk(axis_clk),
        .rst(axis_rst),

        // Ethernet frame input (from MAC RX stream, headers not parsed here)
        .s_eth_hdr_valid          (1'b0),
        .s_eth_hdr_ready          (),
        .s_eth_dest_mac           (48'd0),
        .s_eth_src_mac            (48'd0),
        .s_eth_type               (16'd0),
        .s_eth_payload_axis_tdata (rx8_tdata),
        .s_eth_payload_axis_tvalid(rx8_tvalid),
        .s_eth_payload_axis_tready(rx8_tready),
        .s_eth_payload_axis_tlast (rx8_tlast),
        .s_eth_payload_axis_tuser (1'b0),

        // Ethernet frame output (to MAC TX stream)
        .m_eth_hdr_valid          (),
        .m_eth_hdr_ready          (1'b1),
        .m_eth_dest_mac           (),
        .m_eth_src_mac            (),
        .m_eth_type               (),
        .m_eth_payload_axis_tdata (tx8_tdata),
        .m_eth_payload_axis_tvalid(tx8_tvalid),
        .m_eth_payload_axis_tready(tx8_tready),
        .m_eth_payload_axis_tlast (tx8_tlast),
        // .m_eth_payload_axis_tkeep (tx8_tkeep),
        .m_eth_payload_axis_tuser (),

        // IP input (unused)
        .s_ip_hdr_valid           (1'b0),
        .s_ip_hdr_ready           (),
        .s_ip_dscp                (6'd0),
        .s_ip_ecn                 (2'd0),
        .s_ip_length              (16'd0),
        .s_ip_ttl                 (8'd0),
        .s_ip_protocol            (8'd0),
        .s_ip_source_ip           (32'd0),
        .s_ip_dest_ip             (32'd0),
        .s_ip_payload_axis_tdata  (8'd0),
        .s_ip_payload_axis_tvalid (1'b0),
        .s_ip_payload_axis_tready (),
        .s_ip_payload_axis_tlast  (1'b0),
        .s_ip_payload_axis_tuser  (1'b0),

        // IP output (unused)
        .m_ip_hdr_valid           (),
        .m_ip_hdr_ready           (1'b1),
        .m_ip_eth_dest_mac        (),
        .m_ip_eth_src_mac         (),
        .m_ip_eth_type            (),
        .m_ip_version             (),
        .m_ip_ihl                 (),
        .m_ip_dscp                (),
        .m_ip_ecn                 (),
        .m_ip_length              (),
        .m_ip_identification      (),
        .m_ip_flags               (),
        .m_ip_fragment_offset     (),
        .m_ip_ttl                 (),
        .m_ip_protocol            (),
        .m_ip_header_checksum     (),
        .m_ip_source_ip           (),
        .m_ip_dest_ip             (),
        .m_ip_payload_axis_tdata  (),
        .m_ip_payload_axis_tvalid (),
        .m_ip_payload_axis_tready (1'b1),
        .m_ip_payload_axis_tlast  (),
        .m_ip_payload_axis_tuser  (),

        // UDP input (TX path from user)
        .s_udp_hdr_valid          (udp_tx_hdr_valid),
        .s_udp_hdr_ready          (udp_tx_hdr_ready),
        .s_udp_ip_dscp            (6'd0),
        .s_udp_ip_ecn             (2'd0),
        .s_udp_ip_ttl             (8'd64),
        .s_udp_ip_source_ip       (LOCAL_IP),
        .s_udp_ip_dest_ip         (udp_tx_dest_ip),
        .s_udp_source_port        (udp_tx_src_port),
        .s_udp_dest_port          (udp_tx_dest_port),
        .s_udp_length             (16'd0),
        .s_udp_checksum           (16'd0),
        .s_udp_payload_axis_tdata (udp_tx_tdata),
        .s_udp_payload_axis_tvalid(udp_tx_tvalid),
        .s_udp_payload_axis_tready(udp_tx_tready),
        .s_udp_payload_axis_tlast (udp_tx_tlast),
        .s_udp_payload_axis_tuser (1'b0),

        // UDP output (RX path to user)
        .m_udp_hdr_valid          (udp_rx_hdr_valid),
        .m_udp_hdr_ready          (udp_rx_hdr_ready),
        .m_udp_eth_dest_mac       (),
        .m_udp_eth_src_mac        (),
        .m_udp_eth_type           (),
        .m_udp_ip_version         (),
        .m_udp_ip_ihl             (),
        .m_udp_ip_dscp            (),
        .m_udp_ip_ecn             (),
        .m_udp_ip_length          (),
        .m_udp_ip_identification  (),
        .m_udp_ip_flags           (),
        .m_udp_ip_fragment_offset (),
        .m_udp_ip_ttl             (),
        .m_udp_ip_protocol        (),
        .m_udp_ip_header_checksum (),
        .m_udp_ip_source_ip       (udp_rx_src_ip),
        .m_udp_ip_dest_ip         (),
        .m_udp_source_port        (udp_rx_src_port),
        .m_udp_dest_port          (udp_rx_dest_port),
        .m_udp_length             (),
        .m_udp_checksum           (),
        .m_udp_payload_axis_tdata (udp_rx_tdata),
        .m_udp_payload_axis_tvalid(udp_rx_tvalid),
        .m_udp_payload_axis_tready(udp_rx_tready),
        .m_udp_payload_axis_tlast (udp_rx_tlast),
        .m_udp_payload_axis_tuser (),

        // Status (ignored)
        .ip_rx_busy                       (),
        .ip_tx_busy                       (),
        .udp_rx_busy                      (),
        .udp_tx_busy                      (),
        .ip_rx_error_header_early_termination (),
        .ip_rx_error_payload_early_termination(),
        .ip_rx_error_invalid_header       (),
        .ip_rx_error_invalid_checksum     (),
        .ip_tx_error_payload_early_termination(),
        .ip_tx_error_arp_failed           (),
        .udp_rx_error_header_early_termination(),
        .udp_rx_error_payload_early_termination(),
        .udp_tx_error_payload_early_termination(),

        // Configuration
        .local_mac     (LOCAL_MAC),
        .local_ip      (LOCAL_IP),
        .gateway_ip    (GATEWAY_IP),
        .subnet_mask   (SUBNET_MASK),
        .clear_arp_cache(1'b0)
    );

endmodule
