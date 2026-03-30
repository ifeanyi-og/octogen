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


// =============================================================================
// tb_octogen
//
// Top-level simulation bench using:
// - sim clock wizard stub
// - sim eth_io_top transport shim
//
// This bench is updated for:
// - RX: 4 packets/row, 256 real samples/packet, header 0xFF01
// - TX: 2 packets/row, 256 real samples/packet, header 0xFF03
// - TX row ID autonomous counter starting at 0 after reset
// =============================================================================
module tb_octogen;

    localparam int APP_UDP_PORT        = 16'd5001;

    localparam int RX_BATCH_SAMPLES    = 256;
    localparam int RX_PACKETS_PER_ROW  = 4;

    localparam int TX_BATCH_SAMPLES    = 256;
    localparam int TX_PACKETS_PER_ROW  = 2;

    localparam int BYTES_PER_PACKET    = 1028;
    localparam int TOTAL_TX_BYTES      = TX_PACKETS_PER_ROW * BYTES_PER_PACKET;

    localparam logic [15:0] RX_HDR_TAG = 16'hFF01;
    localparam logic [15:0] TX_HDR_TAG = 16'hFF03;

    // ========================================================================
    // DUT pins
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

    initial osc_clk = 1'b0;
    always #5 osc_clk = ~osc_clk;

    octogen_top dut (
        .reset_btn    (reset_btn),
        .rgmii_rd     (rgmii_rd),
        .rgmii_rx_ctl (rgmii_rx_ctl),
        .rgmii_rxc    (rgmii_rxc),
        .rgmii_td     (rgmii_td),
        .rgmii_tx_ctl (rgmii_tx_ctl),
        .rgmii_txc    (rgmii_txc),
        .osc_clk      (osc_clk),
        .my_led       (my_led),
        .my_btns      (my_btns),
        .phy_rst_n    (phy_rst_n)
    );

    // ========================================================================
    // Scoreboard
    // ========================================================================
    int pass = 0;
    int fail = 0;

    task automatic expect_local(input bit cond, input string msg);
    begin
        if (cond) begin
            pass++;
        end else begin
            $display("FAIL: %s", msg);
            fail++;
        end
    end
    endtask

    task automatic fatal_if_fail(input bit cond, input string msg);
    begin
        expect_local(cond, msg);
        if (!cond) begin
            $display("Stopping due to failure: %s", msg);
            $finish;
        end
    end
    endtask

    // ========================================================================
    // Access helpers
    // ========================================================================
    task automatic wait_clk100(input integer n);
        integer i;
    begin
        for (i = 0; i < n; i = i + 1)
            @(posedge dut.clk_100mhz);
    end
    endtask

    function automatic logic [31:0] bytes_to_u32_le(
        input byte b0, input byte b1, input byte b2, input byte b3
    );
        bytes_to_u32_le = {b3, b2, b1, b0};
    endfunction

    function automatic logic [31:0] expected_rx_header_word(
        input logic [9:0] row_id,
        input logic [1:0] batch_id
    );
        expected_rx_header_word = {RX_HDR_TAG, batch_id, 4'b0000, row_id};
    endfunction

    function automatic logic [31:0] expected_tx_header_word(
        input logic [9:0] tx_row_id,
        input logic [1:0] batch_id
    );
        expected_tx_header_word = {TX_HDR_TAG, batch_id, 4'b0000, tx_row_id};
    endfunction

    // ========================================================================
    // TX capture
    // ========================================================================
    typedef struct packed {
        logic [31:0] dest_ip;
        logic [15:0] src_port;
        logic [15:0] dest_port;
        logic [15:0] length;
    } tx_hdr_t;

    tx_hdr_t tx_hdr_q[$];
    tx_hdr_t pending_hdr_q[$];
    byte     tx_pkts[$][$];

    int active_pkt_idx;
    int active_byte_idx;
    bit active_pkt_open;

    task automatic clear_tx_capture;
    begin
        tx_hdr_q.delete();
        pending_hdr_q.delete();
        tx_pkts.delete();
        active_pkt_idx  = -1;
        active_byte_idx = 0;
        active_pkt_open = 0;
    end
    endtask

    always @(posedge dut.clk_100mhz) begin
        if (dut.axis_reset) begin
            clear_tx_capture();
        end else begin
            if (dut.eth_io.udp_tx_hdr_valid && dut.eth_io.udp_tx_hdr_ready) begin
                tx_hdr_t h;
                h.dest_ip   = dut.eth_io.udp_tx_dest_ip;
                h.src_port  = dut.eth_io.udp_tx_src_port;
                h.dest_port = dut.eth_io.udp_tx_dest_port;
                h.length    = dut.eth_io.udp_tx_length;
                tx_hdr_q.push_back(h);
                pending_hdr_q.push_back(h);
            end

            if (dut.eth_io.udp_tx_tvalid && dut.eth_io.udp_tx_tready) begin
                if (!active_pkt_open) begin
                    if (pending_hdr_q.size() == 0) begin
                        $display("ERROR: TX payload with no matching header");
                        fail++;
                    end else begin
                        pending_hdr_q.pop_front();
                        tx_pkts.push_back({});
                        active_pkt_idx  = tx_pkts.size() - 1;
                        active_byte_idx = 0;
                        active_pkt_open = 1'b1;
                        tx_pkts[active_pkt_idx].push_back(dut.eth_io.udp_tx_tdata);

                        if (dut.eth_io.udp_tx_tlast)
                            active_pkt_open = 1'b0;
                        else
                            active_byte_idx = 1;
                    end
                end else begin
                    tx_pkts[active_pkt_idx].push_back(dut.eth_io.udp_tx_tdata);

                    if (dut.eth_io.udp_tx_tlast)
                        active_pkt_open = 1'b0;
                    else
                        active_byte_idx = active_byte_idx + 1;
                end
            end
        end
    end

    // ========================================================================
    // RX injection via eth_io sim shim
    // ========================================================================
    task automatic send_udp_header(
        input logic [31:0] src_ip,
        input logic [15:0] src_port,
        input logic [15:0] dest_port
    );
    begin
        while (!dut.eth_io.udp_rx_hdr_ready)
            @(posedge dut.clk_100mhz);

        dut.eth_io.tb_udp_rx_hdr_valid <= 1'b1;
        dut.eth_io.tb_udp_rx_src_ip    <= src_ip;
        dut.eth_io.tb_udp_rx_src_port  <= src_port;
        dut.eth_io.tb_udp_rx_dest_port <= dest_port;

        do @(posedge dut.clk_100mhz); while (!(dut.eth_io.tb_udp_rx_hdr_valid && dut.eth_io.udp_rx_hdr_ready));

        dut.eth_io.tb_udp_rx_hdr_valid <= 1'b0;
    end
    endtask

    task automatic send_udp_byte(input byte b, input bit last);
    begin
        while (!dut.eth_io.udp_rx_tready)
            @(posedge dut.clk_100mhz);

        dut.eth_io.tb_udp_rx_tdata  <= b;
        dut.eth_io.tb_udp_rx_tvalid <= 1'b1;
        dut.eth_io.tb_udp_rx_tlast  <= last;

        do @(posedge dut.clk_100mhz); while (!(dut.eth_io.tb_udp_rx_tvalid && dut.eth_io.udp_rx_tready));

        dut.eth_io.tb_udp_rx_tvalid <= 1'b0;
        dut.eth_io.tb_udp_rx_tlast  <= 1'b0;
        dut.eth_io.tb_udp_rx_tdata  <= 8'h00;
    end
    endtask

    task automatic idle_udp(input integer n);
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

    task automatic send_app_packet(
        input logic [9:0]  row_id,
        input logic [1:0]  batch_id,
        input logic [31:0] src_ip,
        input logic [15:0] src_port,
        input logic [15:0] dest_port
    );
        integer i;
        integer global_idx;
        logic [31:0] hdr;
        logic [31:0] data_val;
    begin
        send_udp_header(src_ip, src_port, dest_port);

        hdr = expected_rx_header_word(row_id, batch_id);

        send_udp_byte(hdr[7:0],   1'b0);
        send_udp_byte(hdr[15:8],  1'b0);
        send_udp_byte(hdr[23:16], 1'b0);
        send_udp_byte(hdr[31:24], 1'b0);

        for (i = 0; i < RX_BATCH_SAMPLES; i = i + 1) begin
            global_idx = batch_id * RX_BATCH_SAMPLES + i;
            data_val   = global_idx[31:0];

            send_udp_byte(data_val[7:0],   1'b0);
            send_udp_byte(data_val[15:8],  1'b0);
            send_udp_byte(data_val[23:16], 1'b0);
            send_udp_byte(data_val[31:24], (i == RX_BATCH_SAMPLES-1));
        end
    end
    endtask

    task automatic wait_for_tx_packets(input int exp_packets, input int timeout_cycles, output bit ok);
        int i;
    begin
        ok = 0;
        for (i = 0; i < timeout_cycles; i = i + 1) begin
            @(posedge dut.clk_100mhz);
            if ((tx_pkts.size() >= exp_packets) &&
                (pending_hdr_q.size() == 0) &&
                (!active_pkt_open)) begin
                ok = 1;
                return;
            end
        end
    end
    endtask

    task automatic check_single_packet_payload(
        input int pkt_idx,
        input logic [9:0] exp_tx_row_id
    );
        int s;
        int base;
        int global_idx;
        logic [31:0] hdr_word;
        logic [31:0] exp_hdr_word;
        logic [31:0] got_data;
        logic [31:0] exp_data;
    begin
        fatal_if_fail(pkt_idx < tx_pkts.size(), $sformatf("packet %0d captured", pkt_idx));
        fatal_if_fail(tx_pkts[pkt_idx].size() == BYTES_PER_PACKET,
                      $sformatf("packet %0d has %0d bytes", pkt_idx, BYTES_PER_PACKET));

        hdr_word     = bytes_to_u32_le(tx_pkts[pkt_idx][0], tx_pkts[pkt_idx][1], tx_pkts[pkt_idx][2], tx_pkts[pkt_idx][3]);
        exp_hdr_word = expected_tx_header_word(exp_tx_row_id, pkt_idx[1:0]);

        expect_local(hdr_word == exp_hdr_word,
                     $sformatf("packet %0d header matches tx_row=%0d batch=%0d",
                               pkt_idx, exp_tx_row_id, pkt_idx[1:0]));

        for (s = 0; s < TX_BATCH_SAMPLES; s = s + 1) begin
            base       = 4 + (s * 4);
            global_idx = pkt_idx * TX_BATCH_SAMPLES + s;
            got_data   = bytes_to_u32_le(tx_pkts[pkt_idx][base+0],
                                         tx_pkts[pkt_idx][base+1],
                                         tx_pkts[pkt_idx][base+2],
                                         tx_pkts[pkt_idx][base+3]);

            // decimator keeps even input samples: 0,2,4,...,1022
            exp_data = (global_idx * 2);

            expect_local(got_data == exp_data,
                         $sformatf("packet %0d sample %0d data correct", pkt_idx, s));
        end
    end
    endtask

    task automatic check_row_tx(
        input logic [9:0]  exp_tx_row_id,
        input logic [31:0] exp_dest_ip,
        input logic [15:0] exp_dest_port
    );
        int i;
    begin
        expect_local(tx_hdr_q.size() == TX_PACKETS_PER_ROW, "saw 2 TX headers");
        expect_local(tx_pkts.size()  == TX_PACKETS_PER_ROW, "captured 2 TX packets");

        for (i = 0; i < tx_hdr_q.size(); i = i + 1) begin
            expect_local(tx_hdr_q[i].dest_ip   == exp_dest_ip,   $sformatf("packet %0d dest IP correct", i));
            expect_local(tx_hdr_q[i].src_port  == APP_UDP_PORT,  $sformatf("packet %0d src port correct", i));
            expect_local(tx_hdr_q[i].dest_port == exp_dest_port, $sformatf("packet %0d dest port correct", i));
            expect_local(tx_hdr_q[i].length    == BYTES_PER_PACKET, $sformatf("packet %0d length correct", i));

            check_single_packet_payload(i, exp_tx_row_id);
        end
    end
    endtask

    // ========================================================================
    // Reset helper
    // ========================================================================
    task automatic reset_top;
    begin
        reset_btn    <= 1'b0;
        my_btns      <= 4'h0;
        rgmii_rd     <= 4'h0;
        rgmii_rx_ctl <= 1'b0;
        rgmii_rxc    <= 1'b0;

        dut.eth_io.tb_udp_rx_hdr_valid <= 1'b0;
        dut.eth_io.tb_udp_rx_src_ip    <= 32'd0;
        dut.eth_io.tb_udp_rx_src_port  <= 16'd0;
        dut.eth_io.tb_udp_rx_dest_port <= 16'd0;
        dut.eth_io.tb_udp_rx_tdata     <= 8'd0;
        dut.eth_io.tb_udp_rx_tvalid    <= 1'b0;
        dut.eth_io.tb_udp_rx_tlast     <= 1'b0;

        repeat (10) @(posedge osc_clk);
        reset_btn <= 1'b1;

        wait (dut.pll_locked == 1'b1);
        wait_clk100(20);
        clear_tx_capture();
    end
    endtask

    // ========================================================================
    // Main
    // ========================================================================
    bit ok;

    initial begin
        reset_top();

        expect_local(dut.pll_locked == 1'b1, "PLL locked");
        expect_local(phy_rst_n == 1'b1, "PHY reset released");
        expect_local(my_led[0] == 1'b1, "LED0 reflects pll_locked");
        expect_local(my_led[1] == 1'b1, "LED1 reflects phy_rst_n");

        // TEST1: wrong port ignored
        clear_tx_capture();
        send_app_packet(10'd3, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5002);
        wait_clk100(300);
        expect_local(tx_hdr_q.size() == 0, "wrong-port packet produced no TX headers");
        expect_local(tx_pkts.size()  == 0, "wrong-port packet produced no TX packets");

        // TEST2: one full row end-to-end
        clear_tx_capture();
        reset_top();

        send_app_packet(10'd3, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_udp(3);
        send_app_packet(10'd3, 2'd1, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_udp(3);
        send_app_packet(10'd3, 2'd2, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_udp(3);
        send_app_packet(10'd3, 2'd3, 32'hC0A80A63, 16'd6000, 16'd5001);

        wait_for_tx_packets(2, 50000, ok);
        fatal_if_fail(ok, "received all 2 TX packets");
        check_row_tx(10'd0, 32'hC0A80A63, 16'd6000);

        // LED smoke
        my_btns[0] = 1'b1;
        wait_clk100(2);
        expect_local(my_led[6] == 1'b1, "LED6 reflects button 0 high");
        my_btns[0] = 1'b0;
        wait_clk100(2);
        expect_local(my_led[6] == 1'b0, "LED6 reflects button 0 low");

        $display("==================================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("==================================================");

        $finish;
    end

endmodule


// =============================================================================
// Simulation stub: clk_wiz_main
// =============================================================================
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


// =============================================================================
// Simulation stub: eth_io_top
//
// This is a transport shim for top-level simulation only.
// It does not model Ethernet. It simply exposes UDP-facing ports and allows
// the testbench to drive/capture them hierarchically.
// =============================================================================
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
    output wire [31:0] udp_rx_src_ip,
    output wire [15:0] udp_rx_src_port,
    output wire [15:0] udp_rx_dest_port,
    output wire [7:0]  udp_rx_tdata,
    output wire        udp_rx_tvalid,
    output wire        udp_rx_tlast,
    input  wire        udp_rx_hdr_ready,
    input  wire        udp_rx_tready,

    input  wire        udp_tx_hdr_valid,
    input  wire [31:0] udp_tx_dest_ip,
    input  wire [15:0] udp_tx_src_port,
    input  wire [15:0] udp_tx_dest_port,
    input  wire [15:0] udp_tx_length,
    input  wire [7:0]  udp_tx_tdata,
    input  wire        udp_tx_tvalid,
    input  wire        udp_tx_tlast,
    output wire        udp_tx_hdr_ready,
    output wire        udp_tx_tready
);

    assign rgmii_td     = 4'h0;
    assign rgmii_tx_ctl = 1'b0;
    assign rgmii_txc    = 1'b0;
    assign phy_rst_n    = 1'b1;

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

    assign udp_tx_hdr_ready = 1'b1;
    assign udp_tx_tready    = 1'b1;

    initial begin
        tb_udp_rx_hdr_valid = 1'b0;
        tb_udp_rx_src_ip    = 32'd0;
        tb_udp_rx_src_port  = 16'd0;
        tb_udp_rx_dest_port = 16'd0;
        tb_udp_rx_tdata     = 8'd0;
        tb_udp_rx_tvalid    = 1'b0;
        tb_udp_rx_tlast     = 1'b0;
    end

endmodule

