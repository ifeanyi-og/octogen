`timescale 1ns / 1ps
/*
 * octogen_top.v
 *
 * Clean hierarchy:
 *   octogen_top
 *   |-- eth_io_top
 *       |-- (Alex Forencich's Verilog Ethernet Stack)
 *   |-- udp_processing_top
 *       |-- packet_rx_handler
 *       |-- pingpong_buffer
 *       |-- packet_tx_handler
 *       |-- cal_loader
 *   |-- dsp_core_top
 *
 * Notes:
 * - eth_io_top handles Ethernet / UDP transport
 * - udp_processing_top handles application parsing / buffering / packetization
 * - dsp_core_top handles DSP only
 
 Keep Handy:
 set_param general.maxThreads 8
 launch_runs synth_1 -jobs 4
 launch_runs impl_1 -jobs 2
 */


/*
 * octogen_top.v
 *
 * Updated top-level wiring:
 * - Wires udp_processing_top <-> dsp_core_top completely
 * - Exposes calibration write buses from udp_processing_top into dsp_core_top
 * - Feeds runtime_valid from udp_processing_top into dsp_core_top
 * - Debug LEDs now mirror runtime_valid directly
 *
 * Assumptions:
 * - Calibration is allowed whenever DSP is idle
 * - my_btns are no longer used for LED debug, since LEDs are dedicated to runtime_valid
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

    // =========================================================================
    // Clock generation
    // =========================================================================
    wire clk_100mhz;
    wire clk_125mhz;
    wire clk_200mhz;
    wire pll_locked;

    clk_wiz_main clk_gen (
        .clk_in1 (osc_clk),
        .clk_mn  (clk_100mhz),
        .clk_gtx (clk_125mhz),
        .clk_spd (clk_200mhz),
        .reset   (~reset_btn),
        .locked  (pll_locked)
    );

    wire axis_reset = ~pll_locked;

    // =========================================================================
    // UDP interconnect: eth_io_top <-> udp_processing_top
    // =========================================================================
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

    // =========================================================================
    // DSP streaming interconnect: udp_processing_top <-> dsp_core_top
    // =========================================================================
    wire        dsp_in_valid;
    wire        dsp_in_row_start;
    wire [31:0] dsp_in_data;

    wire        dsp_out_valid;
    wire        dsp_out_row_start;
    wire [31:0] dsp_out_data;

    wire        dsp_busy;
    wire        dsp_row_done;

    // =========================================================================
    // Calibration control / status
    // =========================================================================
    wire        allow_cal;
    wire        cal_loading;
    wire        cal_done_pulse;
    wire        cal_error;
    wire        cal_rejected_busy;
    wire        cal_rejected_mode;
    wire [7:0]  runtime_valid;

    // Conservative policy:
    // allow calibration only while DSP is not busy.
    assign allow_cal = ~dsp_busy;

    // =========================================================================
    // Calibration BRAM write buses: udp_processing_top -> dsp_core_top
    // =========================================================================
    wire        bg_wr_en;
    wire [0:0]  bg_wr_we;
    wire [9:0]  bg_wr_addr;
    wire [31:0] bg_wr_data;

    wire        disp_a_wr_en;
    wire [0:0]  disp_a_wr_we;
    wire [9:0]  disp_a_wr_addr;
    wire [31:0] disp_a_wr_data;

    wire        disp_b_wr_en;
    wire [0:0]  disp_b_wr_we;
    wire [9:0]  disp_b_wr_addr;
    wire [31:0] disp_b_wr_data;

    wire        klin_a_wr_en;
    wire [0:0]  klin_a_wr_we;
    wire [9:0]  klin_a_wr_addr;
    wire [31:0] klin_a_wr_data;

    wire        klin_b_wr_en;
    wire [0:0]  klin_b_wr_we;
    wire [9:0]  klin_b_wr_addr;
    wire [31:0] klin_b_wr_data;

    wire        klin_c_wr_en;
    wire [0:0]  klin_c_wr_we;
    wire [9:0]  klin_c_wr_addr;
    wire [31:0] klin_c_wr_data;

    wire        klin_d_wr_en;
    wire [0:0]  klin_d_wr_we;
    wire [9:0]  klin_d_wr_addr;
    wire [31:0] klin_d_wr_data;

    wire        klin_e_wr_en;
    wire [0:0]  klin_e_wr_we;
    wire [9:0]  klin_e_wr_addr;
    wire [31:0] klin_e_wr_data;

    // =========================================================================
    // Ethernet / UDP transport
    // =========================================================================
    eth_io_top eth_io (
        .reset_btn        (reset_btn),

        .rgmii_rd         (rgmii_rd),
        .rgmii_rx_ctl     (rgmii_rx_ctl),
        .rgmii_rxc        (rgmii_rxc),
        .rgmii_td         (rgmii_td),
        .rgmii_tx_ctl     (rgmii_tx_ctl),
        .rgmii_txc        (rgmii_txc),

        .osc_clk          (osc_clk),
        .phy_rst_n        (phy_rst_n),
        .clk_100mhz       (clk_100mhz),
        .clk_125mhz       (clk_125mhz),
        .clk_200mhz       (clk_200mhz),
        .axis_reset       (axis_reset),

        .udp_rx_hdr_valid (udp_rx_hdr_valid),
        .udp_rx_src_ip    (udp_rx_src_ip),
        .udp_rx_src_port  (udp_rx_src_port),
        .udp_rx_dest_port (udp_rx_dest_port),
        .udp_rx_tdata     (udp_rx_tdata),
        .udp_rx_tvalid    (udp_rx_tvalid),
        .udp_rx_tlast     (udp_rx_tlast),
        .udp_rx_hdr_ready (udp_rx_hdr_ready),
        .udp_rx_tready    (udp_rx_tready),

        .udp_tx_hdr_valid (udp_tx_hdr_valid),
        .udp_tx_dest_ip   (udp_tx_dest_ip),
        .udp_tx_src_port  (udp_tx_src_port),
        .udp_tx_dest_port (udp_tx_dest_port),
        .udp_tx_length    (udp_tx_length),
        .udp_tx_tdata     (udp_tx_tdata),
        .udp_tx_tvalid    (udp_tx_tvalid),
        .udp_tx_tlast     (udp_tx_tlast),
        .udp_tx_hdr_ready (udp_tx_hdr_ready),
        .udp_tx_tready    (udp_tx_tready)
    );

    // =========================================================================
    // Application processing
    // =========================================================================
    udp_processing_top udp_proc (
        .clk               (clk_100mhz),
        .rst               (axis_reset),

        .udp_rx_hdr_valid  (udp_rx_hdr_valid),
        .udp_rx_hdr_ready  (udp_rx_hdr_ready),
        .udp_rx_src_ip     (udp_rx_src_ip),
        .udp_rx_src_port   (udp_rx_src_port),
        .udp_rx_dest_port  (udp_rx_dest_port),
        .udp_rx_tdata      (udp_rx_tdata),
        .udp_rx_tvalid     (udp_rx_tvalid),
        .udp_rx_tready     (udp_rx_tready),
        .udp_rx_tlast      (udp_rx_tlast),

        .udp_tx_hdr_valid  (udp_tx_hdr_valid),
        .udp_tx_hdr_ready  (udp_tx_hdr_ready),
        .udp_tx_dest_ip    (udp_tx_dest_ip),
        .udp_tx_src_port   (udp_tx_src_port),
        .udp_tx_dest_port  (udp_tx_dest_port),
        .udp_tx_length     (udp_tx_length),
        .udp_tx_tdata      (udp_tx_tdata),
        .udp_tx_tvalid     (udp_tx_tvalid),
        .udp_tx_tready     (udp_tx_tready),
        .udp_tx_tlast      (udp_tx_tlast),

        .dsp_in_valid      (dsp_in_valid),
        .dsp_in_row_start  (dsp_in_row_start),
        .dsp_in_data       (dsp_in_data),

        .dsp_out_valid     (dsp_out_valid),
        .dsp_out_data      (dsp_out_data),

        .allow_cal         (allow_cal),
        .dsp_busy          (dsp_busy),

        .cal_loading       (cal_loading),
        .cal_done_pulse    (cal_done_pulse),
        .cal_error         (cal_error),
        .cal_rejected_busy (cal_rejected_busy),
        .cal_rejected_mode (cal_rejected_mode),
        .runtime_valid     (runtime_valid),

        .bg_wr_en          (bg_wr_en),
        .bg_wr_we          (bg_wr_we),
        .bg_wr_addr        (bg_wr_addr),
        .bg_wr_data        (bg_wr_data),

        .disp_a_wr_en      (disp_a_wr_en),
        .disp_a_wr_we      (disp_a_wr_we),
        .disp_a_wr_addr    (disp_a_wr_addr),
        .disp_a_wr_data    (disp_a_wr_data),

        .disp_b_wr_en      (disp_b_wr_en),
        .disp_b_wr_we      (disp_b_wr_we),
        .disp_b_wr_addr    (disp_b_wr_addr),
        .disp_b_wr_data    (disp_b_wr_data),

        .klin_a_wr_en      (klin_a_wr_en),
        .klin_a_wr_we      (klin_a_wr_we),
        .klin_a_wr_addr    (klin_a_wr_addr),
        .klin_a_wr_data    (klin_a_wr_data),

        .klin_b_wr_en      (klin_b_wr_en),
        .klin_b_wr_we      (klin_b_wr_we),
        .klin_b_wr_addr    (klin_b_wr_addr),
        .klin_b_wr_data    (klin_b_wr_data),

        .klin_c_wr_en      (klin_c_wr_en),
        .klin_c_wr_we      (klin_c_wr_we),
        .klin_c_wr_addr    (klin_c_wr_addr),
        .klin_c_wr_data    (klin_c_wr_data),

        .klin_d_wr_en      (klin_d_wr_en),
        .klin_d_wr_we      (klin_d_wr_we),
        .klin_d_wr_addr    (klin_d_wr_addr),
        .klin_d_wr_data    (klin_d_wr_data),

        .klin_e_wr_en      (klin_e_wr_en),
        .klin_e_wr_we      (klin_e_wr_we),
        .klin_e_wr_addr    (klin_e_wr_addr),
        .klin_e_wr_data    (klin_e_wr_data)
    );

    // =========================================================================
    // DSP core
    // =========================================================================
    dsp_core_top #(
        .IN_SAMPLES_PER_ROW  (1024),
        .OUT_SAMPLES_PER_ROW (512)
    ) dsp_core (
        .clk            (clk_100mhz),
        .rst            (axis_reset),

        .in_valid       (dsp_in_valid),
        .in_row_start   (dsp_in_row_start),
        .in_data        (dsp_in_data),

        .runtime_valid  (runtime_valid),

        .bg_wr_en       (bg_wr_en),
        .bg_wr_we       (bg_wr_we),
        .bg_wr_addr     (bg_wr_addr),
        .bg_wr_data     (bg_wr_data),

        .disp_a_wr_en   (disp_a_wr_en),
        .disp_a_wr_we   (disp_a_wr_we),
        .disp_a_wr_addr (disp_a_wr_addr),
        .disp_a_wr_data (disp_a_wr_data),

        .disp_b_wr_en   (disp_b_wr_en),
        .disp_b_wr_we   (disp_b_wr_we),
        .disp_b_wr_addr (disp_b_wr_addr),
        .disp_b_wr_data (disp_b_wr_data),

        .klin_a_wr_en   (klin_a_wr_en),
        .klin_a_wr_we   (klin_a_wr_we),
        .klin_a_wr_addr (klin_a_wr_addr),
        .klin_a_wr_data (klin_a_wr_data),

        .klin_b_wr_en   (klin_b_wr_en),
        .klin_b_wr_we   (klin_b_wr_we),
        .klin_b_wr_addr (klin_b_wr_addr),
        .klin_b_wr_data (klin_b_wr_data),

        .klin_c_wr_en   (klin_c_wr_en),
        .klin_c_wr_we   (klin_c_wr_we),
        .klin_c_wr_addr (klin_c_wr_addr),
        .klin_c_wr_data (klin_c_wr_data),

        .klin_d_wr_en   (klin_d_wr_en),
        .klin_d_wr_we   (klin_d_wr_we),
        .klin_d_wr_addr (klin_d_wr_addr),
        .klin_d_wr_data (klin_d_wr_data),

        .klin_e_wr_en   (klin_e_wr_en),
        .klin_e_wr_we   (klin_e_wr_we),
        .klin_e_wr_addr (klin_e_wr_addr),
        .klin_e_wr_data (klin_e_wr_data),

        .out_valid      (dsp_out_valid),
        .out_row_start  (dsp_out_row_start),
        .out_data       (dsp_out_data),

        .busy           (dsp_busy),
        .row_done       (dsp_row_done)
    );

    // =========================================================================
    // LEDs mirror runtime_valid directly
    // =========================================================================
    always @(posedge clk_100mhz) begin
        if (axis_reset)
            my_led <= 8'h00;
        else
            my_led <= runtime_valid;
    end

endmodule


