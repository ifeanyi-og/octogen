// src/rtl/octogen_top.v

module octogen_top (
    input  wire        clk_50mhz,
    input  wire        reset_btn,
    
    // Ethernet RGMII pins
    input  wire [3:0]  rgmii_rd,
    input  wire        rgmii_rx_ctl,
    input  wire        rgmii_rxc,
    output wire [3:0]  rgmii_td,
    output wire        rgmii_tx_ctl,
    output wire        rgmii_txc
);

    // Clocks
    wire clk_125mhz;
    wire clk_125mhz_90;
    wire clk_200mhz;
    wire pll_locked;
    
    clk_wiz_udp clk_gen (
        .clk_in1(clk_50mhz),
        .clk_out1(clk_125mhz),
        .clk_out2(clk_125mhz_90),
        .clk_out3(clk_200mhz),
        .reset(reset_btn),
        .locked(pll_locked)
    );
    
    wire axis_rst = ~pll_locked;
    
    // UDP interface signals
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

    // UDP stack
    udp_top udp_inst (
        .axis_clk(clk_125mhz),
        .axis_rst(axis_rst),
        .rgmii_rd(rgmii_rd),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .rgmii_rxc(rgmii_rxc),
        .rgmii_td(rgmii_td),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .rgmii_txc(rgmii_txc),
        .gtx_clk(clk_125mhz_90),
        .ref_clk(clk_200mhz),
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
    
    // Echo logic
    reg [31:0] saved_src_ip;
    reg [15:0] saved_src_port;
    reg [15:0] saved_dest_port;
    
    always @(posedge clk_125mhz) begin
        if (udp_rx_hdr_valid && udp_rx_hdr_ready) begin
            saved_src_ip <= udp_rx_src_ip;
            saved_src_port <= udp_rx_src_port;
            saved_dest_port <= udp_rx_dest_port;
        end
    end
    
    assign udp_tx_hdr_valid = udp_rx_hdr_valid;
    assign udp_rx_hdr_ready = udp_tx_hdr_ready;
    assign udp_tx_dest_ip = saved_src_ip;
    assign udp_tx_src_port = saved_dest_port;
    assign udp_tx_dest_port = saved_src_port;
    assign udp_tx_tdata = udp_rx_tdata;
    assign udp_tx_tvalid = udp_rx_tvalid;
    assign udp_rx_tready = udp_tx_tready;
    assign udp_tx_tlast = udp_rx_tlast;

endmodule