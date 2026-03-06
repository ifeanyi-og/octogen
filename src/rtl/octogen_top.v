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
    
    // Debug LEDs and buttons (buttons are active LOW)
    output reg  [7:0]  my_led,
    input  wire [3:0]  my_btns,

    // PHY reset
    output wire        phy_rst_n
);

    // ========================================================================
    // Clock Generation (centralized)
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
    wire        debug_parser_hdr_valid;
    wire        debug_parser_sample_tvalid;
    wire        debug_parser_sample_tready;
    wire [7:0]  debug_parser_assembled_header_byte0;
    wire [1:0]  debug_s2b_byte_ptr;
    wire [31:0] debug_s2b_sample_hold;
    wire        debug_udp_tx_tvalid;
    wire        debug_udp_tx_tlast;

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
        .debug_parser_hdr_valid(debug_parser_hdr_valid),
        .debug_parser_sample_tvalid(debug_parser_sample_tvalid),
        .debug_parser_sample_tready(debug_parser_sample_tready),
        .debug_parser_assembled_header_byte0(debug_parser_assembled_header_byte0),
        .debug_s2b_byte_ptr(debug_s2b_byte_ptr),
        .debug_s2b_sample_hold(debug_s2b_sample_hold),
        .debug_udp_tx_tvalid(debug_udp_tx_tvalid),
        .debug_udp_tx_tlast(debug_udp_tx_tlast)
    );

    // ========================================================================
    // LED DEBUG CONTROL - Button-controlled mode selection (buttons active LOW)
    // ========================================================================
    // my_btns[0] = 0 → Mode 0 (Parser internals)
    // my_btns[1] = 0 → Mode 1 (Sample counting)
    // my_btns[2] = 0 → Mode 2 (TX path)
    // my_btns[3] = 0 → Mode 3 (Byte conversion)
    
    reg [1:0] debug_mode;
    
    // Direct mode selection from buttons (active LOW)
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
            debug_mode = 2'b00;  // Default to mode 0 if no button pressed
    end

    always @(posedge clk_100mhz) begin
        if (axis_reset) begin
            my_led <= 0;
        end else begin

            // ========== LED ASSIGNMENT BY MODE ==========
            case (debug_mode)
                
                2'b00: begin  // MODE 0: Parser internals - see FSM and flow
                    my_led[1:0] <= debug_parser_state;           // FSM state (00=IDLE, 01=HEADER, 10=SAMPLES)
                    my_led[2]   <= debug_parser_hdr_valid;       // Header pulsing?
                    my_led[3]   <= debug_parser_sample_tvalid;   // Samples outputting?
                    my_led[4]   <= debug_parser_sample_tready;   // Downstream accepting?
                    my_led[5]   <= udp_rx_tvalid;                // RX data arriving?
                    my_led[6]   <= udp_tx_tvalid;                // TX data leaving?
                    my_led[7]   <= pll_locked;
                end
                
                2'b01: begin  // MODE 1: Sample counting (0-63)
                    my_led[5:0] <= debug_parser_sample_count[5:0];  // Sample count (0-63)
                    my_led[6]   <= (debug_parser_sample_count == 7'd63);  // Last sample?
                    my_led[7]   <= pll_locked;
                end
                
                2'b10: begin  // MODE 2: TX path - is response being sent?
                    my_led[1:0] <= debug_parser_state;           // Parser FSM state
                    my_led[2]   <= debug_udp_tx_tvalid;          // TX data valid?
                    my_led[3]   <= debug_udp_tx_tlast;           // TX packet end?
                    my_led[4]   <= debug_parser_sample_tvalid;   // Parser outputting?
                    my_led[5]   <= udp_tx_tready;                // eth_io_top ready to TX?
                    my_led[6]   <= debug_parser_hdr_valid;       // Header pulsing?
                    my_led[7]   <= pll_locked;
                end
                
                2'b11: begin  // MODE 3: Byte conversion status
                    my_led[1:0] <= debug_parser_state;           // Parser FSM state
                    my_led[2]   <= (debug_s2b_byte_ptr == 2'b00);  // At first byte?
                    my_led[3]   <= (debug_s2b_byte_ptr == 2'b11);  // At last byte?
                    my_led[4]   <= debug_udp_tx_tvalid;          // TX bytes flowing?
                    my_led[5]   <= debug_parser_sample_tvalid;   // Samples arriving to s2b?
                    my_led[6]   <= debug_parser_sample_tready;   // s2b accepting?
                    my_led[7]   <= pll_locked;
                end
            endcase
            // ========== END LED ASSIGNMENT ==========
        end
    end

endmodule
