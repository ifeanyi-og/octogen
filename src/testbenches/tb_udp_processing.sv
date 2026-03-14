
`timescale 1ns/1ps

module tb_udp_processing_top;

    localparam int APP_UDP_PORT      = 16'd5001;
    localparam int BATCH_SAMPLES     = 128;
    localparam int PACKETS_PER_ROW   = 4;
    localparam int BYTES_PER_PACKET  = 1028;
    localparam int TOTAL_ROW_BYTES   = PACKETS_PER_ROW * BYTES_PER_PACKET;

    // =========================================================================
    // Clock / reset
    // =========================================================================
    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    // =========================================================================
    // DUT I/O
    // =========================================================================
    logic        udp_rx_hdr_valid;
    logic        udp_rx_hdr_ready;
    logic [31:0] udp_rx_src_ip;
    logic [15:0] udp_rx_src_port;
    logic [15:0] udp_rx_dest_port;

    logic [7:0]  udp_rx_tdata;
    logic        udp_rx_tvalid;
    logic        udp_rx_tready;
    logic        udp_rx_tlast;

    logic        udp_tx_hdr_valid;
    logic        udp_tx_hdr_ready;
    logic [31:0] udp_tx_dest_ip;
    logic [15:0] udp_tx_src_port;
    logic [15:0] udp_tx_dest_port;
    logic [15:0] udp_tx_length;

    logic [7:0]  udp_tx_tdata;
    logic        udp_tx_tvalid;
    logic        udp_tx_tready;
    logic        udp_tx_tlast;

    logic        dsp_in_valid;
    logic        dsp_in_row_start;
    logic [31:0] dsp_in_re;
    logic [31:0] dsp_in_im;

    logic        dsp_out_valid;
    logic [31:0] dsp_out_re;
    logic [31:0] dsp_out_im;

    udp_processing_top dut (
        .clk(clk),
        .rst(rst),

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

    // =========================================================================
    // Simple DSP model: fixed latency 2, transform +1/+2
    // =========================================================================
    logic [31:0] pipe_re0, pipe_re1;
    logic [31:0] pipe_im0, pipe_im1;
    logic        pipe_v0, pipe_v1;

    always @(posedge clk) begin
        if (rst) begin
            pipe_re0      <= '0;
            pipe_re1      <= '0;
            pipe_im0      <= '0;
            pipe_im1      <= '0;
            pipe_v0       <= 1'b0;
            pipe_v1       <= 1'b0;
            dsp_out_valid <= 1'b0;
            dsp_out_re    <= '0;
            dsp_out_im    <= '0;
        end else begin
            pipe_v0  <= dsp_in_valid;
            pipe_re0 <= dsp_in_re + 32'd1;
            pipe_im0 <= dsp_in_im + 32'd2;

            pipe_v1  <= pipe_v0;
            pipe_re1 <= pipe_re0;
            pipe_im1 <= pipe_im0;

            dsp_out_valid <= pipe_v1;
            dsp_out_re    <= pipe_re1;
            dsp_out_im    <= pipe_im1;
        end
    end

    // =========================================================================
    // Pass/fail
    // =========================================================================
    int pass = 0;
    int fail = 0;

    task automatic expect_local(input bit cond, input string msg);
    begin
        if (cond) begin
            $display("PASS: %s", msg);
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

    // =========================================================================
    // Counters / observability
    // =========================================================================
    integer cycle_count;

    int parser_batch_count;
    int replay_start_count;
    int dsp_row_start_count;
    int dsp_in_count;

    int tx_hdr_count;
    int tx_byte_count;
    int tx_tlast_count;

    always @(posedge clk) begin
        if (rst) begin
            cycle_count         <= 0;
            parser_batch_count  <= 0;
            replay_start_count  <= 0;
            dsp_row_start_count <= 0;
            dsp_in_count        <= 0;
            tx_hdr_count        <= 0;
            tx_byte_count       <= 0;
            tx_tlast_count      <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (dut.sample_valid_w && dut.sample_last_w)
                parser_batch_count <= parser_batch_count + 1;

            if (dut.replay_active && (dut.replay_idx == 0))
                replay_start_count <= replay_start_count + 1;

            if (dsp_in_valid) begin
                dsp_in_count <= dsp_in_count + 1;
                if (dsp_in_row_start)
                    dsp_row_start_count <= dsp_row_start_count + 1;
            end

            if (udp_tx_hdr_valid && udp_tx_hdr_ready)
                tx_hdr_count <= tx_hdr_count + 1;

            if (udp_tx_tvalid && udp_tx_tready) begin
                tx_byte_count <= tx_byte_count + 1;
                if (udp_tx_tlast)
                    tx_tlast_count <= tx_tlast_count + 1;
            end
        end
    end

    task automatic clear_counts;
    begin
        parser_batch_count  = 0;
        replay_start_count  = 0;
        dsp_row_start_count = 0;
        dsp_in_count        = 0;
        tx_hdr_count        = 0;
        tx_byte_count       = 0;
        tx_tlast_count      = 0;
    end
    endtask


    // =========================================================================
    // TX capture / scoreboard (robust against header/payload decoupling)
    // =========================================================================
    typedef struct packed {
        logic [31:0] dest_ip;
        logic [15:0] src_port;
        logic [15:0] dest_port;
        logic [15:0] length;
    } tx_hdr_t;

    tx_hdr_t tx_hdr_q[$];       // all accepted headers, for final checks
    tx_hdr_t pending_hdr_q[$];  // headers accepted but not yet bound to a payload packet
    byte     tx_pkts[$][$];

    int active_pkt_idx;
    int active_byte_idx;
    bit active_pkt_open;
    bit saw_row_finished;

    always @(posedge clk) begin
        if (rst) begin
            tx_hdr_q.delete();
            pending_hdr_q.delete();
            tx_pkts.delete();
            active_pkt_idx     <= -1;
            active_byte_idx    <= 0;
            active_pkt_open    <= 1'b0;
            saw_row_finished   <= 1'b0;
        end else begin
            if (dut.tx_row_finished)
                saw_row_finished <= 1'b1;

            // Queue every accepted TX header.
            if (udp_tx_hdr_valid && udp_tx_hdr_ready) begin
                tx_hdr_t h;
                h.dest_ip   = udp_tx_dest_ip;
                h.src_port  = udp_tx_src_port;
                h.dest_port = udp_tx_dest_port;
                h.length    = udp_tx_length;

                tx_hdr_q.push_back(h);
                pending_hdr_q.push_back(h);
            end

            // Start a new payload packet only when the first payload byte arrives,
            // not when the header is accepted.
            if (udp_tx_tvalid && udp_tx_tready) begin
                if (!active_pkt_open) begin
                    if (pending_hdr_q.size() == 0) begin
                        $display("ERROR: payload byte observed with no pending header at cycle %0d", cycle_count);
                        fail++;
                    end else begin
                        tx_hdr_t consume_hdr;
                        consume_hdr = pending_hdr_q.pop_front();

                        tx_pkts.push_back({});
                        active_pkt_idx  <= tx_pkts.size() - 1;
                        active_byte_idx <= 0;
                        active_pkt_open <= 1'b1;

                        tx_pkts[tx_pkts.size()-1].push_back(udp_tx_tdata);

                        if (udp_tx_tlast) begin
                            if (0 != BYTES_PER_PACKET-1) begin
                                $display("ERROR: tlast at wrong byte index: got %0d expected %0d",
                                         0, BYTES_PER_PACKET-1);
                                fail++;
                            end
                            active_pkt_open <= 1'b0;
                        end else begin
                            active_byte_idx <= 1;
                        end
                    end
                end else begin
                    tx_pkts[active_pkt_idx].push_back(udp_tx_tdata);

                    if (udp_tx_tlast) begin
                        if (active_byte_idx != BYTES_PER_PACKET-1) begin
                            $display("ERROR: tlast at wrong byte index: got %0d expected %0d",
                                     active_byte_idx, BYTES_PER_PACKET-1);
                            fail++;
                        end
                        active_pkt_open <= 1'b0;
                    end else begin
                        if (active_byte_idx == BYTES_PER_PACKET-1) begin
                            $display("ERROR: packet exceeded %0d bytes without tlast", BYTES_PER_PACKET);
                            fail++;
                            active_pkt_open <= 1'b0;
                        end else begin
                            active_byte_idx <= active_byte_idx + 1;
                        end
                    end
                end
            end
        end
    end

    task automatic clear_tx_capture;
    begin
        tx_hdr_q.delete();
        pending_hdr_q.delete();
        tx_pkts.delete();
        active_pkt_idx   = -1;
        active_byte_idx  = 0;
        active_pkt_open  = 0;
        saw_row_finished = 0;
    end
    endtask

    task automatic dump_tx_packet_sizes;
        int i;
    begin
        $display("TX PACKET SIZE SUMMARY:");
        $display("  headers accepted      = %0d", tx_hdr_q.size());
        $display("  pending headers       = %0d", pending_hdr_q.size());
        $display("  packets captured      = %0d", tx_pkts.size());
        $display("  active_pkt_open       = %0b", active_pkt_open);
        for (i = 0; i < tx_pkts.size(); i++) begin
            $display("  packet[%0d] bytes     = %0d", i, tx_pkts[i].size());
        end
    end
    endtask

    function automatic logic [31:0] bytes_to_u32_le(
        input byte b0, input byte b1, input byte b2, input byte b3
    );
        bytes_to_u32_le = {b3, b2, b1, b0};
    endfunction

    function automatic logic [31:0] expected_header_word(
        input logic [9:0] row_id,
        input logic [1:0] batch_id
    );
        expected_header_word = {8'hFF, 8'hFF, batch_id, 4'b0000, row_id};
    endfunction

    task automatic check_single_packet_payload(
        input int pkt_idx,
        input logic [9:0] exp_row_id
    );
        int s;
        logic [31:0] hdr_word;
        logic [31:0] exp_hdr_word;
        logic [31:0] got_re, got_im;
        logic [31:0] exp_re, exp_im;
    begin
        expect_local(pkt_idx < tx_pkts.size(), $sformatf("packet %0d captured", pkt_idx));
        if (pkt_idx >= tx_pkts.size())
            return;

        expect_local(tx_pkts[pkt_idx].size() == BYTES_PER_PACKET,
                     $sformatf("packet %0d has %0d bytes", pkt_idx, BYTES_PER_PACKET));
        if (tx_pkts[pkt_idx].size() != BYTES_PER_PACKET)
            return;

        hdr_word     = bytes_to_u32_le(tx_pkts[pkt_idx][0], tx_pkts[pkt_idx][1], tx_pkts[pkt_idx][2], tx_pkts[pkt_idx][3]);
        exp_hdr_word = expected_header_word(exp_row_id, pkt_idx[1:0]);

        expect_local(hdr_word == exp_hdr_word,
                     $sformatf("packet %0d app header matches row=%0d batch=%0d", pkt_idx, exp_row_id, pkt_idx));

        for (s = 0; s < BATCH_SAMPLES; s++) begin
            int base;
            int global_idx;
            base = 4 + (s * 8);
            global_idx = pkt_idx * BATCH_SAMPLES + s;

            got_re = bytes_to_u32_le(tx_pkts[pkt_idx][base+0],
                                     tx_pkts[pkt_idx][base+1],
                                     tx_pkts[pkt_idx][base+2],
                                     tx_pkts[pkt_idx][base+3]);

            got_im = bytes_to_u32_le(tx_pkts[pkt_idx][base+4],
                                     tx_pkts[pkt_idx][base+5],
                                     tx_pkts[pkt_idx][base+6],
                                     tx_pkts[pkt_idx][base+7]);

            exp_re = global_idx + 32'd1;
            exp_im = global_idx + 32'd1002;

            if (got_re !== exp_re) begin
                $display("FAIL: packet %0d sample %0d RE mismatch got=%08h exp=%08h",
                         pkt_idx, s, got_re, exp_re);
                fail++;
            end else begin
                pass++;
            end

            if (got_im !== exp_im) begin
                $display("FAIL: packet %0d sample %0d IM mismatch got=%08h exp=%08h",
                         pkt_idx, s, got_im, exp_im);
                fail++;
            end else begin
                pass++;
            end
        end
    end
    endtask
    
    task automatic check_row_tx(
        input logic [9:0]  exp_row_id,
        input logic [31:0] exp_dest_ip,
        input logic [15:0] exp_dest_port
    );
        int i;
    begin
        expect_local(tx_hdr_q.size() == PACKETS_PER_ROW, "saw 4 TX headers");
        expect_local(tx_pkts.size()  == PACKETS_PER_ROW, "captured 4 TX packets");
        expect_local(tx_hdr_count    == PACKETS_PER_ROW, "header count is 4");
        expect_local(tx_tlast_count  == PACKETS_PER_ROW, "tlast count is 4");
        expect_local(tx_byte_count   == TOTAL_ROW_BYTES, "total TX bytes is 4112");
        expect_local(saw_row_finished, "row finished pulse observed");

        for (i = 0; i < tx_hdr_q.size(); i++) begin
            expect_local(tx_hdr_q[i].dest_ip   == exp_dest_ip,
                         $sformatf("packet %0d dest IP correct", i));
            expect_local(tx_hdr_q[i].src_port  == APP_UDP_PORT,
                         $sformatf("packet %0d src port correct", i));
            expect_local(tx_hdr_q[i].dest_port == exp_dest_port,
                         $sformatf("packet %0d dest port correct", i));
            expect_local(tx_hdr_q[i].length    == BYTES_PER_PACKET,
                         $sformatf("packet %0d length correct", i));

            check_single_packet_payload(i, exp_row_id);
        end

        expect_local(pending_hdr_q.size() == 0, "no leftover pending TX headers");
        expect_local(!active_pkt_open, "no partially open TX packet remains");
    end
    endtask

    task automatic wait_for_tx_packets(input int exp_packets, input int timeout_cycles, output bit ok);
        int i;
    begin
        ok = 0;
        for (i = 0; i < timeout_cycles; i++) begin
            @(posedge clk);
            if ((tx_pkts.size() >= exp_packets) &&
                (pending_hdr_q.size() == 0) &&
                (!active_pkt_open)) begin
                ok = 1;
                return;
            end
        end
    end
    endtask

    // =========================================================================
    // RX helpers
    // =========================================================================
    task automatic idle_rx(input int cycles);
        int i;
    begin
        for (i = 0; i < cycles; i++) begin
            @(posedge clk);
            udp_rx_hdr_valid <= 1'b0;
            udp_rx_tvalid    <= 1'b0;
            udp_rx_tlast     <= 1'b0;
            udp_rx_tdata     <= 8'h00;
        end
    end
    endtask

    task automatic send_udp_header(
        input logic [31:0] src_ip,
        input logic [15:0] src_port,
        input logic [15:0] dest_port
    );
    begin
        while (!udp_rx_hdr_ready)
            @(posedge clk);

        udp_rx_hdr_valid <= 1'b1;
        udp_rx_src_ip    <= src_ip;
        udp_rx_src_port  <= src_port;
        udp_rx_dest_port <= dest_port;

        do @(posedge clk); while (!(udp_rx_hdr_valid && udp_rx_hdr_ready));
        udp_rx_hdr_valid <= 1'b0;
    end
    endtask

    task automatic send_udp_byte(input byte b, input bit last);
    begin
        while (!udp_rx_tready)
            @(posedge clk);

        udp_rx_tdata  <= b;
        udp_rx_tvalid <= 1'b1;
        udp_rx_tlast  <= last;

        do @(posedge clk); while (!(udp_rx_tvalid && udp_rx_tready));

        udp_rx_tvalid <= 1'b0;
        udp_rx_tlast  <= 1'b0;
        udp_rx_tdata  <= 8'h00;
    end
    endtask

    task automatic send_app_packet(
        input logic [9:0]  row_id,
        input logic [1:0]  batch_id,
        input logic [31:0] src_ip,
        input logic [15:0] src_port,
        input logic [15:0] dest_port
    );
        int i;
        int global_idx;
        logic [31:0] hdr;
        logic [31:0] re_val;
        logic [31:0] im_val;
    begin
        send_udp_header(src_ip, src_port, dest_port);

        hdr = expected_header_word(row_id, batch_id);

        send_udp_byte(hdr[7:0],   1'b0);
        send_udp_byte(hdr[15:8],  1'b0);
        send_udp_byte(hdr[23:16], 1'b0);
        send_udp_byte(hdr[31:24], 1'b0);

        for (i = 0; i < BATCH_SAMPLES; i++) begin
            global_idx = batch_id * BATCH_SAMPLES + i;
            re_val = global_idx;
            im_val = global_idx + 1000;

            send_udp_byte(re_val[7:0],   1'b0);
            send_udp_byte(re_val[15:8],  1'b0);
            send_udp_byte(re_val[23:16], 1'b0);
            send_udp_byte(re_val[31:24], 1'b0);

            send_udp_byte(im_val[7:0],   1'b0);
            send_udp_byte(im_val[15:8],  1'b0);
            send_udp_byte(im_val[23:16], 1'b0);
            send_udp_byte(im_val[31:24], (i == BATCH_SAMPLES-1));
        end
    end
    endtask

    // =========================================================================
    // TX backpressure generators
    // =========================================================================
    task automatic run_tx_ready_always_on;
    begin
        udp_tx_hdr_ready = 1'b1;
        udp_tx_tready    = 1'b1;
    end
    endtask

    task automatic run_tx_random_backpressure(input int cycles);
        int i;
    begin
        for (i = 0; i < cycles; i++) begin
            @(posedge clk);
            udp_tx_hdr_ready <= $urandom_range(0,1);
            udp_tx_tready    <= $urandom_range(0,1);
        end
        udp_tx_hdr_ready <= 1'b1;
        udp_tx_tready    <= 1'b1;
    end
    endtask

    // =========================================================================
    // Test wrapper reset
    // =========================================================================
    task automatic reset_dut;
    begin
        rst <= 1'b1;
        udp_rx_hdr_valid <= 1'b0;
        udp_rx_src_ip    <= '0;
        udp_rx_src_port  <= '0;
        udp_rx_dest_port <= '0;
        udp_rx_tdata     <= '0;
        udp_rx_tvalid    <= 1'b0;
        udp_rx_tlast     <= 1'b0;
        udp_tx_hdr_ready <= 1'b1;
        udp_tx_tready    <= 1'b1;

        repeat (8) @(posedge clk);
        clear_counts();
        clear_tx_capture();
        rst <= 1'b0;
        repeat (4) @(posedge clk);
    end
    endtask

    // =========================================================================
    // Tests
    // =========================================================================
    task automatic test_wrong_port_ignored;
    begin
        $display("--------------------------------------------------");
        $display("TEST1: wrong port ignored");
        $display("--------------------------------------------------");

        clear_counts();
        clear_tx_capture();

        send_app_packet(10'd3, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5002);
        idle_rx(200);

        expect_local(tx_hdr_count == 0, "no TX headers");
        expect_local(tx_byte_count == 0, "no TX bytes");
        expect_local(tx_pkts.size() == 0, "no TX packets captured");
    end
    endtask

    task automatic test_one_row_exact_bytes;
        bit ok;
    begin
        $display("--------------------------------------------------");
        $display("TEST2: one row exact byte-for-byte correctness");
        $display("--------------------------------------------------");

        clear_counts();
        clear_tx_capture();
        run_tx_ready_always_on();

        send_app_packet(10'd3, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_rx(5);
        send_app_packet(10'd3, 2'd1, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_rx(5);
        send_app_packet(10'd3, 2'd2, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_rx(5);
        send_app_packet(10'd3, 2'd3, 32'hC0A80A63, 16'd6000, 16'd5001);

        wait_for_tx_packets(4, 30000, ok);
        fatal_if_fail(ok, "received all 4 TX packets");

        expect_local(parser_batch_count == 4, "parser completed 4 batches");
        expect_local(replay_start_count == 4, "replay started 4 times");
        expect_local(dsp_row_start_count == 1, "DSP row started once");
        expect_local(dsp_in_count == 512, "DSP saw 512 samples");

        dump_tx_packet_sizes();
        check_row_tx(10'd3, 32'hC0A80A63, 16'd6000);
    end
    endtask

    task automatic test_tx_backpressure_exact_bytes;
        bit ok;
    begin
        $display("--------------------------------------------------");
        $display("TEST3: TX backpressure with exact packet framing");
        $display("--------------------------------------------------");

        clear_counts();
        clear_tx_capture();

        fork
            begin
                send_app_packet(10'd9, 2'd0, 32'hC0A80A63, 16'd6001, 16'd5001);
                idle_rx(2);
                send_app_packet(10'd9, 2'd1, 32'hC0A80A63, 16'd6001, 16'd5001);
                idle_rx(2);
                send_app_packet(10'd9, 2'd2, 32'hC0A80A63, 16'd6001, 16'd5001);
                idle_rx(2);
                send_app_packet(10'd9, 2'd3, 32'hC0A80A63, 16'd6001, 16'd5001);
            end
            begin
                run_tx_random_backpressure(12000);
            end
        join

        wait_for_tx_packets(4, 40000, ok);
        fatal_if_fail(ok, "received 4 packets under backpressure");

        dump_tx_packet_sizes();
        check_row_tx(10'd9, 32'hC0A80A63, 16'd6001);
    end
    endtask

    task automatic test_route_update_same_row_new_sender;
        bit ok;
    begin
        $display("--------------------------------------------------");
        $display("TEST4: same-row route updates to latest sender");
        $display("--------------------------------------------------");

        clear_counts();
        clear_tx_capture();
        run_tx_ready_always_on();

        send_app_packet(10'd11, 2'd0, 32'hC0A80A11, 16'd6010, 16'd5001);
        idle_rx(2);
        send_app_packet(10'd11, 2'd1, 32'hC0A80A11, 16'd6010, 16'd5001);
        idle_rx(2);
        send_app_packet(10'd11, 2'd2, 32'hC0A80A11, 16'd6010, 16'd5001);
        idle_rx(2);

        // Last batch arrives from different sender; reply should go there.
        send_app_packet(10'd11, 2'd3, 32'hC0A80A22, 16'd6022, 16'd5001);

        wait_for_tx_packets(4, 30000, ok);
        fatal_if_fail(ok, "received all 4 TX packets for row 11");

        check_row_tx(10'd11, 32'hC0A80A22, 16'd6022);
    end
    endtask

    task automatic test_two_rows_sequential_routes;
        bit ok;
    begin
        $display("--------------------------------------------------");
        $display("TEST5: two sequential rows keep distinct routes");
        $display("--------------------------------------------------");

        // Row 20
        clear_counts();
        clear_tx_capture();
        run_tx_ready_always_on();

        send_app_packet(10'd20, 2'd0, 32'hC0A80114, 16'd6100, 16'd5001);
        send_app_packet(10'd20, 2'd1, 32'hC0A80114, 16'd6100, 16'd5001);
        send_app_packet(10'd20, 2'd2, 32'hC0A80114, 16'd6100, 16'd5001);
        send_app_packet(10'd20, 2'd3, 32'hC0A80114, 16'd6100, 16'd5001);

        wait_for_tx_packets(4, 30000, ok);
        fatal_if_fail(ok, "row 20 produced 4 packets");
        check_row_tx(10'd20, 32'hC0A80114, 16'd6100);

        // Row 21 after row 20 completion
        clear_counts();
        clear_tx_capture();

        send_app_packet(10'd21, 2'd0, 32'hC0A80115, 16'd6101, 16'd5001);
        send_app_packet(10'd21, 2'd1, 32'hC0A80115, 16'd6101, 16'd5001);
        send_app_packet(10'd21, 2'd2, 32'hC0A80115, 16'd6101, 16'd5001);
        send_app_packet(10'd21, 2'd3, 32'hC0A80115, 16'd6101, 16'd5001);

        wait_for_tx_packets(4, 30000, ok);
        fatal_if_fail(ok, "row 21 produced 4 packets");
        check_row_tx(10'd21, 32'hC0A80115, 16'd6101);
    end
    endtask

    task automatic test_route_reuse_after_completion;
        bit ok;
    begin
        $display("--------------------------------------------------");
        $display("TEST6: route table reused after completion");
        $display("--------------------------------------------------");

        // Complete one row
        clear_counts();
        clear_tx_capture();

        send_app_packet(10'd30, 2'd0, 32'hC0A80201, 16'd6200, 16'd5001);
        send_app_packet(10'd30, 2'd1, 32'hC0A80201, 16'd6200, 16'd5001);
        send_app_packet(10'd30, 2'd2, 32'hC0A80201, 16'd6200, 16'd5001);
        send_app_packet(10'd30, 2'd3, 32'hC0A80201, 16'd6200, 16'd5001);

        wait_for_tx_packets(4, 30000, ok);
        fatal_if_fail(ok, "row 30 complete");
        check_row_tx(10'd30, 32'hC0A80201, 16'd6200);

        // New row should not inherit stale route
        clear_counts();
        clear_tx_capture();

        send_app_packet(10'd31, 2'd0, 32'hC0A80202, 16'd6201, 16'd5001);
        send_app_packet(10'd31, 2'd1, 32'hC0A80202, 16'd6201, 16'd5001);
        send_app_packet(10'd31, 2'd2, 32'hC0A80202, 16'd6201, 16'd5001);
        send_app_packet(10'd31, 2'd3, 32'hC0A80202, 16'd6201, 16'd5001);

        wait_for_tx_packets(4, 30000, ok);
        fatal_if_fail(ok, "row 31 complete");
        check_row_tx(10'd31, 32'hC0A80202, 16'd6201);
    end
    endtask

    // =========================================================================
    // Main
    // =========================================================================
    initial begin
        udp_rx_hdr_valid = 1'b0;
        udp_rx_src_ip    = '0;
        udp_rx_src_port  = '0;
        udp_rx_dest_port = '0;
        udp_rx_tdata     = '0;
        udp_rx_tvalid    = 1'b0;
        udp_rx_tlast     = 1'b0;
        udp_tx_hdr_ready = 1'b1;
        udp_tx_tready    = 1'b1;

        reset_dut();

        test_wrong_port_ignored();
        test_one_row_exact_bytes();
        test_tx_backpressure_exact_bytes();
        test_route_update_same_row_new_sender();
        test_two_rows_sequential_routes();
        test_route_reuse_after_completion();

        $display("==================================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("==================================================");

        $finish;
    end

endmodule
