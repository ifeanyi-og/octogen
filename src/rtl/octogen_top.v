
/*
 * octogen_top.v
 *
 * Revised hierarchy:
 *   octogen_top
 *   ├── eth_io_top
 *   ├── udp_processing_top
 *   └── dsp_core_top
 *
 * Notes:
 * - This establishes a clean boundary between transport/application handling
 *   and DSP execution.
 * - udp_processing_top is assumed to expose a DSP-facing streaming interface.
 * - dsp_core_top is assumed to consume one complex sample per cycle and return
 *   one processed complex sample stream.
 * - You will need udp_processing_top and dsp_core_top port lists to match
 *   this top-level wiring.
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
    // Clock Generation
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
    // UDP RX/TX interconnect wires: eth_io_top <-> udp_processing_top
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
    wire [15:0] udp_tx_length;     // added for variable TX packet size
    wire [7:0]  udp_tx_tdata;
    wire        udp_tx_tvalid;
    wire        udp_tx_tready;
    wire        udp_tx_tlast;

    // ========================================================================
    // DSP stream interconnect wires: udp_processing_top <-> dsp_core_top
    // ========================================================================
    // Input stream into DSP
    wire        dsp_in_valid;
    wire        dsp_in_row_start;
    wire [31:0] dsp_in_re;
    wire [31:0] dsp_in_im;

    // Output stream from DSP
    wire        dsp_out_valid;
    wire [31:0] dsp_out_re;
    wire [31:0] dsp_out_im;

    // Optional status wires
    wire        dsp_busy;
    wire        dsp_row_done;

    // ========================================================================
    // DEBUG wires from udp_processing_top
    // Keep/remove as needed while refactoring
    // ========================================================================
    wire [1:0]  debug_parser_state;
    wire [1:0]  debug_parser_byte_count;
    wire [6:0]  debug_parser_sample_count;
    wire [7:0]  debug_parser_packet_type;
    wire        debug_parser_valid_packet;
    wire        debug_parser_hdr_valid;
    wire        debug_parser_sample_tvalid;
    wire        debug_parser_sample_tready;
    wire [1:0]  debug_s2b_byte_ptr;
    wire [31:0] debug_s2b_sample_hold;
    wire        debug_udp_tx_tvalid;
    wire        debug_udp_tx_tlast;
    wire [31:0] debug_stored_src_ip;
    wire [15:0] debug_stored_src_port;
    wire [15:0] debug_stored_dest_port;

    // ========================================================================
    // Activity counters for diagnostics
    // ========================================================================
    reg [26:0] eth_activity_counter;
    always @(posedge clk_100mhz) begin
        if (axis_reset)
            eth_activity_counter <= 0;
        else
            eth_activity_counter <= eth_activity_counter + 1;
    end

    // ========================================================================
    // INSTANTIATE: Ethernet I/O Module
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

        // UDP RX toward udp_processing_top
        .udp_rx_hdr_valid(udp_rx_hdr_valid),
        .udp_rx_hdr_ready(udp_rx_hdr_ready),
        .udp_rx_src_ip(udp_rx_src_ip),
        .udp_rx_src_port(udp_rx_src_port),
        .udp_rx_dest_port(udp_rx_dest_port),
        .udp_rx_tdata(udp_rx_tdata),
        .udp_rx_tvalid(udp_rx_tvalid),
        .udp_rx_tready(udp_rx_tready),
        .udp_rx_tlast(udp_rx_tlast),

        // UDP TX from udp_processing_top
        .udp_tx_hdr_valid(udp_tx_hdr_valid),
        .udp_tx_hdr_ready(udp_tx_hdr_ready),
        .udp_tx_dest_ip(udp_tx_dest_ip),
        .udp_tx_src_port(udp_tx_src_port),
        .udp_tx_dest_port(udp_tx_dest_port),
        .udp_tx_length(udp_tx_length),     // add this port in eth_io_top
        .udp_tx_tdata(udp_tx_tdata),
        .udp_tx_tvalid(udp_tx_tvalid),
        .udp_tx_tready(udp_tx_tready),
        .udp_tx_tlast(udp_tx_tlast)
    );

    // ========================================================================
    // INSTANTIATE: UDP Processing / application-side transport adapter
    // This module now owns packet parsing, row assembly, buffering,
    // DSP launch/capture, and response packetization.
    // ========================================================================
    udp_processing_top udp_proc (
        .clk(clk_100mhz),
        .rst(axis_reset),

        // UDP RX from eth_io_top
        .udp_rx_hdr_valid(udp_rx_hdr_valid),
        .udp_rx_hdr_ready(udp_rx_hdr_ready),
        .udp_rx_src_ip(udp_rx_src_ip),
        .udp_rx_src_port(udp_rx_src_port),
        .udp_rx_dest_port(udp_rx_dest_port),
        .udp_rx_tdata(udp_rx_tdata),
        .udp_rx_tvalid(udp_rx_tvalid),
        .udp_rx_tready(udp_rx_tready),
        .udp_rx_tlast(udp_rx_tlast),

        // UDP TX to eth_io_top
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

        // DSP input stream out to dsp_core_top
        .dsp_in_valid(dsp_in_valid),
        .dsp_in_row_start(dsp_in_row_start),
        .dsp_in_re(dsp_in_re),
        .dsp_in_im(dsp_in_im),

        // DSP output stream in from dsp_core_top
        .dsp_out_valid(dsp_out_valid),
        .dsp_out_re(dsp_out_re),
        .dsp_out_im(dsp_out_im),

        // Optional DSP status back from core
        .dsp_busy(dsp_busy),
        .dsp_row_done(dsp_row_done),

        // Existing debug signals
        .debug_parser_state(debug_parser_state),
        .debug_parser_byte_count(debug_parser_byte_count),
        .debug_parser_sample_count(debug_parser_sample_count),
        .debug_parser_packet_type(debug_parser_packet_type),
        .debug_parser_valid_packet(debug_parser_valid_packet),
        .debug_parser_hdr_valid(debug_parser_hdr_valid),
        .debug_parser_sample_tvalid(debug_parser_sample_tvalid),
        .debug_parser_sample_tready(debug_parser_sample_tready),
        .debug_s2b_byte_ptr(debug_s2b_byte_ptr),
        .debug_s2b_sample_hold(debug_s2b_sample_hold),
        .debug_udp_tx_tvalid(debug_udp_tx_tvalid),
        .debug_udp_tx_tlast(debug_udp_tx_tlast),
        .debug_stored_src_ip(debug_stored_src_ip),
        .debug_stored_src_port(debug_stored_src_port),
        .debug_stored_dest_port(debug_stored_dest_port)
    );

    // ========================================================================
    // INSTANTIATE: DSP Core Top
    // This block should own the DSP pipeline only.
    // ========================================================================
    dsp_core_top dsp_core (
        .clk(clk_100mhz),
        .rst(axis_reset),

        // Continuous complex row stream input
        .in_valid(dsp_in_valid),
        .in_row_start(dsp_in_row_start),
        .in_re(dsp_in_re),
        .in_im(dsp_in_im),

        // Processed complex stream output
        .out_valid(dsp_out_valid),
        .out_re(dsp_out_re),
        .out_im(dsp_out_im),

        // Optional status
        .busy(dsp_busy),
        .row_done(dsp_row_done)
    );

    // ========================================================================
    // Optional LED/debug mapping
    // Update as useful during bring-up
    // ========================================================================
    always @(posedge clk_100mhz) begin
        if (axis_reset) begin
            my_led <= 8'h00;
        end
        else begin
            my_led[0] <= pll_locked;
            my_led[1] <= phy_rst_n;
            my_led[2] <= udp_rx_tvalid;
            my_led[3] <= udp_tx_tvalid;
            my_led[4] <= dsp_in_valid;
            my_led[5] <= dsp_out_valid;
            my_led[6] <= dsp_busy;
            my_led[7] <= eth_activity_counter[26];
        end
    end

endmodule
