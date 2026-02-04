//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
//Date        : Wed Feb  4 11:39:55 2026
//Host        : LAPTOP-27IMO5011 running 64-bit major release  (build 9200)
//Command     : generate_target ethernet.bd
//Design      : ethernet
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "ethernet,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=ethernet,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=1,numReposBlks=1,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=USER,synth_mode=Hierarchical}" *) (* HW_HANDOFF = "ethernet.hwdef" *) 
module ethernet
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
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.AXIS_CLK_0 CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.AXIS_CLK_0, ASSOCIATED_BUSIF m_axis_rxd_0:s_axis_txd_0, CLK_DOMAIN ethernet_axis_clk_0, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input axis_clk_0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.GTX_CLK_0 CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.GTX_CLK_0, CLK_DOMAIN ethernet_gtx_clk_0, FREQ_HZ 125000000, FREQ_TOLERANCE_HZ 1000000, INSERT_VIP 0, PHASE 0" *) input gtx_clk_0;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rxd_0 TDATA" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_axis_rxd_0, CLK_DOMAIN ethernet_axis_clk_0, FREQ_HZ 100000000, HAS_TKEEP 1, HAS_TLAST 1, HAS_TREADY 1, HAS_TSTRB 0, INSERT_VIP 0, LAYERED_METADATA undef, PHASE 0.0, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0" *) output [31:0]m_axis_rxd_0_tdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rxd_0 TKEEP" *) output [3:0]m_axis_rxd_0_tkeep;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rxd_0 TLAST" *) output m_axis_rxd_0_tlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rxd_0 TREADY" *) input m_axis_rxd_0_tready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis_rxd_0 TVALID" *) output m_axis_rxd_0_tvalid;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.PHY_RST_N_0 RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.PHY_RST_N_0, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) output [0:0]phy_rst_n_0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.REF_CLK_0 CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.REF_CLK_0, CLK_DOMAIN ethernet_ref_clk_0, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input ref_clk_0;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 rgmii_0 RD" *) (* X_INTERFACE_MODE = "Master" *) input [3:0]rgmii_0_rd;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 rgmii_0 RX_CTL" *) input rgmii_0_rx_ctl;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 rgmii_0 RXC" *) input rgmii_0_rxc;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 rgmii_0 TD" *) output [3:0]rgmii_0_td;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 rgmii_0 TX_CTL" *) output rgmii_0_tx_ctl;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 rgmii_0 TXC" *) output rgmii_0_txc;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 ARADDR" *) (* X_INTERFACE_MODE = "Slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_0, ADDR_WIDTH 18, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN ethernet_s_axi_lite_clk_0, DATA_WIDTH 32, FREQ_HZ 100000000, HAS_BRESP 1, HAS_BURST 0, HAS_CACHE 0, HAS_LOCK 0, HAS_PROT 0, HAS_QOS 0, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 1, NUM_READ_OUTSTANDING 1, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 1, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI4LITE, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) input [17:0]s_axi_0_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 ARREADY" *) output s_axi_0_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 ARVALID" *) input s_axi_0_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 AWADDR" *) input [17:0]s_axi_0_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 AWREADY" *) output s_axi_0_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 AWVALID" *) input s_axi_0_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 BREADY" *) input s_axi_0_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 BRESP" *) output [1:0]s_axi_0_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 BVALID" *) output s_axi_0_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 RDATA" *) output [31:0]s_axi_0_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 RREADY" *) input s_axi_0_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 RRESP" *) output [1:0]s_axi_0_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 RVALID" *) output s_axi_0_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 WDATA" *) input [31:0]s_axi_0_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 WREADY" *) output s_axi_0_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 WSTRB" *) input [3:0]s_axi_0_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axi_0 WVALID" *) input s_axi_0_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.S_AXI_LITE_CLK_0 CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.S_AXI_LITE_CLK_0, ASSOCIATED_BUSIF s_axi_0, CLK_DOMAIN ethernet_s_axi_lite_clk_0, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input s_axi_lite_clk_0;
  input s_axis_txc_tvalid_0;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_txd_0 TDATA" *) (* X_INTERFACE_MODE = "Slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axis_txd_0, CLK_DOMAIN ethernet_axis_clk_0, FREQ_HZ 100000000, HAS_TKEEP 1, HAS_TLAST 1, HAS_TREADY 1, HAS_TSTRB 0, INSERT_VIP 0, LAYERED_METADATA undef, PHASE 0.0, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0" *) input [31:0]s_axis_txd_0_tdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_txd_0 TKEEP" *) input [3:0]s_axis_txd_0_tkeep;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_txd_0 TLAST" *) input s_axis_txd_0_tlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_txd_0 TREADY" *) output s_axis_txd_0_tready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_txd_0 TVALID" *) input s_axis_txd_0_tvalid;

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
  wire [31:0]s_axis_txd_0_tdata;
  wire [3:0]s_axis_txd_0_tkeep;
  wire s_axis_txd_0_tlast;
  wire s_axis_txd_0_tready;
  wire s_axis_txd_0_tvalid;

  ethernet_axi_ethernet_0_0 axi_ethernet_0
       (.axi_rxd_arstn(1'b1),
        .axi_rxs_arstn(1'b1),
        .axi_txc_arstn(1'b1),
        .axi_txd_arstn(1'b1),
        .axis_clk(axis_clk_0),
        .gtx_clk(gtx_clk_0),
        .m_axis_rxd_tdata(m_axis_rxd_0_tdata),
        .m_axis_rxd_tkeep(m_axis_rxd_0_tkeep),
        .m_axis_rxd_tlast(m_axis_rxd_0_tlast),
        .m_axis_rxd_tready(m_axis_rxd_0_tready),
        .m_axis_rxd_tvalid(m_axis_rxd_0_tvalid),
        .m_axis_rxs_tready(1'b1),
        .mdio_mdio_i(1'b0),
        .phy_rst_n(phy_rst_n_0),
        .ref_clk(ref_clk_0),
        .rgmii_rd(rgmii_0_rd),
        .rgmii_rx_ctl(rgmii_0_rx_ctl),
        .rgmii_rxc(rgmii_0_rxc),
        .rgmii_td(rgmii_0_td),
        .rgmii_tx_ctl(rgmii_0_tx_ctl),
        .rgmii_txc(rgmii_0_txc),
        .s_axi_araddr(s_axi_0_araddr),
        .s_axi_arready(s_axi_0_arready),
        .s_axi_arvalid(s_axi_0_arvalid),
        .s_axi_awaddr(s_axi_0_awaddr),
        .s_axi_awready(s_axi_0_awready),
        .s_axi_awvalid(s_axi_0_awvalid),
        .s_axi_bready(s_axi_0_bready),
        .s_axi_bresp(s_axi_0_bresp),
        .s_axi_bvalid(s_axi_0_bvalid),
        .s_axi_lite_clk(s_axi_lite_clk_0),
        .s_axi_lite_resetn(1'b0),
        .s_axi_rdata(s_axi_0_rdata),
        .s_axi_rready(s_axi_0_rready),
        .s_axi_rresp(s_axi_0_rresp),
        .s_axi_rvalid(s_axi_0_rvalid),
        .s_axi_wdata(s_axi_0_wdata),
        .s_axi_wready(s_axi_0_wready),
        .s_axi_wstrb(s_axi_0_wstrb),
        .s_axi_wvalid(s_axi_0_wvalid),
        .s_axis_txc_tdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axis_txc_tkeep({1'b1,1'b1,1'b1,1'b1}),
        .s_axis_txc_tlast(1'b0),
        .s_axis_txc_tvalid(1'b0),
        .s_axis_txd_tdata(s_axis_txd_0_tdata),
        .s_axis_txd_tkeep(s_axis_txd_0_tkeep),
        .s_axis_txd_tlast(s_axis_txd_0_tlast),
        .s_axis_txd_tready(s_axis_txd_0_tready),
        .s_axis_txd_tvalid(s_axis_txd_0_tvalid));
endmodule
