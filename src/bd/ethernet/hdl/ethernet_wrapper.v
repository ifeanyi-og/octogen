//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
//Date        : Wed Feb  4 11:39:55 2026
//Host        : LAPTOP-27IMO5011 running 64-bit major release  (build 9200)
//Command     : generate_target ethernet_wrapper.bd
//Design      : ethernet_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module ethernet_wrapper
   (axis_clk_0,
    gtx_clk_0,
    m_axis_rxd_0_tdata,
    m_axis_rxd_0_tkeep,
    m_axis_rxd_0_tlast,
    m_axis_rxd_0_tready,
    m_axis_rxd_0_tvalid,
    phy_rst_n_0,
    ref_clk_0,
    rgmii_0_rd,
    rgmii_0_rx_ctl,
    rgmii_0_rxc,
    rgmii_0_td,
    rgmii_0_tx_ctl,
    rgmii_0_txc,
    s_axi_0_araddr,
    s_axi_0_arready,
    s_axi_0_arvalid,
    s_axi_0_awaddr,
    s_axi_0_awready,
    s_axi_0_awvalid,
    s_axi_0_bready,
    s_axi_0_bresp,
    s_axi_0_bvalid,
    s_axi_0_rdata,
    s_axi_0_rready,
    s_axi_0_rresp,
    s_axi_0_rvalid,
    s_axi_0_wdata,
    s_axi_0_wready,
    s_axi_0_wstrb,
    s_axi_0_wvalid,
    s_axi_lite_clk_0,
    s_axis_txc_tvalid_0,
    s_axis_txd_0_tdata,
    s_axis_txd_0_tkeep,
    s_axis_txd_0_tlast,
    s_axis_txd_0_tready,
    s_axis_txd_0_tvalid);
  input axis_clk_0;
  input gtx_clk_0;
  output [31:0]m_axis_rxd_0_tdata;
  output [3:0]m_axis_rxd_0_tkeep;
  output m_axis_rxd_0_tlast;
  input m_axis_rxd_0_tready;
  output m_axis_rxd_0_tvalid;
  output [0:0]phy_rst_n_0;
  input ref_clk_0;
  input [3:0]rgmii_0_rd;
  input rgmii_0_rx_ctl;
  input rgmii_0_rxc;
  output [3:0]rgmii_0_td;
  output rgmii_0_tx_ctl;
  output rgmii_0_txc;
  input [17:0]s_axi_0_araddr;
  output s_axi_0_arready;
  input s_axi_0_arvalid;
  input [17:0]s_axi_0_awaddr;
  output s_axi_0_awready;
  input s_axi_0_awvalid;
  input s_axi_0_bready;
  output [1:0]s_axi_0_bresp;
  output s_axi_0_bvalid;
  output [31:0]s_axi_0_rdata;
  input s_axi_0_rready;
  output [1:0]s_axi_0_rresp;
  output s_axi_0_rvalid;
  input [31:0]s_axi_0_wdata;
  output s_axi_0_wready;
  input [3:0]s_axi_0_wstrb;
  input s_axi_0_wvalid;
  input s_axi_lite_clk_0;
  input s_axis_txc_tvalid_0;
  input [31:0]s_axis_txd_0_tdata;
  input [3:0]s_axis_txd_0_tkeep;
  input s_axis_txd_0_tlast;
  output s_axis_txd_0_tready;
  input s_axis_txd_0_tvalid;

  wire axis_clk_0;
  wire gtx_clk_0;
  wire [31:0]m_axis_rxd_0_tdata;
  wire [3:0]m_axis_rxd_0_tkeep;
  wire m_axis_rxd_0_tlast;
  wire m_axis_rxd_0_tready;
  wire m_axis_rxd_0_tvalid;
  wire [0:0]phy_rst_n_0;
  wire ref_clk_0;
  wire [3:0]rgmii_0_rd;
  wire rgmii_0_rx_ctl;
  wire rgmii_0_rxc;
  wire [3:0]rgmii_0_td;
  wire rgmii_0_tx_ctl;
  wire rgmii_0_txc;
  wire [17:0]s_axi_0_araddr;
  wire s_axi_0_arready;
  wire s_axi_0_arvalid;
  wire [17:0]s_axi_0_awaddr;
  wire s_axi_0_awready;
  wire s_axi_0_awvalid;
  wire s_axi_0_bready;
  wire [1:0]s_axi_0_bresp;
  wire s_axi_0_bvalid;
  wire [31:0]s_axi_0_rdata;
  wire s_axi_0_rready;
  wire [1:0]s_axi_0_rresp;
  wire s_axi_0_rvalid;
  wire [31:0]s_axi_0_wdata;
  wire s_axi_0_wready;
  wire [3:0]s_axi_0_wstrb;
  wire s_axi_0_wvalid;
  wire s_axi_lite_clk_0;
  wire s_axis_txc_tvalid_0;
  wire [31:0]s_axis_txd_0_tdata;
  wire [3:0]s_axis_txd_0_tkeep;
  wire s_axis_txd_0_tlast;
  wire s_axis_txd_0_tready;
  wire s_axis_txd_0_tvalid;

  ethernet ethernet_i
       (.axis_clk_0(axis_clk_0),
        .gtx_clk_0(gtx_clk_0),
        .m_axis_rxd_0_tdata(m_axis_rxd_0_tdata),
        .m_axis_rxd_0_tkeep(m_axis_rxd_0_tkeep),
        .m_axis_rxd_0_tlast(m_axis_rxd_0_tlast),
        .m_axis_rxd_0_tready(m_axis_rxd_0_tready),
        .m_axis_rxd_0_tvalid(m_axis_rxd_0_tvalid),
        .phy_rst_n_0(phy_rst_n_0),
        .ref_clk_0(ref_clk_0),
        .rgmii_0_rd(rgmii_0_rd),
        .rgmii_0_rx_ctl(rgmii_0_rx_ctl),
        .rgmii_0_rxc(rgmii_0_rxc),
        .rgmii_0_td(rgmii_0_td),
        .rgmii_0_tx_ctl(rgmii_0_tx_ctl),
        .rgmii_0_txc(rgmii_0_txc),
        .s_axi_0_araddr(s_axi_0_araddr),
        .s_axi_0_arready(s_axi_0_arready),
        .s_axi_0_arvalid(s_axi_0_arvalid),
        .s_axi_0_awaddr(s_axi_0_awaddr),
        .s_axi_0_awready(s_axi_0_awready),
        .s_axi_0_awvalid(s_axi_0_awvalid),
        .s_axi_0_bready(s_axi_0_bready),
        .s_axi_0_bresp(s_axi_0_bresp),
        .s_axi_0_bvalid(s_axi_0_bvalid),
        .s_axi_0_rdata(s_axi_0_rdata),
        .s_axi_0_rready(s_axi_0_rready),
        .s_axi_0_rresp(s_axi_0_rresp),
        .s_axi_0_rvalid(s_axi_0_rvalid),
        .s_axi_0_wdata(s_axi_0_wdata),
        .s_axi_0_wready(s_axi_0_wready),
        .s_axi_0_wstrb(s_axi_0_wstrb),
        .s_axi_0_wvalid(s_axi_0_wvalid),
        .s_axi_lite_clk_0(s_axi_lite_clk_0),
        .s_axis_txc_tvalid_0(s_axis_txc_tvalid_0),
        .s_axis_txd_0_tdata(s_axis_txd_0_tdata),
        .s_axis_txd_0_tkeep(s_axis_txd_0_tkeep),
        .s_axis_txd_0_tlast(s_axis_txd_0_tlast),
        .s_axis_txd_0_tready(s_axis_txd_0_tready),
        .s_axis_txd_0_tvalid(s_axis_txd_0_tvalid));
endmodule
