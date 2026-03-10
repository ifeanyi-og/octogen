`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 10:32:27 AM
// Design Name: 
// Module Name: tb_octotop
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module tb_octotop;

    // ========================================================================
    // Top-level DUT pins
    // ========================================================================
    logic        reset_btn;
    logic [3:0]  rgmii_rd;
    logic        rgmii_rx_ctl;
    logic        rgmii_rxc;
    wire  [3:0]  rgmii_td;
    wire         rgmii_tx_ctl;
    wire         rgmii_txc;
    logic        osc_clk;
    wire  [7:0]  my_led;
    logic [3:0]  my_btns;
    wire         phy_rst_n;

    // free-running oscillator
    initial osc_clk = 1'b0;
    always #5 osc_clk = ~osc_clk;

    octogen_top dut (
        .reset_btn(reset_btn),
        .rgmii_rd(rgmii_rd),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .rgmii_rxc(rgmii_rxc),
        .rgmii_td(rgmii_td),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .rgmii_txc(rgmii_txc),
        .osc_clk(osc_clk),
        .my_led(my_led),
        .my_btns(my_btns),
        .phy_rst_n(phy_rst_n)
    );

    // ========================================================================
    // Scoreboard
    // ========================================================================
    integer pass = 0;
    integer fail = 0;

    task expect_local(input logic cond, input string msg);
    begin
        if (cond) begin
            $display("PASS: %s", msg);
            pass = pass + 1;
        end else begin
            $display("FAIL: %s", msg);
            fail = fail + 1;
        end
    end
    endtask

    // ========================================================================
    // Access stub internals through hierarchy
    //   dut.eth_io.<signals>
    // ========================================================================
    task wait_clk100(input integer n);
        integer i;
    begin
        for (i = 0; i < n; i = i + 1)
            @(posedge dut.clk_100mhz);
    end
    endtask

    task send_udp_header(input [31:0] src_ip, input [15:0] src_port, input [15:0] dest_port);
    begin
        while (!dut.eth_io.udp_rx_hdr_ready)
            @(posedge dut.clk_100mhz);

        @(posedge dut.clk_100mhz);
        dut.eth_io.tb_udp_rx_hdr_valid <= 1'b1;
        dut.eth_io.tb_udp_rx_src_ip    <= src_ip;
        dut.eth_io.tb_udp_rx_src_port  <= src_port;
        dut.eth_io.tb_udp_rx_dest_port <= dest_port;

        while (!(dut.eth_io.tb_udp_rx_hdr_valid && dut.eth_io.udp_rx_hdr_ready))
            @(posedge dut.clk_100mhz);

        @(posedge dut.clk_100mhz);
        dut.eth_io.tb_udp_rx_hdr_valid <= 1'b0;
    end
    endtask

    task send_udp_byte(input [7:0] b, input logic last);
    begin
        while (!dut.eth_io.udp_rx_tready)
            @(posedge dut.clk_100mhz);

        @(posedge dut.clk_100mhz);
        dut.eth_io.tb_udp_rx_tdata  <= b;
        dut.eth_io.tb_udp_rx_tvalid <= 1'b1;
        dut.eth_io.tb_udp_rx_tlast  <= last;
    end
    endtask

    task idle_udp(input integer n);
        integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge dut.clk_100mhz);
            dut.eth_io.tb_udp_rx_tvalid <= 1'b0;
            dut.eth_io.tb_udp_rx_tlast  <= 1'b0;
            dut.eth_io.tb_udp_rx_tdata  <= 8'h00;
        end
    end
    endtask

    task send_app_packet(
        input [9:0]  row_id,
        input [1:0]  batch_id,
        input [31:0] src_ip,
        input [15:0] src_port,
        input [15:0] dest_port
    );
        integer i;
        integer global_idx;
        logic [31:0] hdr;
        logic [31:0] re_val;
        logic [31:0] im_val;
    begin
        send_udp_header(src_ip, src_port, dest_port);

        hdr = {8'hFF, 8'hFF, batch_id, 4'b0000, row_id};

        send_udp_byte(hdr[7:0],   1'b0);
        send_udp_byte(hdr[15:8],  1'b0);
        send_udp_byte(hdr[23:16], 1'b0);
        send_udp_byte(hdr[31:24], 1'b0);

        for (i = 0; i < 128; i = i + 1) begin
            global_idx = batch_id * 128 + i;
            re_val = global_idx;
            im_val = global_idx + 1000;

            send_udp_byte(re_val[7:0],   1'b0);
            send_udp_byte(re_val[15:8],  1'b0);
            send_udp_byte(re_val[23:16], 1'b0);
            send_udp_byte(re_val[31:24], 1'b0);

            send_udp_byte(im_val[7:0],   1'b0);
            send_udp_byte(im_val[15:8],  1'b0);
            send_udp_byte(im_val[23:16], 1'b0);
            send_udp_byte(im_val[31:24], (i == 127));
        end

        @(posedge dut.clk_100mhz);
        dut.eth_io.tb_udp_rx_tvalid <= 1'b0;
        dut.eth_io.tb_udp_rx_tlast  <= 1'b0;
    end
    endtask

    // ========================================================================
    // Main sequence
    // ========================================================================
    initial begin
        reset_btn    = 1'b0;
        rgmii_rd     = 4'h0;
        rgmii_rx_ctl = 1'b0;
        rgmii_rxc    = 1'b0;
        my_btns      = 4'h0;

        // hold reset, then release
        #50;
        reset_btn = 1'b1;

        // wait for PLL lock and PHY reset delay
        wait (dut.pll_locked == 1'b1);
        wait_clk100(260);

        expect_local(dut.pll_locked == 1'b1, "PLL locked");
        expect_local(phy_rst_n == 1'b1, "PHY reset released");
        expect_local(my_led[0] == 1'b1, "LED0 reflects pll_locked");
        expect_local(my_led[1] == 1'b1, "LED1 reflects phy_rst_n");

        // --------------------------------------------------------------------
        // TEST 1: Wrong port ignored
        // --------------------------------------------------------------------
        dut.eth_io.clear_tx_counters();
        send_app_packet(10'd3, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5002);
        wait_clk100(300);

        expect_local(dut.eth_io.tx_hdr_count == 0, "wrong-port packet produced no TX headers");
        expect_local(dut.eth_io.tx_byte_count == 0, "wrong-port packet produced no TX bytes");

        // --------------------------------------------------------------------
        // TEST 2: One full row end-to-end
        // --------------------------------------------------------------------
        dut.eth_io.clear_tx_counters();

        send_app_packet(10'd3, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_udp(10);
        send_app_packet(10'd3, 2'd1, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_udp(10);
        send_app_packet(10'd3, 2'd2, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_udp(10);
        send_app_packet(10'd3, 2'd3, 32'hC0A80A63, 16'd6000, 16'd5001);

        wait_clk100(15000);

        expect_local(dut.eth_io.tx_hdr_count  == 4,    "four TX headers observed");
        expect_local(dut.eth_io.tx_tlast_count == 4,   "four TX packet ends observed");
        expect_local(dut.eth_io.tx_byte_count == 4112, "4112 TX bytes observed");
        expect_local(dut.eth_io.first_tx_dest_ip   == 32'hC0A80A63, "reply dest IP correct");
        expect_local(dut.eth_io.first_tx_src_port  == 16'd5001,     "reply src port correct");
        expect_local(dut.eth_io.first_tx_dest_port == 16'd6000,     "reply dest port correct");
        expect_local(dut.eth_io.first_tx_length    == 16'd1028,     "reply UDP payload length correct");

        // LED smoke checks
        expect_local(my_led[3] == 1'b0 || my_led[3] == 1'b1, "LED3 driven");
        expect_local(my_led[4] == 1'b0 || my_led[4] == 1'b1, "LED4 driven");
        expect_local(my_led[5] == 1'b0 || my_led[5] == 1'b1, "LED5 driven");

        // button passthrough to LED6
        my_btns[0] = 1'b1;
        wait_clk100(2);
        expect_local(my_led[6] == 1'b1, "LED6 reflects button 0");
        my_btns[0] = 1'b0;
        wait_clk100(2);
        expect_local(my_led[6] == 1'b0, "LED6 clears with button 0");

        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");

        $finish;
    end

endmodule

// ============================================================================
// Stub: clk_wiz_main
// Simple simulation-friendly clock wizard model
// ============================================================================
module clk_wiz_main (
    input  wire clk_in1,
    output wire clk_mn,
    output wire clk_gtx,
    output wire clk_spd,
    output wire clk_gtx2,
    input  wire reset,
    output reg  locked
);
    assign clk_mn   = clk_in1;
    assign clk_gtx  = clk_in1;
    assign clk_spd  = clk_in1;
    assign clk_gtx2 = 1'b0;

    integer lock_cnt;

    initial begin
        locked   = 1'b0;
        lock_cnt = 0;
    end

    always @(posedge clk_in1 or posedge reset) begin
        if (reset) begin
            locked   <= 1'b0;
            lock_cnt <= 0;
        end else begin
            if (!locked) begin
                lock_cnt <= lock_cnt + 1;
                if (lock_cnt > 10)
                    locked <= 1'b1;
            end
        end
    end
endmodule

// ============================================================================
// Stub: dsp_core_top
// Latency-2 DSP model: out_re = in_re + 1, out_im = in_im + 2
// ============================================================================
module dsp_core_top (
    input  wire        clk,
    input  wire        rst,
    input  wire        in_valid,
    input  wire        in_row_start,
    input  wire [31:0] in_re,
    input  wire [31:0] in_im,
    output reg         out_valid,
    output reg  [31:0] out_re,
    output reg  [31:0] out_im
);
    reg [31:0] re0, re1;
    reg [31:0] im0, im1;
    reg        v0, v1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            re0 <= 0; re1 <= 0;
            im0 <= 0; im1 <= 0;
            v0  <= 0; v1  <= 0;
            out_valid <= 0;
            out_re    <= 0;
            out_im    <= 0;
        end else begin
            v0  <= in_valid;
            re0 <= in_re + 32'd1;
            im0 <= in_im + 32'd2;

            v1  <= v0;
            re1 <= re0;
            im1 <= im0;

            out_valid <= v1;
            out_re    <= re1;
            out_im    <= im1;
        end
    end
endmodule

// ============================================================================
// Stub: eth_io_top
// Simulation transport shim. Does not model Ethernet.
// Exposes task-driven UDP RX stimulus and captures UDP TX traffic.
// ============================================================================
module eth_io_top (
    input  wire        reset_btn,
    input  wire [3:0]  rgmii_rd,
    input  wire        rgmii_rx_ctl,
    input  wire        rgmii_rxc,
    output wire [3:0]  rgmii_td,
    output wire        rgmii_tx_ctl,
    output wire        rgmii_txc,
    input  wire        osc_clk,
    output wire        phy_rst_n,
    input  wire        clk_100mhz,
    input  wire        clk_125mhz,
    input  wire        clk_200mhz,
    input  wire        axis_reset,

    output wire        udp_rx_hdr_valid,
    input  wire        udp_rx_hdr_ready,
    output wire [31:0] udp_rx_src_ip,
    output wire [15:0] udp_rx_src_port,
    output wire [15:0] udp_rx_dest_port,
    output wire [7:0]  udp_rx_tdata,
    output wire        udp_rx_tvalid,
    input  wire        udp_rx_tready,
    output wire        udp_rx_tlast,

    input  wire        udp_tx_hdr_valid,
    output wire        udp_tx_hdr_ready,
    input  wire [31:0] udp_tx_dest_ip,
    input  wire [15:0] udp_tx_src_port,
    input  wire [15:0] udp_tx_dest_port,
    input  wire [15:0] udp_tx_length,
    input  wire [7:0]  udp_tx_tdata,
    input  wire        udp_tx_tvalid,
    output wire        udp_tx_tready,
    input  wire        udp_tx_tlast
);

    // unused board-facing pins in stub
    assign rgmii_td     = 4'h0;
    assign rgmii_tx_ctl = 1'b0;
    assign rgmii_txc    = 1'b0;
    assign phy_rst_n    = 1'b1;

    // TB-driven RX stimulus
    reg        tb_udp_rx_hdr_valid;
    reg [31:0] tb_udp_rx_src_ip;
    reg [15:0] tb_udp_rx_src_port;
    reg [15:0] tb_udp_rx_dest_port;
    reg [7:0]  tb_udp_rx_tdata;
    reg        tb_udp_rx_tvalid;
    reg        tb_udp_rx_tlast;

    assign udp_rx_hdr_valid = tb_udp_rx_hdr_valid;
    assign udp_rx_src_ip    = tb_udp_rx_src_ip;
    assign udp_rx_src_port  = tb_udp_rx_src_port;
    assign udp_rx_dest_port = tb_udp_rx_dest_port;
    assign udp_rx_tdata     = tb_udp_rx_tdata;
    assign udp_rx_tvalid    = tb_udp_rx_tvalid;
    assign udp_rx_tlast     = tb_udp_rx_tlast;

    // Always ready to accept TX in this stub
    assign udp_tx_hdr_ready = 1'b1;
    assign udp_tx_tready    = 1'b1;

    // Capture TX traffic
    integer tx_hdr_count;
    integer tx_byte_count;
    integer tx_tlast_count;
    reg [31:0] first_tx_dest_ip;
    reg [15:0] first_tx_src_port;
    reg [15:0] first_tx_dest_port;
    reg [15:0] first_tx_length;

    task clear_tx_counters;
    begin
        tx_hdr_count       = 0;
        tx_byte_count      = 0;
        tx_tlast_count     = 0;
        first_tx_dest_ip   = 32'd0;
        first_tx_src_port  = 16'd0;
        first_tx_dest_port = 16'd0;
        first_tx_length    = 16'd0;
    end
    endtask

    always @(posedge clk_100mhz) begin
        if (axis_reset) begin
            clear_tx_counters();
        end else begin
            if (udp_tx_hdr_valid && udp_tx_hdr_ready) begin
                tx_hdr_count <= tx_hdr_count + 1;
                if (tx_hdr_count == 0) begin
                    first_tx_dest_ip   <= udp_tx_dest_ip;
                    first_tx_src_port  <= udp_tx_src_port;
                    first_tx_dest_port <= udp_tx_dest_port;
                    first_tx_length    <= udp_tx_length;
                end
            end

            if (udp_tx_tvalid && udp_tx_tready) begin
                tx_byte_count <= tx_byte_count + 1;
                if (udp_tx_tlast)
                    tx_tlast_count <= tx_tlast_count + 1;
            end
        end
    end

    initial begin
        tb_udp_rx_hdr_valid = 0;
        tb_udp_rx_src_ip    = 0;
        tb_udp_rx_src_port  = 0;
        tb_udp_rx_dest_port = 0;
        tb_udp_rx_tdata     = 0;
        tb_udp_rx_tvalid    = 0;
        tb_udp_rx_tlast     = 0;
        clear_tx_counters();
    end

endmodule