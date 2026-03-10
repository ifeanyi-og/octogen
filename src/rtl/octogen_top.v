`timescale 1ns / 1ps
/*
 * octogen_top.v
 *
 * Clean hierarchy:
 *   octogen_top
 *   |── eth_io_top
 *   |── udp_processing_top
 *   |── dsp_core_top
 *
 * Notes:
 * - eth_io_top handles Ethernet / UDP transport
 * - udp_processing_top handles application parsing / buffering / packetization
 * - dsp_core_top handles DSP only
 */

module octogen_top (
    input  wire        reset_btn,
    input  wire [3:0]  rgmii_rd,
    input  wire        rgmii_rx_ctl,
    input  wire        rgmii_rxc,
    output wire [3:0]  rgmii_td,
    output wire        rgmii_tx_ctl,
    output wire        rgmii_txc,
    input  wire        osc_clk,
    output reg  [7:0]  my_led,
    input  wire [3:0]  my_btns,
    output wire        phy_rst_n
);

    // ========================================================================
    // Clock generation
    // ========================================================================
    wire clk_100mhz;
    wire clk_125mhz;
    wire clk_200mhz;
    wire pll_locked;

    clk_wiz_main clk_gen (
        .clk_in1(osc_clk),
        .clk_mn(clk_100mhz),
        .clk_gtx(clk_125mhz),
        .clk_spd(clk_200mhz),
        .clk_gtx2(),
        .reset(~reset_btn),
        .locked(pll_locked)
    );

    wire axis_reset = ~pll_locked;

    // ========================================================================
    // UDP interconnect: eth_io_top <-> udp_processing_top
    // ========================================================================
    wire        udp_rx_hdr_valid;
    wire        udp_rx_hdr_ready;
    wire [31:0] udp_rx_src_ip;
    wire [15:0] udp_rx_src_port;
    wire [15:0] udp_rx_dest_port;
    wire [7:0]  udp_rx_tdata;
    wire        udp_rx_tvalid;
    wire        udp_rx_tready;
    wire        udp_rx_tlast;

    wire        udp_tx_hdr_valid;
    wire        udp_tx_hdr_ready;
    wire [31:0] udp_tx_dest_ip;
    wire [15:0] udp_tx_src_port;
    wire [15:0] udp_tx_dest_port;
    wire [15:0] udp_tx_length;
    wire [7:0]  udp_tx_tdata;
    wire        udp_tx_tvalid;
    wire        udp_tx_tready;
    wire        udp_tx_tlast;

    // ========================================================================
    // DSP interconnect: udp_processing_top <-> dsp_core_top
    // ========================================================================
    wire        dsp_in_valid;
    wire        dsp_in_row_start;
    wire [31:0] dsp_in_re;
    wire [31:0] dsp_in_im;

    wire        dsp_out_valid;
    wire [31:0] dsp_out_re;
    wire [31:0] dsp_out_im;

    // ========================================================================
    // Simple activity counter for LED heartbeat
    // ========================================================================
    reg [26:0] activity_counter;

    always @(posedge clk_100mhz) begin
        if (axis_reset)
            activity_counter <= 27'd0;
        else
            activity_counter <= activity_counter + 27'd1;
    end

    // ========================================================================
    // Ethernet / UDP transport
    // ========================================================================
    eth_io_top eth_io (
        .reset_btn(reset_btn),

        .rgmii_rd(rgmii_rd),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .rgmii_rxc(rgmii_rxc),
        .rgmii_td(rgmii_td),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .rgmii_txc(rgmii_txc),

        .osc_clk(osc_clk),
        .phy_rst_n(phy_rst_n),
        .clk_100mhz(clk_100mhz),
        .clk_125mhz(clk_125mhz),
        .clk_200mhz(clk_200mhz),
        .axis_reset(axis_reset),

        .udp_rx_hdr_valid(udp_rx_hdr_valid),
        .udp_rx_hdr_ready(udp_rx_hdr_ready),
        .udp_rx_src_ip(udp_rx_src_ip),
        .udp_rx_src_port(udp_rx_src_port),
        .udp_rx_dest_port(udp_rx_dest_port),
        .udp_rx_tdata(udp_rx_tdata),
        .udp_rx_tvalid(udp_rx_tvalid),
        .udp_rx_tready(udp_rx_tready),
        .udp_rx_tlast(udp_rx_tlast),

        .udp_tx_hdr_valid(udp_tx_hdr_valid),
        .udp_tx_hdr_ready(udp_tx_hdr_ready),
        .udp_tx_dest_ip(udp_tx_dest_ip),
        .udp_tx_src_port(udp_tx_src_port),
        .udp_tx_dest_port(udp_tx_dest_port),
        .udp_tx_length(udp_tx_length),
        .udp_tx_tdata(udp_tx_tdata),
        .udp_tx_tvalid(udp_tx_tvalid),
        .udp_tx_tready(udp_tx_tready),
        .udp_tx_tlast(udp_tx_tlast)
    );

    // ========================================================================
    // Application processing
    // ========================================================================
    udp_processing_top udp_proc (
        .clk(clk_100mhz),
        .rst(axis_reset),

        .udp_rx_hdr_valid(udp_rx_hdr_valid),
        .udp_rx_hdr_ready(udp_rx_hdr_ready),
        .udp_rx_src_ip(udp_rx_src_ip),
        .udp_rx_src_port(udp_rx_src_port),
        .udp_rx_dest_port(udp_rx_dest_port),
        .udp_rx_tdata(udp_rx_tdata),
        .udp_rx_tvalid(udp_rx_tvalid),
        .udp_rx_tready(udp_rx_tready),
        .udp_rx_tlast(udp_rx_tlast),

        .udp_tx_hdr_valid(udp_tx_hdr_valid),
        .udp_tx_hdr_ready(udp_tx_hdr_ready),
        .udp_tx_dest_ip(udp_tx_dest_ip),
        .udp_tx_src_port(udp_tx_src_port),
        .udp_tx_dest_port(udp_tx_dest_port),
        .udp_tx_length(udp_tx_length),
        .udp_tx_tdata(udp_tx_tdata),
        .udp_tx_tvalid(udp_tx_tvalid),
        .udp_tx_tready(udp_tx_tready),
        .udp_tx_tlast(udp_tx_tlast),

        .dsp_in_valid(dsp_in_valid),
        .dsp_in_row_start(dsp_in_row_start),
        .dsp_in_re(dsp_in_re),
        .dsp_in_im(dsp_in_im),

        .dsp_out_valid(dsp_out_valid),
        .dsp_out_re(dsp_out_re),
        .dsp_out_im(dsp_out_im)
    );

    // ========================================================================
    // DSP core
    // ========================================================================
    dsp_core_top dsp_core (
        .clk(clk_100mhz),
        .rst(axis_reset),

        .in_valid(dsp_in_valid),
        .in_row_start(dsp_in_row_start),
        .in_re(dsp_in_re),
        .in_im(dsp_in_im),

        .out_valid(dsp_out_valid),
        .out_re(dsp_out_re),
        .out_im(dsp_out_im)
    );

    // ========================================================================
    // LEDs
    // ========================================================================
    always @(posedge clk_100mhz) begin
        if (axis_reset) begin
            my_led <= 8'h00;
        end else begin
            my_led[0] <= pll_locked;
            my_led[1] <= phy_rst_n;
            my_led[2] <= udp_rx_tvalid;
            my_led[3] <= udp_tx_tvalid;
            my_led[4] <= dsp_in_valid;
            my_led[5] <= dsp_out_valid;
            my_led[6] <= my_btns[0];
            my_led[7] <= activity_counter[26];
        end
    end

endmodule

