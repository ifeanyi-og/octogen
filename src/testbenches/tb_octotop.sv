`timescale 1ns / 1ps
// =============================================================================
// tb_octogen
//
// Top-level simulation bench using:
// - sim clock wizard stub
// - sim eth_io_top transport shim
//
// Current expected system behavior:
// - RX: 4 packets/row, 256 real samples/packet, header 0xFF01
// - DSP stub: accepts 1024 samples, outputs first 512 unchanged
// - TX: 2 packets/row, 256 real samples/packet, header 0xFF03
// - TX row ID auto-counter starts at 0 after reset and increments per row
//
// Stronger coverage added:
// - multiple consecutive rows
// - distinctive data per row and per batch
// - minimal inter-batch gaps
// - modest variable inter-batch gaps
// =============================================================================

module tb_octogen;

    // =========================================================================
    // Core transport / packet sizing
    // =========================================================================
    localparam int APP_UDP_PORT        = 16'd5001;

    localparam int RX_BATCH_SAMPLES    = 256;   // input row packets into FPGA
    localparam int RX_PACKETS_PER_ROW  = 4;

    localparam int TX_BATCH_SAMPLES    = 256;   // output row packets from FPGA
    localparam int TX_PACKETS_PER_ROW  = 2;

    localparam int CAL_BATCH_SAMPLES   = 256;   // calibration packets
    localparam int CAL_PACKETS_PER_SET = 4;

    localparam int BYTES_PER_PACKET    = 4 + (256 * 4);  // 1028 bytes

    localparam logic [15:0] RX_HDR_TAG = 16'hFF01;
    localparam logic [15:0] TX_HDR_TAG = 16'hFF03;

    // -------------------------------------------------------------------------
    // IMPORTANT:
    // Adjust CAL_HDR_TAG / build_cal_header_word() only if your cal-loader TB
    // uses a different exact encoding. Everything else is independent.
    // -------------------------------------------------------------------------
    localparam logic [15:0] CAL_HDR_TAG = 16'hFF02;

    typedef enum logic [9:0] {
        CAL_BG_ROWID     = 10'd0,
        CAL_DISP_A_ROWID = 10'd20,
        CAL_DISP_B_ROWID = 10'd21,
        CAL_KLIN_A_ROWID = 10'd24,
        CAL_KLIN_B_ROWID = 10'd25,
        CAL_KLIN_C_ROWID = 10'd26,
        CAL_KLIN_D_ROWID = 10'd27,
        CAL_KLIN_E_ROWID = 10'd28
    } cal_rowid_e;

    // Assumed runtime_valid mapping.
    // Keep this only if it matches your cal_loader.
    localparam int RV_BG     = 0;
    localparam int RV_DISP_A = 1;
    localparam int RV_DISP_B = 2;
    localparam int RV_KLIN_A = 3;
    localparam int RV_KLIN_B = 4;
    localparam int RV_KLIN_C = 5;
    localparam int RV_KLIN_D = 6;
    localparam int RV_KLIN_E = 7;


    // =========================================================================
    // DUT pins
    // =========================================================================
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

    // =========================================================================
    // Scoreboard
    // =========================================================================
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
            $display("==================================================");
            $display("TOTAL PASS = %0d", pass);
            $display("TOTAL FAIL = %0d", fail);
            $display("==================================================");
            $finish;
        end
    end
    endtask

    // =========================================================================
    // Access helpers
    // =========================================================================
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

    // -------------------------------------------------------------------------
    // ASSUMED calibration header format
    // [31:16] = CAL_HDR_TAG
    // [15:14] = batch_id
    // [13:11] = cal_kind
    // [10:0]  = reserved
    //
    // If your unchanged cal_loader format differs, edit THIS function only.
    // -------------------------------------------------------------------------
    function automatic logic [31:0] build_cal_header_word(
        input cal_rowid_e  cal_row_id,
        input logic [1:0]  batch_id
    );
        build_cal_header_word = {8'hFF, 8'h02, batch_id, 4'b0000, cal_row_id[9:0]};
    endfunction

    // Distinctive raw row pattern:
    // sample = row_num*1_000_000 + batch_id*100_000 + sample_idx
    function automatic logic [31:0] patterned_input_sample_value(
        input int row_num,
        input int batch_id,
        input int sample_idx
    );
        patterned_input_sample_value =
            (row_num  * 32'd1000000) +
            (batch_id * 32'd100000)  +
            sample_idx[31:0];
    endfunction

    // DSP now returns first 512 samples unchanged:
    // tx_global_idx 0..255   => original batch 0 samples 0..255
    // tx_global_idx 256..511 => original batch 1 samples 0..255
    function automatic logic [31:0] expected_tx_sample_value_patterned(
        input int row_num,
        input int tx_global_idx
    );
        int batch_id;
        int sample_idx;
    begin
        batch_id   = tx_global_idx / 256; // 0 or 1
        sample_idx = tx_global_idx % 256;

        expected_tx_sample_value_patterned =
            (row_num  * 32'd1000000) +
            (batch_id * 32'd100000)  +
            sample_idx[31:0];
    end
    endfunction

    // Deterministic calibration pattern
    function automatic logic [31:0] patterned_cal_sample_value(
        input cal_rowid_e cal_row_id,
        input int         seed,
        input int         batch_id,
        input int         sample_idx
    );
        patterned_cal_sample_value =
            (32'(cal_row_id) * 32'd10000000) +
            (seed            * 32'd100000)   +
            (batch_id        * 32'd1000)     +
            sample_idx[31:0];
    endfunction

    // =========================================================================
    // TX capture
    // =========================================================================
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

    // =========================================================================
    // Calibration write-bus monitors into dsp_core
    // =========================================================================
    typedef struct packed {
        logic [9:0]  addr;
        logic [31:0] data;
    } wr32_t;

    typedef struct packed {
        logic [9:0]  addr;
        logic [9:0]  data;
    } wr10_t;

    typedef struct packed {
        logic [9:0]  addr;
        logic [17:0] data;
    } wr18_t;

    wr32_t bg_writes[$];
    wr32_t disp_a_writes[$];
    wr32_t disp_b_writes[$];
    wr32_t klin_a_writes32[$];
    wr32_t klin_b_writes32[$];
    wr32_t klin_c_writes32[$];
    wr32_t klin_d_writes32[$];
    wr32_t klin_e_writes32[$];

    task automatic clear_cal_write_logs;
    begin
        bg_writes.delete();
        disp_a_writes.delete();
        disp_b_writes.delete();
        klin_a_writes32.delete();
        klin_b_writes32.delete();
        klin_c_writes32.delete();
        klin_d_writes32.delete();
        klin_e_writes32.delete();
    end
    endtask

    always @(posedge dut.clk_100mhz) begin
        if (dut.axis_reset) begin
            clear_cal_write_logs();
        end else begin
            if (dut.bg_wr_en     && dut.bg_wr_we[0])     bg_writes.push_back('{dut.bg_wr_addr,     dut.bg_wr_data});
            if (dut.disp_a_wr_en && dut.disp_a_wr_we[0]) disp_a_writes.push_back('{dut.disp_a_wr_addr, dut.disp_a_wr_data});
            if (dut.disp_b_wr_en && dut.disp_b_wr_we[0]) disp_b_writes.push_back('{dut.disp_b_wr_addr, dut.disp_b_wr_data});
            if (dut.klin_a_wr_en && dut.klin_a_wr_we[0]) klin_a_writes32.push_back('{dut.klin_a_wr_addr, dut.klin_a_wr_data});
            if (dut.klin_b_wr_en && dut.klin_b_wr_we[0]) klin_b_writes32.push_back('{dut.klin_b_wr_addr, dut.klin_b_wr_data});
            if (dut.klin_c_wr_en && dut.klin_c_wr_we[0]) klin_c_writes32.push_back('{dut.klin_c_wr_addr, dut.klin_c_wr_data});
            if (dut.klin_d_wr_en && dut.klin_d_wr_we[0]) klin_d_writes32.push_back('{dut.klin_d_wr_addr, dut.klin_d_wr_data});
            if (dut.klin_e_wr_en && dut.klin_e_wr_we[0]) klin_e_writes32.push_back('{dut.klin_e_wr_addr, dut.klin_e_wr_data});
        end
    end

    // =========================================================================
    // RX injection via eth_io sim shim
    // =========================================================================
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

        do @(posedge dut.clk_100mhz);
        while (!(dut.eth_io.tb_udp_rx_hdr_valid && dut.eth_io.udp_rx_hdr_ready));

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

        do @(posedge dut.clk_100mhz);
        while (!(dut.eth_io.tb_udp_rx_tvalid && dut.eth_io.udp_rx_tready));

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

    task automatic send_raw_app_packet_patterned(
        input logic [9:0]  row_id,
        input int          row_num,
        input logic [1:0]  batch_id,
        input logic [31:0] src_ip,
        input logic [15:0] src_port,
        input logic [15:0] dest_port
    );
        integer i;
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
            data_val = patterned_input_sample_value(row_num, batch_id, i);

            send_udp_byte(data_val[7:0],   1'b0);
            send_udp_byte(data_val[15:8],  1'b0);
            send_udp_byte(data_val[23:16], 1'b0);
            send_udp_byte(data_val[31:24], (i == RX_BATCH_SAMPLES-1));
        end
    end
    endtask

    task automatic send_full_row_patterned(
        input logic [9:0]  rx_row_id,
        input int          row_num,
        input int          gap0,
        input int          gap1,
        input int          gap2,
        input int          gap3,
        input logic [31:0] src_ip,
        input logic [15:0] src_port,
        input logic [15:0] dest_port
    );
    begin
        send_raw_app_packet_patterned(rx_row_id, row_num, 2'd0, src_ip, src_port, dest_port);
        idle_udp(gap0);

        send_raw_app_packet_patterned(rx_row_id, row_num, 2'd1, src_ip, src_port, dest_port);
        idle_udp(gap1);

        send_raw_app_packet_patterned(rx_row_id, row_num, 2'd2, src_ip, src_port, dest_port);
        idle_udp(gap2);

        send_raw_app_packet_patterned(rx_row_id, row_num, 2'd3, src_ip, src_port, dest_port);
        idle_udp(gap3);
    end
    endtask

    task automatic send_cal_packet_patterned(
        input cal_rowid_e    cal_row_id,
        input int            seed,
        input logic [1:0]    batch_id,
        input logic [31:0]   src_ip,
        input logic [15:0]   src_port,
        input logic [15:0]   dest_port
    );
        integer i;
        logic [31:0] hdr;
        logic [31:0] data_val;
    begin
        send_udp_header(src_ip, src_port, dest_port);

        hdr = build_cal_header_word(cal_row_id, batch_id);

        send_udp_byte(hdr[7:0],   1'b0);
        send_udp_byte(hdr[15:8],  1'b0);
        send_udp_byte(hdr[23:16], 1'b0);
        send_udp_byte(hdr[31:24], 1'b0);

        for (i = 0; i < CAL_BATCH_SAMPLES; i = i + 1) begin
            data_val = patterned_cal_sample_value(cal_row_id, seed, batch_id, i);

            send_udp_byte(data_val[7:0],   1'b0);
            send_udp_byte(data_val[15:8],  1'b0);
            send_udp_byte(data_val[23:16], 1'b0);
            send_udp_byte(data_val[31:24], (i == CAL_BATCH_SAMPLES-1));
        end
    end
    endtask

    task automatic send_full_cal_set_patterned(
        input cal_rowid_e    cal_row_id,
        input int            seed,
        input logic [31:0]   src_ip,
        input logic [15:0]   src_port,
        input logic [15:0]   dest_port,
        input int            g0,
        input int            g1,
        input int            g2,
        input int            g3
    );
    begin
        send_cal_packet_patterned(cal_row_id, seed, 2'd0, src_ip, src_port, dest_port);
        idle_udp(g0);
        send_cal_packet_patterned(cal_row_id, seed, 2'd1, src_ip, src_port, dest_port);
        idle_udp(g1);
        send_cal_packet_patterned(cal_row_id, seed, 2'd2, src_ip, src_port, dest_port);
        idle_udp(g2);
        send_cal_packet_patterned(cal_row_id, seed, 2'd3, src_ip, src_port, dest_port);
        idle_udp(g3);
    end
    endtask

    task automatic send_partial_cal_set_patterned(
        input cal_rowid_e    cal_row_id,
        input int            seed,
        input int            num_batches,
        input logic [31:0]   src_ip,
        input logic [15:0]   src_port,
        input logic [15:0]   dest_port
    );
        int b;
    begin
        for (b = 0; b < num_batches; b = b + 1) begin
            send_cal_packet_patterned(cal_row_id, seed, b[1:0], src_ip, src_port, dest_port);
            idle_udp(1);
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

    task automatic wait_for_runtime_valid_mask(
        input logic [7:0] mask,
        input logic [7:0] exp_value,
        input int         timeout_cycles,
        output bit        ok
    );
        int i;
    begin
        ok = 0;
        for (i = 0; i < timeout_cycles; i = i + 1) begin
            @(posedge dut.clk_100mhz);
            if ((dut.runtime_valid & mask) == (exp_value & mask)) begin
                ok = 1;
                return;
            end
        end
    end
    endtask

    // =========================================================================
    // Payload checking
    // =========================================================================
    task automatic check_single_packet_payload_patterned(
        input int         pkt_idx,
        input logic [9:0] exp_tx_row_id,
        input int         row_num
    );
        int s;
        int base_byte;
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
            base_byte  = 4 + (s * 4);
            global_idx = pkt_idx * TX_BATCH_SAMPLES + s;

            got_data = bytes_to_u32_le(tx_pkts[pkt_idx][base_byte+0],
                                       tx_pkts[pkt_idx][base_byte+1],
                                       tx_pkts[pkt_idx][base_byte+2],
                                       tx_pkts[pkt_idx][base_byte+3]);

            exp_data = expected_tx_sample_value_patterned(row_num, global_idx);

            expect_local(got_data == exp_data,
                         $sformatf("packet %0d sample %0d correct exp=%0d got=%0d",
                                   pkt_idx, s, exp_data, got_data));
        end
    end
    endtask

    task automatic check_row_tx_patterned(
        input logic [9:0]  exp_tx_row_id,
        input int          row_num,
        input logic [31:0] exp_dest_ip,
        input logic [15:0] exp_dest_port
    );
        int i;
    begin
        expect_local(tx_hdr_q.size() == TX_PACKETS_PER_ROW, "saw 2 TX headers");
        expect_local(tx_pkts.size()  == TX_PACKETS_PER_ROW, "captured 2 TX packets");

        for (i = 0; i < tx_hdr_q.size(); i = i + 1) begin
            expect_local(tx_hdr_q[i].dest_ip   == exp_dest_ip,      $sformatf("packet %0d dest IP correct", i));
            expect_local(tx_hdr_q[i].src_port  == APP_UDP_PORT,     $sformatf("packet %0d src port correct", i));
            expect_local(tx_hdr_q[i].dest_port == exp_dest_port,    $sformatf("packet %0d dest port correct", i));
            expect_local(tx_hdr_q[i].length    == BYTES_PER_PACKET, $sformatf("packet %0d length correct", i));

            check_single_packet_payload_patterned(i, exp_tx_row_id, row_num);
        end
    end
    endtask

    // =========================================================================
    // Shadow-memory checking
    // =========================================================================

    task automatic check_bg_shadow_range(
        input int start_idx,
        input int count,
        input int seed
    );
        int i;
        logic [31:0] exp_data;
    begin
        for (i = 0; i < count; i = i + 1) begin
            exp_data = patterned_cal_sample_value(CAL_BG_ROWID, seed, (start_idx+i)/256, (start_idx+i)%256);
            expect_local(dut.dsp_core.bg_shadow[start_idx+i] === exp_data,
                $sformatf("bg_shadow[%0d] matches expected 0x%08x", start_idx+i, exp_data));
        end
    end
    endtask

    task automatic check_klin_a_shadow_range(
        input int start_idx,
        input int count,
        input int seed
    );
        int i;
        logic [31:0] exp_data32;
        logic [9:0]  exp_data10;
    begin
        for (i = 0; i < count; i = i + 1) begin
            exp_data32 = patterned_cal_sample_value(CAL_KLIN_A_ROWID, seed, (start_idx+i)/256, (start_idx+i)%256);
            exp_data10 = exp_data32[9:0];
            expect_local(dut.dsp_core.klin_a_shadow[start_idx+i] === exp_data10,
                $sformatf("klin_a_shadow[%0d] matches expected 0x%03x", start_idx+i, exp_data10));
        end
    end
    endtask

    task automatic check_klin_b_shadow_range(
        input int start_idx,
        input int count,
        input int seed
    );
        int i;
        logic [31:0] exp_data32;
        logic [17:0] exp_data18;
    begin
        for (i = 0; i < count; i = i + 1) begin
            exp_data32 = patterned_cal_sample_value(CAL_KLIN_B_ROWID, seed, (start_idx+i)/256, (start_idx+i)%256);
            exp_data18 = exp_data32[17:0];
            expect_local(dut.dsp_core.klin_b_shadow[start_idx+i] === exp_data18,
                $sformatf("klin_b_shadow[%0d] matches expected 0x%05x", start_idx+i, exp_data18));
        end
    end
    endtask

    task automatic check_klin_c_shadow_range(
        input int start_idx,
        input int count,
        input int seed
    );
        int i;
        logic [31:0] exp_data32;
        logic [17:0] exp_data18;
    begin
        for (i = 0; i < count; i = i + 1) begin
            exp_data32 = patterned_cal_sample_value(CAL_KLIN_C_ROWID, seed, (start_idx+i)/256, (start_idx+i)%256);
            exp_data18 = exp_data32[17:0];
            expect_local(dut.dsp_core.klin_c_shadow[start_idx+i] === exp_data18,
                $sformatf("klin_c_shadow[%0d] matches expected 0x%05x", start_idx+i, exp_data18));
        end
    end
    endtask

    task automatic check_klin_d_shadow_range(
        input int start_idx,
        input int count,
        input int seed
    );
        int i;
        logic [31:0] exp_data32;
        logic [17:0] exp_data18;
    begin
        for (i = 0; i < count; i = i + 1) begin
            exp_data32 = patterned_cal_sample_value(CAL_KLIN_D_ROWID, seed, (start_idx+i)/256, (start_idx+i)%256);
            exp_data18 = exp_data32[17:0];
            expect_local(dut.dsp_core.klin_d_shadow[start_idx+i] === exp_data18,
                $sformatf("klin_d_shadow[%0d] matches expected 0x%05x", start_idx+i, exp_data18));
        end
    end
    endtask

    task automatic check_klin_e_shadow_range(
        input int start_idx,
        input int count,
        input int seed
    );
        int i;
        logic [31:0] exp_data32;
        logic [17:0] exp_data18;
    begin
        for (i = 0; i < count; i = i + 1) begin
            exp_data32 = patterned_cal_sample_value(CAL_KLIN_E_ROWID, seed, (start_idx+i)/256, (start_idx+i)%256);
            exp_data18 = exp_data32[17:0];
            expect_local(dut.dsp_core.klin_e_shadow[start_idx+i] === exp_data18,
                $sformatf("klin_e_shadow[%0d] matches expected 0x%05x", start_idx+i, exp_data18));
        end
    end
    endtask

    // =========================================================================
    // Reset helper
    // =========================================================================
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
        clear_cal_write_logs();
    end
    endtask

    // =========================================================================
    // End-to-end row helper
    // =========================================================================
    task automatic run_and_check_row(
        input logic [9:0] rx_row_id,
        input logic [9:0] exp_tx_row_id,
        input int         row_num,
        input int         gap0,
        input int         gap1,
        input int         gap2,
        input int         gap3
    );
        bit ok;
    begin
        clear_tx_capture();

        send_full_row_patterned(
            rx_row_id,
            row_num,
            gap0, gap1, gap2, gap3,
            32'hC0A80A63,
            16'd6000,
            APP_UDP_PORT
        );

        wait_for_tx_packets(2, 80000, ok);
        fatal_if_fail(ok,
            $sformatf("received all 2 TX packets for row_num=%0d exp_tx_row_id=%0d",
                      row_num, exp_tx_row_id));

        check_row_tx_patterned(exp_tx_row_id, row_num, 32'hC0A80A63, 16'd6000);
    end
    endtask

    // =========================================================================
    // Main
    // =========================================================================
    integer r;
    bit ok;
    logic [7:0] mask;

    initial begin
        reset_top();

        expect_local(dut.pll_locked == 1'b1, "PLL locked");
        expect_local(phy_rst_n == 1'b1, "PHY reset released");
        expect_local(my_led == dut.runtime_valid, "LEDs mirror runtime_valid after reset");

        // ---------------------------------------------------------------------
        // TEST 1: wrong app port ignored
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 1: wrong app port ignored");
        $display("==================================================");

        clear_tx_capture();
        send_raw_app_packet_patterned(10'd3, 999, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5002);
        wait_clk100(300);
        expect_local(tx_hdr_q.size() == 0, "wrong-port packet produced no TX headers");
        expect_local(tx_pkts.size()  == 0, "wrong-port packet produced no TX packets");

        // ---------------------------------------------------------------------
        // TEST 2: one full row end-to-end, first-512 behavior
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 2: one full row end-to-end");
        $display("==================================================");

        reset_top();
        run_and_check_row(10'd11, 10'd0, 0, 1, 1, 1, 1);

        // ---------------------------------------------------------------------
        // TEST 3: multiple consecutive rows with compact gaps
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 3: 6 consecutive rows with compact gaps");
        $display("==================================================");

        reset_top();

        for (r = 0; r < 6; r = r + 1) begin
            run_and_check_row(
                10'(r + 20),
                10'(r),
                r,
                0, 1, 0, 0
            );
        end

        // ---------------------------------------------------------------------
        // TEST 4: successful BG calibration reaches dsp_core shadow memory,
        //         sets runtime_valid bit, and LEDs mirror it
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 4: BG calibration load reaches dsp_core");
        $display("==================================================");

        reset_top();
        clear_cal_write_logs();

        send_full_cal_set_patterned(CAL_BG_ROWID, 17, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 1, 1, 1, 1);

        mask = 8'(1 << RV_BG);
        wait_for_runtime_valid_mask(mask, mask, 20000, ok);
        wait_clk100(2);
        fatal_if_fail(ok, "runtime_valid BG bit asserted after full BG load");
        
        expect_local(my_led == dut.runtime_valid, "LEDs mirror runtime_valid after BG load");
        expect_local(dut.runtime_valid[RV_BG] == 1'b1, "BG runtime_valid bit high");
        expect_local(bg_writes.size() == 1024, "BG write bus saw 1024 writes");
        expect_local(dut.dsp_core.bg_shadow[0]    === patterned_cal_sample_value(CAL_BG_ROWID, 17, 0, 0),   "BG shadow[0] correct");
        expect_local(dut.dsp_core.bg_shadow[255]  === patterned_cal_sample_value(CAL_BG_ROWID, 17, 0, 255), "BG shadow[255] correct");
        expect_local(dut.dsp_core.bg_shadow[256]  === patterned_cal_sample_value(CAL_BG_ROWID, 17, 1, 0),   "BG shadow[256] correct");
        expect_local(dut.dsp_core.bg_shadow[511]  === patterned_cal_sample_value(CAL_BG_ROWID, 17, 1, 255), "BG shadow[511] correct");
        expect_local(dut.dsp_core.bg_shadow[512]  === patterned_cal_sample_value(CAL_BG_ROWID, 17, 2, 0),   "BG shadow[512] correct");
        expect_local(dut.dsp_core.bg_shadow[767]  === patterned_cal_sample_value(CAL_BG_ROWID, 17, 2, 255), "BG shadow[767] correct");
        expect_local(dut.dsp_core.bg_shadow[768]  === patterned_cal_sample_value(CAL_BG_ROWID, 17, 3, 0),   "BG shadow[768] correct");
        expect_local(dut.dsp_core.bg_shadow[1023] === patterned_cal_sample_value(CAL_BG_ROWID, 17, 3, 255), "BG shadow[1023] correct");

        // ---------------------------------------------------------------------
        // TEST 5: representative k-lin loads reach dsp_core shadow memories
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 5: k-lin calibration loads reach dsp_core");
        $display("==================================================");

        clear_cal_write_logs();

        send_full_cal_set_patterned(CAL_KLIN_A_ROWID, 21, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_KLIN_B_ROWID, 22, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_KLIN_C_ROWID, 23, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_KLIN_D_ROWID, 24, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_KLIN_E_ROWID, 25, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        
        mask = 8'((1 << RV_KLIN_A) | (1 << RV_KLIN_B) | (1 << RV_KLIN_C) | (1 << RV_KLIN_D) | (1 << RV_KLIN_E));
        wait_for_runtime_valid_mask(mask, mask, 80000, ok);
        wait_clk100(2);
        fatal_if_fail(ok, "all representative k-lin runtime_valid bits asserted");

        expect_local(klin_a_writes32.size() == 1024, "KLIN_A write bus saw 1024 writes");
        expect_local(klin_b_writes32.size() == 1024, "KLIN_B write bus saw 1024 writes");
        expect_local(klin_c_writes32.size() == 1024, "KLIN_C write bus saw 1024 writes");
        expect_local(klin_d_writes32.size() == 1024, "KLIN_D write bus saw 1024 writes");
        expect_local(klin_e_writes32.size() == 1024, "KLIN_E write bus saw 1024 writes");

        expect_local(dut.dsp_core.klin_a_shadow[0]    === patterned_cal_sample_value(CAL_KLIN_A_ROWID, 21, 0, 0)[9:0],    "klin_a_shadow[0] correct");
        expect_local(dut.dsp_core.klin_a_shadow[1023] === patterned_cal_sample_value(CAL_KLIN_A_ROWID, 21, 3, 255)[9:0],  "klin_a_shadow[1023] correct");
        expect_local(dut.dsp_core.klin_b_shadow[0]    === patterned_cal_sample_value(CAL_KLIN_B_ROWID, 22, 0, 0)[17:0],   "klin_b_shadow[0] correct");
        expect_local(dut.dsp_core.klin_b_shadow[1023] === patterned_cal_sample_value(CAL_KLIN_B_ROWID, 22, 3, 255)[17:0], "klin_b_shadow[1023] correct");
        expect_local(dut.dsp_core.klin_c_shadow[0]    === patterned_cal_sample_value(CAL_KLIN_C_ROWID, 23, 0, 0)[17:0],   "klin_c_shadow[0] correct");
        expect_local(dut.dsp_core.klin_c_shadow[1023] === patterned_cal_sample_value(CAL_KLIN_C_ROWID, 23, 3, 255)[17:0], "klin_c_shadow[1023] correct");
        expect_local(dut.dsp_core.klin_d_shadow[0]    === patterned_cal_sample_value(CAL_KLIN_D_ROWID, 24, 0, 0)[17:0],   "klin_d_shadow[0] correct");
        expect_local(dut.dsp_core.klin_d_shadow[1023] === patterned_cal_sample_value(CAL_KLIN_D_ROWID, 24, 3, 255)[17:0], "klin_d_shadow[1023] correct");
        expect_local(dut.dsp_core.klin_e_shadow[0]    === patterned_cal_sample_value(CAL_KLIN_E_ROWID, 25, 0, 0)[17:0],   "klin_e_shadow[0] correct");
        expect_local(dut.dsp_core.klin_e_shadow[1023] === patterned_cal_sample_value(CAL_KLIN_E_ROWID, 25, 3, 255)[17:0], "klin_e_shadow[1023] correct");

        expect_local(my_led == dut.runtime_valid, "LEDs mirror runtime_valid after k-lin loads");

        // ---------------------------------------------------------------------
        // TEST 6: DISP loads affect validity / LEDs even though dsp_core ignores
        //         internal storage for them in current shell
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 6: DISP calibration validity and LED mirror");
        $display("==================================================");

        clear_cal_write_logs();
        
        // TEST 6
        send_full_cal_set_patterned(CAL_DISP_A_ROWID, 31, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 1, 0, 1);
        send_full_cal_set_patterned(CAL_DISP_B_ROWID, 32, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 1, 0, 1, 0);
        
        mask = 8'((1 << RV_DISP_A) | (1 << RV_DISP_B));
        wait_for_runtime_valid_mask(mask, mask, 50000, ok);
        wait_clk100(2);
        fatal_if_fail(ok, "DISP runtime_valid bits asserted");

        expect_local(disp_a_writes.size() == 1024, "DISP_A write bus saw 1024 writes");
        expect_local(disp_b_writes.size() == 1024, "DISP_B write bus saw 1024 writes");
        expect_local(my_led == dut.runtime_valid, "LEDs mirror runtime_valid after DISP loads");

        // ---------------------------------------------------------------------
        // TEST 7: failed/incomplete calibration clears runtime_valid bit but does
        //         not block DSP row processing
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 7: incomplete calibration clears valid but DSP still runs");
        $display("==================================================");

        reset_top();
        clear_cal_write_logs();

        // First establish a valid BG load.
        send_full_cal_set_patterned(CAL_BG_ROWID, 40, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);

        mask = 8'(1 << RV_BG);
        wait_for_runtime_valid_mask(mask, mask, 30000, ok);
        wait_clk100(2);
        fatal_if_fail(ok, "BG valid bit asserted after full baseline BG load");
        expect_local(dut.runtime_valid[RV_BG] == 1'b1, "BG valid high before incomplete overwrite");

        // Now send only 3/4 packets of a new BG load.
        clear_cal_write_logs();
        send_partial_cal_set_patterned(CAL_BG_ROWID, 41, 3, 32'hC0A80A63, 16'd6000, APP_UDP_PORT);

        // Expect the cal_loader policy to clear runtime_valid for BG.
        wait_for_runtime_valid_mask(mask, 8'h00, 30000, ok);
        wait_clk100(2);
        fatal_if_fail(ok, "BG valid bit cleared after incomplete BG load");

        expect_local(dut.runtime_valid[RV_BG] == 1'b0, "BG runtime_valid bit low after incomplete load");
        expect_local(my_led == dut.runtime_valid, "LEDs mirror runtime_valid after incomplete load");

        // Shadow memory should show first 768 entries overwritten with new seed,
        // while last quarter remains from previous complete load.
        expect_local(bg_writes.size() == 768, "incomplete BG write bus saw 768 writes");
        check_bg_shadow_range(0,   768, 41);

        expect_local(dut.dsp_core.bg_shadow[768]  === patterned_cal_sample_value(CAL_BG_ROWID, 40, 3,   0), "bg_shadow[768] stayed old after incomplete load");
        expect_local(dut.dsp_core.bg_shadow[1023] === patterned_cal_sample_value(CAL_BG_ROWID, 40, 3, 255), "bg_shadow[1023] stayed old after incomplete load");

        // DSP must still process a raw row because current shell does not consult
        // runtime_valid for gating.
        run_and_check_row(10'd77, 10'd0, 700, 0, 0, 0, 0);

        // ---------------------------------------------------------------------
        // TEST 8: all valid bits -> LEDs exactly mirror full runtime_valid vector
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 8: full runtime_valid vector mirrored to LEDs");
        $display("==================================================");

        reset_top();

        send_full_cal_set_patterned(CAL_BG_ROWID,     50, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_DISP_A_ROWID, 51, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_DISP_B_ROWID, 52, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_KLIN_A_ROWID, 53, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_KLIN_B_ROWID, 54, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_KLIN_C_ROWID, 55, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_KLIN_D_ROWID, 56, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);
        send_full_cal_set_patterned(CAL_KLIN_E_ROWID, 57, 32'hC0A80A63, 16'd6000, APP_UDP_PORT, 0, 0, 0, 0);

        wait_for_runtime_valid_mask(8'hFF, 8'hFF, 120000, ok);
        wait_clk100(2);
        fatal_if_fail(ok, "all runtime_valid bits high after full calibration sweep");

        expect_local(dut.runtime_valid == 8'hFF, "runtime_valid is 0xFF");
        expect_local(my_led == 8'hFF, "my_led is 0xFF and mirrors runtime_valid");

        // ---------------------------------------------------------------------
        // Final summary
        // ---------------------------------------------------------------------
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
// Transport shim for top-level simulation only.
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
