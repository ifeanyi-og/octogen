`timescale 1ns / 1ps

module eth_io_top (
    input  wire        reset_btn,

    // RGMII PHY pins
    input  wire [3:0]  rgmii_rd,
    input  wire        rgmii_rx_ctl,
    input  wire        rgmii_rxc,
    output wire [3:0]  rgmii_td,
    output wire        rgmii_tx_ctl,
    output wire        rgmii_txc,

    // Board clocks / reset
    input  wire        osc_clk,
    output wire        phy_rst_n,
    input  wire        clk_100mhz,
    input  wire        clk_125mhz,
    input  wire        clk_200mhz,
    input  wire        axis_reset,

    // -------------------------------------------------------------------------
    // UDP RX outputs to udp_processing_top
    // -------------------------------------------------------------------------
    output wire        udp_rx_hdr_valid,
    output wire [31:0] udp_rx_src_ip,
    output wire [15:0] udp_rx_src_port,
    output wire [15:0] udp_rx_dest_port,
    output wire [7:0]  udp_rx_tdata,
    output wire        udp_rx_tvalid,
    output wire        udp_rx_tlast,
    input  wire        udp_rx_hdr_ready,
    input  wire        udp_rx_tready,

    // -------------------------------------------------------------------------
    // UDP TX inputs from udp_processing_top
    // -------------------------------------------------------------------------
    input  wire        udp_tx_hdr_valid,
    input  wire [31:0] udp_tx_dest_ip,
    input  wire [15:0] udp_tx_src_port,
    input  wire [15:0] udp_tx_dest_port,
    input  wire [15:0] udp_tx_length,
    input  wire [7:0]  udp_tx_tdata,
    input  wire        udp_tx_tvalid,
    input  wire        udp_tx_tlast,
    output wire        udp_tx_hdr_ready,
    output wire        udp_tx_tready
);

    // =========================================================================
    // IDELAYCTRL for RGMII RX
    // =========================================================================
    (* IODELAY_GROUP = "rgmii_idly" *)
    IDELAYCTRL idelayctrl_inst (
        .RDY(),
        .REFCLK(clk_200mhz),
        .RST(axis_reset)
    );

    // =========================================================================
    // PHY reset delay
    // =========================================================================
    reg [7:0] rst_cnt = 8'd0;

    always @(posedge clk_100mhz) begin
        if (axis_reset)
            rst_cnt <= 8'd0;
        else if (rst_cnt != 8'hFF)
            rst_cnt <= rst_cnt + 8'd1;
    end

    assign phy_rst_n = (rst_cnt == 8'hFF);

    // =========================================================================
    // MAC AXI-stream wires
    // =========================================================================
    wire [7:0] mac_rx_tdata;
    wire       mac_rx_tvalid;
    wire       mac_rx_tready;
    wire       mac_rx_tlast;

    wire [7:0] mac_tx_tdata;
    wire       mac_tx_tvalid;
    wire       mac_tx_tready;
    wire       mac_tx_tlast;

    // =========================================================================
    // Ethernet MAC
    // =========================================================================
    eth_mac_1g_rgmii_fifo #(
        .TARGET("XILINX"),
        .IODDR_STYLE("IODDR2"),
        .CLOCK_INPUT_STYLE("BUFG"),
        .USE_CLK90("FALSE"),
        .ENABLE_PADDING(1),
        .MIN_FRAME_LENGTH(64),
        .TX_FIFO_DEPTH(4096),
        .TX_FRAME_FIFO(1),
        .RX_FIFO_DEPTH(4096),
        .RX_FRAME_FIFO(1)
    ) mac_inst (
        .gtx_clk(clk_125mhz),
        .gtx_clk90(1'b0),
        .gtx_rst(axis_reset),

        .logic_clk(clk_100mhz),
        .logic_rst(axis_reset),

        .tx_axis_tdata(mac_tx_tdata),
        .tx_axis_tkeep(1'b1),
        .tx_axis_tvalid(mac_tx_tvalid),
        .tx_axis_tready(mac_tx_tready),
        .tx_axis_tlast(mac_tx_tlast),
        .tx_axis_tuser(1'b0),

        .rx_axis_tdata(mac_rx_tdata),
        .rx_axis_tkeep(),
        .rx_axis_tvalid(mac_rx_tvalid),
        .rx_axis_tready(mac_rx_tready),
        .rx_axis_tlast(mac_rx_tlast),
        .rx_axis_tuser(),

        .rgmii_rx_clk(rgmii_rxc),
        .rgmii_rxd(rgmii_rd),
        .rgmii_rx_ctl(rgmii_rx_ctl),

        .rgmii_tx_clk(rgmii_txc),
        .rgmii_txd(rgmii_td),
        .rgmii_tx_ctl(rgmii_tx_ctl),

        .tx_error_underflow(),
        .tx_fifo_overflow(),
        .tx_fifo_bad_frame(),
        .tx_fifo_good_frame(),
        .rx_error_bad_frame(),
        .rx_error_bad_fcs(),
        .rx_fifo_overflow(),
        .rx_fifo_bad_frame(),
        .rx_fifo_good_frame(),
        .speed(),

        .cfg_ifg(8'd12),
        .cfg_tx_enable(1'b1),
        .cfg_rx_enable(1'b1)
    );

    // =========================================================================
    // Ethernet RX parser: MAC -> Ethernet header/payload
    // =========================================================================
    wire        s_eth_hdr_valid;
    wire        s_eth_hdr_ready;
    wire [47:0] s_eth_dest_mac;
    wire [47:0] s_eth_src_mac;
    wire [15:0] s_eth_type;

    wire [7:0]  s_eth_payload_tdata;
    wire        s_eth_payload_tvalid;
    wire        s_eth_payload_tready;
    wire        s_eth_payload_tlast;

    eth_axis_rx eth_rx_inst (
        .clk(clk_100mhz),
        .rst(axis_reset),

        .s_axis_tdata(mac_rx_tdata),
        .s_axis_tvalid(mac_rx_tvalid),
        .s_axis_tready(mac_rx_tready),
        .s_axis_tlast(mac_rx_tlast),
        .s_axis_tuser(1'b0),

        .m_eth_hdr_valid(s_eth_hdr_valid),
        .m_eth_hdr_ready(s_eth_hdr_ready),
        .m_eth_dest_mac(s_eth_dest_mac),
        .m_eth_src_mac(s_eth_src_mac),
        .m_eth_type(s_eth_type),

        .m_eth_payload_axis_tdata(s_eth_payload_tdata),
        .m_eth_payload_axis_tvalid(s_eth_payload_tvalid),
        .m_eth_payload_axis_tready(s_eth_payload_tready),
        .m_eth_payload_axis_tlast(s_eth_payload_tlast),
        .m_eth_payload_axis_tuser()
    );

    // =========================================================================
    // Ethernet TX packer: Ethernet header/payload -> MAC
    // =========================================================================
    wire        m_eth_hdr_valid;
    wire        m_eth_hdr_ready;
    wire [47:0] m_eth_dest_mac;
    wire [47:0] m_eth_src_mac;
    wire [15:0] m_eth_type;

    wire [7:0]  m_eth_payload_tdata;
    wire        m_eth_payload_tvalid;
    wire        m_eth_payload_tready;
    wire        m_eth_payload_tlast;

    eth_axis_tx eth_tx_inst (
        .clk(clk_100mhz),
        .rst(axis_reset),

        .s_eth_hdr_valid(m_eth_hdr_valid),
        .s_eth_hdr_ready(m_eth_hdr_ready),
        .s_eth_dest_mac(m_eth_dest_mac),
        .s_eth_src_mac(m_eth_src_mac),
        .s_eth_type(m_eth_type),

        .s_eth_payload_axis_tdata(m_eth_payload_tdata),
        .s_eth_payload_axis_tvalid(m_eth_payload_tvalid),
        .s_eth_payload_axis_tready(m_eth_payload_tready),
        .s_eth_payload_axis_tlast(m_eth_payload_tlast),
        .s_eth_payload_axis_tuser(1'b0),

        .m_axis_tdata(mac_tx_tdata),
        .m_axis_tvalid(mac_tx_tvalid),
        .m_axis_tready(mac_tx_tready),
        .m_axis_tlast(mac_tx_tlast),
        .m_axis_tuser()
    );

    // =========================================================================
    // Local network configuration
    // =========================================================================
    localparam [47:0] LOCAL_MAC   = 48'h02_00_00_00_00_01;
    localparam [31:0] LOCAL_IP    = {8'd192, 8'd168, 8'd10, 8'd50};
    localparam [31:0] GATEWAY_IP  = {8'd192, 8'd168, 8'd10, 8'd1};
    localparam [31:0] SUBNET_MASK = {8'd255, 8'd255, 8'd255, 8'd0};

    // =========================================================================
    // Internal UDP RX/TX wires to/from udp_complete
    // =========================================================================
    wire        udp_rx_hdr_valid_int;
    wire        udp_rx_hdr_ready_int;
    wire [31:0] udp_rx_src_ip_int;
    wire [15:0] udp_rx_src_port_int;
    wire [15:0] udp_rx_dest_port_int;
    wire [7:0]  udp_rx_tdata_int;
    wire        udp_rx_tvalid_int;
    wire        udp_rx_tready_int;
    wire        udp_rx_tlast_int;

    wire        udp_tx_hdr_valid_int;
    wire        udp_tx_hdr_ready_int;
    wire [31:0] udp_tx_dest_ip_int;
    wire [15:0] udp_tx_src_port_int;
    wire [15:0] udp_tx_dest_port_int;
    wire [7:0]  udp_tx_tdata_int;
    wire        udp_tx_tvalid_int;
    wire        udp_tx_tready_int;
    wire        udp_tx_tlast_int;

    // =========================================================================
    // UDP/IP/ARP stack
    // =========================================================================
    udp_complete udp_inst (
        .clk(clk_100mhz),
        .rst(axis_reset),

        // Ethernet RX input
        .s_eth_hdr_valid(s_eth_hdr_valid),
        .s_eth_hdr_ready(s_eth_hdr_ready),
        .s_eth_dest_mac(s_eth_dest_mac),
        .s_eth_src_mac(s_eth_src_mac),
        .s_eth_type(s_eth_type),

        .s_eth_payload_axis_tdata(s_eth_payload_tdata),
        .s_eth_payload_axis_tvalid(s_eth_payload_tvalid),
        .s_eth_payload_axis_tready(s_eth_payload_tready),
        .s_eth_payload_axis_tlast(s_eth_payload_tlast),
        .s_eth_payload_axis_tuser(1'b0),

        // Ethernet TX output
        .m_eth_hdr_valid(m_eth_hdr_valid),
        .m_eth_hdr_ready(m_eth_hdr_ready),
        .m_eth_dest_mac(m_eth_dest_mac),
        .m_eth_src_mac(m_eth_src_mac),
        .m_eth_type(m_eth_type),

        .m_eth_payload_axis_tdata(m_eth_payload_tdata),
        .m_eth_payload_axis_tvalid(m_eth_payload_tvalid),
        .m_eth_payload_axis_tready(m_eth_payload_tready),
        .m_eth_payload_axis_tlast(m_eth_payload_tlast),
        .m_eth_payload_axis_tuser(),

        // IP input unused
        .s_ip_hdr_valid(1'b0),
        .s_ip_hdr_ready(),
        .s_ip_dscp(6'd0),
        .s_ip_ecn(2'd0),
        .s_ip_length(16'd0),
        .s_ip_ttl(8'd0),
        .s_ip_protocol(8'd0),
        .s_ip_source_ip(32'd0),
        .s_ip_dest_ip(32'd0),
        .s_ip_payload_axis_tdata(8'd0),
        .s_ip_payload_axis_tvalid(1'b0),
        .s_ip_payload_axis_tready(),
        .s_ip_payload_axis_tlast(1'b0),
        .s_ip_payload_axis_tuser(1'b0),

        // IP output unused
        .m_ip_hdr_valid(),
        .m_ip_hdr_ready(1'b1),
        .m_ip_eth_dest_mac(),
        .m_ip_eth_src_mac(),
        .m_ip_eth_type(),
        .m_ip_version(),
        .m_ip_ihl(),
        .m_ip_dscp(),
        .m_ip_ecn(),
        .m_ip_length(),
        .m_ip_identification(),
        .m_ip_flags(),
        .m_ip_fragment_offset(),
        .m_ip_ttl(),
        .m_ip_protocol(),
        .m_ip_header_checksum(),
        .m_ip_source_ip(),
        .m_ip_dest_ip(),
        .m_ip_payload_axis_tdata(),
        .m_ip_payload_axis_tvalid(),
        .m_ip_payload_axis_tready(1'b1),
        .m_ip_payload_axis_tlast(),
        .m_ip_payload_axis_tuser(),

        // UDP TX input from udp_processing_top
        .s_udp_hdr_valid(udp_tx_hdr_valid_int),
        .s_udp_hdr_ready(udp_tx_hdr_ready_int),
        .s_udp_ip_dscp(6'd0),
        .s_udp_ip_ecn(2'd0),
        .s_udp_ip_ttl(8'd64),
        .s_udp_ip_source_ip(LOCAL_IP),
        .s_udp_ip_dest_ip(udp_tx_dest_ip_int),
        .s_udp_source_port(udp_tx_src_port_int),
        .s_udp_dest_port(udp_tx_dest_port_int),
        .s_udp_length(udp_tx_length),
        .s_udp_checksum(16'd0),

        .s_udp_payload_axis_tdata(udp_tx_tdata_int),
        .s_udp_payload_axis_tvalid(udp_tx_tvalid_int),
        .s_udp_payload_axis_tready(udp_tx_tready_int),
        .s_udp_payload_axis_tlast(udp_tx_tlast_int),
        .s_udp_payload_axis_tuser(1'b0),

        // UDP RX output to udp_processing_top
        .m_udp_hdr_valid(udp_rx_hdr_valid_int),
        .m_udp_hdr_ready(udp_rx_hdr_ready_int),
        .m_udp_eth_dest_mac(),
        .m_udp_eth_src_mac(),
        .m_udp_eth_type(),
        .m_udp_ip_version(),
        .m_udp_ip_ihl(),
        .m_udp_ip_dscp(),
        .m_udp_ip_ecn(),
        .m_udp_ip_length(),
        .m_udp_ip_identification(),
        .m_udp_ip_flags(),
        .m_udp_ip_fragment_offset(),
        .m_udp_ip_ttl(),
        .m_udp_ip_protocol(),
        .m_udp_ip_header_checksum(),
        .m_udp_ip_source_ip(udp_rx_src_ip_int),
        .m_udp_ip_dest_ip(),
        .m_udp_source_port(udp_rx_src_port_int),
        .m_udp_dest_port(udp_rx_dest_port_int),
        .m_udp_length(),
        .m_udp_checksum(),

        .m_udp_payload_axis_tdata(udp_rx_tdata_int),
        .m_udp_payload_axis_tvalid(udp_rx_tvalid_int),
        .m_udp_payload_axis_tready(udp_rx_tready_int),
        .m_udp_payload_axis_tlast(udp_rx_tlast_int),
        .m_udp_payload_axis_tuser(),

        // Status
        .ip_rx_busy(),
        .ip_tx_busy(),
        .udp_rx_busy(),
        .udp_tx_busy(),
        .ip_rx_error_header_early_termination(),
        .ip_rx_error_payload_early_termination(),
        .ip_rx_error_invalid_header(),
        .ip_rx_error_invalid_checksum(),
        .ip_tx_error_payload_early_termination(),
        .ip_tx_error_arp_failed(),
        .udp_rx_error_header_early_termination(),
        .udp_rx_error_payload_early_termination(),
        .udp_tx_error_payload_early_termination(),

        // Config
        .local_mac(LOCAL_MAC),
        .local_ip(LOCAL_IP),
        .gateway_ip(GATEWAY_IP),
        .subnet_mask(SUBNET_MASK),
        .clear_arp_cache(1'b0)
    );

    // =========================================================================
    // External UDP RX connections
    // =========================================================================
    assign udp_rx_hdr_valid     = udp_rx_hdr_valid_int;
    assign udp_rx_src_ip        = udp_rx_src_ip_int;
    assign udp_rx_src_port      = udp_rx_src_port_int;
    assign udp_rx_dest_port     = udp_rx_dest_port_int;
    assign udp_rx_tdata         = udp_rx_tdata_int;
    assign udp_rx_tvalid        = udp_rx_tvalid_int;
    assign udp_rx_tlast         = udp_rx_tlast_int;
    assign udp_rx_hdr_ready_int = udp_rx_hdr_ready;
    assign udp_rx_tready_int    = udp_rx_tready;

    // =========================================================================
    // External UDP TX connections
    // =========================================================================
    assign udp_tx_hdr_valid_int = udp_tx_hdr_valid;
    assign udp_tx_dest_ip_int   = udp_tx_dest_ip;
    assign udp_tx_src_port_int  = udp_tx_src_port;
    assign udp_tx_dest_port_int = udp_tx_dest_port;
    assign udp_tx_tdata_int     = udp_tx_tdata;
    assign udp_tx_tvalid_int    = udp_tx_tvalid;
    assign udp_tx_tlast_int     = udp_tx_tlast;
    assign udp_tx_hdr_ready     = udp_tx_hdr_ready_int;
    assign udp_tx_tready        = udp_tx_tready_int;

endmodule
