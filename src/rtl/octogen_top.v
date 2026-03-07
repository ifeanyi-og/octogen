/*
 * octogen_top.v
 * 
 * Top-level FPGA module with full debug probes for all stages
 * 
 * LED Modes (button-controlled):
 * BTN[0] = Mode 0: Ethernet RX diagnostics
 * BTN[1] = Mode 1: UDP RX diagnostics  
 * BTN[2] = Mode 2: Parser diagnostics
 * BTN[3] = Mode 3: sample_to_byte diagnostics
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
    // DEBUG wires from udp_processing_top
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
    // INSTANTIATE: UDP Processing with packet parsing
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
        .udp_tx_tlast(udp_tx_tlast),
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
    // LED DEBUG CONTROL - Button-controlled mode selection (buttons active LOW)
    // ========================================================================
    reg [1:0] debug_mode;
    
    always @(*) begin
        if (!my_btns[0])
            debug_mode = 2'b00;
        else if (!my_btns[1])
            debug_mode = 2'b01;
        else if (!my_btns[2])
            debug_mode = 2'b10;
        else if (!my_btns[3])
            debug_mode = 2'b11;
        else
            debug_mode = 2'b00;
    end

    always @(posedge clk_100mhz) begin
        if (axis_reset) begin
            my_led <= 0;
        end else begin

            case (debug_mode)
                
                2'b00: begin
                    // MODE 0: UDP RX and basic parser state
                    my_led[1:0] <= debug_parser_state;
                    my_led[2]   <= debug_parser_hdr_valid;
                    my_led[3]   <= debug_parser_sample_tvalid;
                    my_led[4]   <= debug_parser_sample_tready;
                    my_led[5]   <= udp_rx_tvalid;
                    my_led[6]   <= udp_tx_tvalid;
                    my_led[7]   <= pll_locked;
                end
                
                2'b01: begin
                    // MODE 1: Byte counting
                    my_led[1:0] <= debug_parser_byte_count;
                    my_led[2]   <= (debug_parser_byte_count == 2'b00);
                    my_led[3]   <= (debug_parser_byte_count == 2'b11);
                    my_led[4]   <= udp_rx_tlast;
                    my_led[5]   <= udp_rx_tvalid;
                    my_led[6]   <= debug_parser_sample_count[0];
                    my_led[7]   <= pll_locked;
                end
                
                2'b10: begin
                    // MODE 2: TX path - response being sent?
                    my_led[1:0] <= debug_parser_state;
                    my_led[2]   <= debug_udp_tx_tvalid;
                    my_led[3]   <= debug_udp_tx_tlast;
                    my_led[4]   <= debug_parser_sample_tvalid;
                    my_led[5]   <= udp_tx_tready;
                    my_led[6]   <= debug_parser_hdr_valid;
                    my_led[7]   <= pll_locked;
                end
                
                2'b11: begin
                    // MODE 3: Byte conversion status
                    my_led[1:0] <= debug_parser_state;
                    my_led[2]   <= (debug_s2b_byte_ptr == 2'b00);
                    my_led[3]   <= (debug_s2b_byte_ptr == 2'b11);
                    my_led[4]   <= debug_udp_tx_tvalid;
                    my_led[5]   <= debug_parser_sample_tvalid;
                    my_led[6]   <= debug_parser_sample_tready;
                    my_led[7]   <= pll_locked;
                end
            endcase

        end
    end

endmodule

