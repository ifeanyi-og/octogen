module octogen_top (
    // Reset button (active high)
    input  wire        reset_btn,

    // RGMII PHY pins
    input  wire [3:0]  rgmii_rd,
    input  wire        rgmii_rx_ctl,
    input  wire        rgmii_rxc,
    output wire [3:0]  rgmii_td,
    output wire        rgmii_tx_ctl,
    output wire        rgmii_txc,

    // 50MHz input from crystal osc
    input  wire        osc_clk,
    
    // Debug LEDs and buttons (controlled here)
    output reg  [7:0]  my_led,
    input  wire [3:0]  my_btns,

    // PHY reset
    output wire        phy_rst_n
);

    // ========================================================================
    // Clock Generation (centralized in octogen_top)
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
    // UDP RX/TX interconnect wires
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
    wire [7:0]  udp_tx_tdata;
    wire        udp_tx_tvalid;
    wire        udp_tx_tready;
    wire        udp_tx_tlast;

    // ========================================================================
    // Ethernet I/O Module
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

        // Clock inputs (generated here in octogen_top)
        .clk_100mhz(clk_100mhz),
        .clk_125mhz(clk_125mhz),
        .clk_200mhz(clk_200mhz),
        .axis_reset(axis_reset),

        // UDP RX outputs
        .udp_rx_hdr_valid(udp_rx_hdr_valid),
        .udp_rx_hdr_ready(udp_rx_hdr_ready),
        .udp_rx_src_ip(udp_rx_src_ip),
        .udp_rx_src_port(udp_rx_src_port),
        .udp_rx_dest_port(udp_rx_dest_port),
        .udp_rx_tdata(udp_rx_tdata),
        .udp_rx_tvalid(udp_rx_tvalid),
        .udp_rx_tready(udp_rx_tready),
        .udp_rx_tlast(udp_rx_tlast),

        // UDP TX inputs
        .udp_tx_hdr_valid(udp_tx_hdr_valid),
        .udp_tx_hdr_ready(udp_tx_hdr_ready),
        .udp_tx_dest_ip(udp_tx_dest_ip),
        .udp_tx_src_port(udp_tx_src_port),
        .udp_tx_dest_port(udp_tx_dest_port),
        .udp_tx_tdata(udp_tx_tdata),
        .udp_tx_tvalid(udp_tx_tvalid),
        .udp_tx_tready(udp_tx_tready),
        .udp_tx_tlast(udp_tx_tlast)
    );

    // ========================================================================
    // UDP Processing & DSP Module
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
        .udp_tx_tdata(udp_tx_tdata),
        .udp_tx_tvalid(udp_tx_tvalid),
        .udp_tx_tready(udp_tx_tready),
        .udp_tx_tlast(udp_tx_tlast)
    );

    // ========================================================================
    // LED Debug Control (easily modifiable)
    // ========================================================================
    reg [7:0] pkt_count = 0;

    always @(posedge clk_100mhz) begin
        if (axis_reset) begin
            pkt_count <= 0;
            my_led <= 0;
        end else begin
            // Count received packets
            if (udp_rx_tlast && udp_rx_tvalid && udp_rx_tready)
                pkt_count <= pkt_count + 1;

            // LED assignments (easily customizable)
            my_led[7:4] <= pkt_count[3:0];                    // [7:4] = packet counter
            my_led[0]   <= pll_locked;                        // [0] = PLL locked indicator
            my_led[1]   <= phy_rst_n;                         // [1] = PHY out of reset
            my_led[2]   <= udp_rx_tvalid;                     // [2] = UDP RX activity
            my_led[3]   <= udp_tx_tvalid;                     // [3] = UDP TX activity
        end
    end

endmodule

