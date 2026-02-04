// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
// DO NOT MODIFY THIS FILE.

// MODULE VLNV: amd.com:blockdesign:ethernet:1.0

// The following must be inserted into your Verilog file for this
// module to be instantiated. Change the instance name and port connections
// (in parentheses) to your own signal names.

// INST_TAG     ------ Begin cut for INSTANTIATION Template ------
ethernet your_instance_name (
  .m_axis_rxd_0_tdata(m_axis_rxd_0_tdata), // output wire [31:0] m_axis_rxd_0_tdata
  .m_axis_rxd_0_tkeep(m_axis_rxd_0_tkeep), // output wire [3:0] m_axis_rxd_0_tkeep
  .m_axis_rxd_0_tlast(m_axis_rxd_0_tlast), // output wire m_axis_rxd_0_tlast
  .m_axis_rxd_0_tready(m_axis_rxd_0_tready), // input wire m_axis_rxd_0_tready
  .m_axis_rxd_0_tvalid(m_axis_rxd_0_tvalid), // output wire m_axis_rxd_0_tvalid
  .s_axis_txd_0_tdata(s_axis_txd_0_tdata), // input wire [31:0] s_axis_txd_0_tdata
  .s_axis_txd_0_tkeep(s_axis_txd_0_tkeep), // input wire [3:0] s_axis_txd_0_tkeep
  .s_axis_txd_0_tlast(s_axis_txd_0_tlast), // input wire s_axis_txd_0_tlast
  .s_axis_txd_0_tready(s_axis_txd_0_tready), // output wire s_axis_txd_0_tready
  .s_axis_txd_0_tvalid(s_axis_txd_0_tvalid), // input wire s_axis_txd_0_tvalid
  .s_axi_0_araddr(s_axi_0_araddr), // input wire [17:0] s_axi_0_araddr
  .s_axi_0_arready(s_axi_0_arready), // output wire s_axi_0_arready
  .s_axi_0_arvalid(s_axi_0_arvalid), // input wire s_axi_0_arvalid
  .s_axi_0_awaddr(s_axi_0_awaddr), // input wire [17:0] s_axi_0_awaddr
  .s_axi_0_awready(s_axi_0_awready), // output wire s_axi_0_awready
  .s_axi_0_awvalid(s_axi_0_awvalid), // input wire s_axi_0_awvalid
  .s_axi_0_bready(s_axi_0_bready), // input wire s_axi_0_bready
  .s_axi_0_bresp(s_axi_0_bresp), // output wire [1:0] s_axi_0_bresp
  .s_axi_0_bvalid(s_axi_0_bvalid), // output wire s_axi_0_bvalid
  .s_axi_0_rdata(s_axi_0_rdata), // output wire [31:0] s_axi_0_rdata
  .s_axi_0_rready(s_axi_0_rready), // input wire s_axi_0_rready
  .s_axi_0_rresp(s_axi_0_rresp), // output wire [1:0] s_axi_0_rresp
  .s_axi_0_rvalid(s_axi_0_rvalid), // output wire s_axi_0_rvalid
  .s_axi_0_wdata(s_axi_0_wdata), // input wire [31:0] s_axi_0_wdata
  .s_axi_0_wready(s_axi_0_wready), // output wire s_axi_0_wready
  .s_axi_0_wstrb(s_axi_0_wstrb), // input wire [3:0] s_axi_0_wstrb
  .s_axi_0_wvalid(s_axi_0_wvalid), // input wire s_axi_0_wvalid
  .rgmii_0_rd(rgmii_0_rd), // input wire [3:0] rgmii_0_rd
  .rgmii_0_rx_ctl(rgmii_0_rx_ctl), // input wire rgmii_0_rx_ctl
  .rgmii_0_rxc(rgmii_0_rxc), // input wire rgmii_0_rxc
  .rgmii_0_td(rgmii_0_td), // output wire [3:0] rgmii_0_td
  .rgmii_0_tx_ctl(rgmii_0_tx_ctl), // output wire rgmii_0_tx_ctl
  .rgmii_0_txc(rgmii_0_txc), // output wire rgmii_0_txc
  .ref_clk_0(ref_clk_0), // input wire ref_clk_0
  .gtx_clk_0(gtx_clk_0), // input wire gtx_clk_0
  .axis_clk_0(axis_clk_0), // input wire axis_clk_0
  .phy_rst_n_0(phy_rst_n_0), // output wire [0:0] phy_rst_n_0
  .s_axi_lite_clk_0(s_axi_lite_clk_0), // input wire s_axi_lite_clk_0
  .s_axis_txc_tvalid_0(s_axis_txc_tvalid_0) // input wire s_axis_txc_tvalid_0
);
// INST_TAG_END ------  End cut for INSTANTIATION Template  ------

// You must compile the wrapper file ethernet.v when simulating
// the module, ethernet. When compiling the wrapper file, be sure to
// reference the Verilog simulation library.
