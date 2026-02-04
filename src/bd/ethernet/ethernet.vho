-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
-- -------------------------------------------------------------------------------
-- This file contains confidential and proprietary information
-- of AMD and is protected under U.S. and international copyright
-- and other intellectual property laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- AMD, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) AMD shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or AMD had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- AMD products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of AMD products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
-- DO NOT MODIFY THIS FILE.

-- MODULE VLNV: amd.com:blockdesign:ethernet:1.0

-- The following code must appear in the VHDL architecture header.

-- COMP_TAG     ------ Begin cut for COMPONENT Declaration ------
COMPONENT ethernet
  PORT (
    m_axis_rxd_0_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_rxd_0_tkeep : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axis_rxd_0_tlast : OUT STD_LOGIC;
    m_axis_rxd_0_tready : IN STD_LOGIC;
    m_axis_rxd_0_tvalid : OUT STD_LOGIC;
    s_axis_txd_0_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_txd_0_tkeep : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axis_txd_0_tlast : IN STD_LOGIC;
    s_axis_txd_0_tready : OUT STD_LOGIC;
    s_axis_txd_0_tvalid : IN STD_LOGIC;
    s_axi_0_araddr : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
    s_axi_0_arready : OUT STD_LOGIC;
    s_axi_0_arvalid : IN STD_LOGIC;
    s_axi_0_awaddr : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
    s_axi_0_awready : OUT STD_LOGIC;
    s_axi_0_awvalid : IN STD_LOGIC;
    s_axi_0_bready : IN STD_LOGIC;
    s_axi_0_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_0_bvalid : OUT STD_LOGIC;
    s_axi_0_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_0_rready : IN STD_LOGIC;
    s_axi_0_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_0_rvalid : OUT STD_LOGIC;
    s_axi_0_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_0_wready : OUT STD_LOGIC;
    s_axi_0_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_0_wvalid : IN STD_LOGIC;
    rgmii_0_rd : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    rgmii_0_rx_ctl : IN STD_LOGIC;
    rgmii_0_rxc : IN STD_LOGIC;
    rgmii_0_td : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    rgmii_0_tx_ctl : OUT STD_LOGIC;
    rgmii_0_txc : OUT STD_LOGIC;
    ref_clk_0 : IN STD_LOGIC;
    gtx_clk_0 : IN STD_LOGIC;
    axis_clk_0 : IN STD_LOGIC;
    phy_rst_n_0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    s_axi_lite_clk_0 : IN STD_LOGIC;
    s_axis_txc_tvalid_0 : IN STD_LOGIC
  );
END COMPONENT;
-- COMP_TAG_END ------  End cut for COMPONENT Declaration  ------

-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.

-- INST_TAG     ------ Begin cut for INSTANTIATION Template ------
your_instance_name : ethernet
  PORT MAP (
    m_axis_rxd_0_tdata => m_axis_rxd_0_tdata,
    m_axis_rxd_0_tkeep => m_axis_rxd_0_tkeep,
    m_axis_rxd_0_tlast => m_axis_rxd_0_tlast,
    m_axis_rxd_0_tready => m_axis_rxd_0_tready,
    m_axis_rxd_0_tvalid => m_axis_rxd_0_tvalid,
    s_axis_txd_0_tdata => s_axis_txd_0_tdata,
    s_axis_txd_0_tkeep => s_axis_txd_0_tkeep,
    s_axis_txd_0_tlast => s_axis_txd_0_tlast,
    s_axis_txd_0_tready => s_axis_txd_0_tready,
    s_axis_txd_0_tvalid => s_axis_txd_0_tvalid,
    s_axi_0_araddr => s_axi_0_araddr,
    s_axi_0_arready => s_axi_0_arready,
    s_axi_0_arvalid => s_axi_0_arvalid,
    s_axi_0_awaddr => s_axi_0_awaddr,
    s_axi_0_awready => s_axi_0_awready,
    s_axi_0_awvalid => s_axi_0_awvalid,
    s_axi_0_bready => s_axi_0_bready,
    s_axi_0_bresp => s_axi_0_bresp,
    s_axi_0_bvalid => s_axi_0_bvalid,
    s_axi_0_rdata => s_axi_0_rdata,
    s_axi_0_rready => s_axi_0_rready,
    s_axi_0_rresp => s_axi_0_rresp,
    s_axi_0_rvalid => s_axi_0_rvalid,
    s_axi_0_wdata => s_axi_0_wdata,
    s_axi_0_wready => s_axi_0_wready,
    s_axi_0_wstrb => s_axi_0_wstrb,
    s_axi_0_wvalid => s_axi_0_wvalid,
    rgmii_0_rd => rgmii_0_rd,
    rgmii_0_rx_ctl => rgmii_0_rx_ctl,
    rgmii_0_rxc => rgmii_0_rxc,
    rgmii_0_td => rgmii_0_td,
    rgmii_0_tx_ctl => rgmii_0_tx_ctl,
    rgmii_0_txc => rgmii_0_txc,
    ref_clk_0 => ref_clk_0,
    gtx_clk_0 => gtx_clk_0,
    axis_clk_0 => axis_clk_0,
    phy_rst_n_0 => phy_rst_n_0,
    s_axi_lite_clk_0 => s_axi_lite_clk_0,
    s_axis_txc_tvalid_0 => s_axis_txc_tvalid_0
  );
-- INST_TAG_END ------  End cut for INSTANTIATION Template  ------

-- You must compile the wrapper file ethernet.vhd when simulating
-- the module, ethernet. When compiling the wrapper file, be sure to
-- reference the VHDL simulation library.
