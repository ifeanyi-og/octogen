
`timescale 1ns/1ps

module tb_udp_processing_top;

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
            pipe_re0      <= 0;
            pipe_re1      <= 0;
            pipe_im0      <= 0;
            pipe_im1      <= 0;
            pipe_v0       <= 0;
            pipe_v1       <= 0;
            dsp_out_valid <= 0;
            dsp_out_re    <= 0;
            dsp_out_im    <= 0;
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
    // Scoreboard
    // =========================================================================
    int pass = 0;
    int fail = 0;

    task expect_local(input logic cond, input string msg);
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

    // =========================================================================
    // Debug controls
    // =========================================================================
    bit verbose_test2 = 1'b1;
    integer cycle_count = 0;

    int tx_hdr_count;
    int tx_byte_count;
    int tx_tlast_count;
    logic [31:0] first_tx_dest_ip;
    logic [15:0] first_tx_src_port;
    logic [15:0] first_tx_dest_port;
    logic [15:0] first_tx_length;

    int parser_batch_count;
    int replay_start_count;
    int dsp_row_start_count;
    int dsp_in_count;
    int app_tx_start_count;

    always @(posedge clk) begin
        if (rst) begin
            cycle_count         <= 0;
            tx_hdr_count        <= 0;
            tx_byte_count       <= 0;
            tx_tlast_count      <= 0;
            first_tx_dest_ip    <= 0;
            first_tx_src_port   <= 0;
            first_tx_dest_port  <= 0;
            first_tx_length     <= 0;
            parser_batch_count  <= 0;
            replay_start_count  <= 0;
            dsp_row_start_count <= 0;
            dsp_in_count        <= 0;
            app_tx_start_count  <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

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

            if (dut.sample_valid_w && dut.sample_last_w)
                parser_batch_count <= parser_batch_count + 1;

            if (dut.replay_active && dut.replay_idx == 0)
                replay_start_count <= replay_start_count + 1;

            if (dsp_in_valid) begin
                dsp_in_count <= dsp_in_count + 1;
                if (dsp_in_row_start)
                    dsp_row_start_count <= dsp_row_start_count + 1;
            end

            if (dut.app_tx_tvalid && dut.app_tx_payload_ready && dut.tx_byte_idx == 0)
                app_tx_start_count <= app_tx_start_count + 1;
        end
    end

    task clear_caps;
    begin
        tx_hdr_count        = 0;
        tx_byte_count       = 0;
        tx_tlast_count      = 0;
        first_tx_dest_ip    = 0;
        first_tx_src_port   = 0;
        first_tx_dest_port  = 0;
        first_tx_length     = 0;
        parser_batch_count  = 0;
        replay_start_count  = 0;
        dsp_row_start_count = 0;
        dsp_in_count        = 0;
        app_tx_start_count  = 0;
    end
    endtask

    // =========================================================================
    // Focused debug monitor for TEST2
    // =========================================================================
    always @(posedge clk) begin
        if (!rst && verbose_test2) begin
            if (udp_rx_hdr_valid && udp_rx_hdr_ready) begin
                $display("DBG C=%0d RX_HDR src_ip=%08h src_port=%0d dest_port=%0d",
                         cycle_count, udp_rx_src_ip, udp_rx_src_port, udp_rx_dest_port);
            end

            if (udp_rx_tvalid && udp_rx_tready && (udp_rx_tlast || (udp_rx_tdata == 8'hFF))) begin
                $display("DBG C=%0d RX_BYTE data=%02h last=%0b ready=%0b accept=%0b",
                         cycle_count, udp_rx_tdata, udp_rx_tlast, udp_rx_tready, dut.cur_pkt_accept);
            end

            if (dut.sample_valid_w) begin
                $display("DBG C=%0d PARSER re=%08h im=%08h last=%0b row=%0d batch=%0d",
                         cycle_count, dut.sample_re_w, dut.sample_im_w, dut.sample_last_w,
                         dut.batch_row_id_w, dut.batch_id_w);
            end

            if (dut.sample_valid_w && dut.sample_last_w) begin
                $display("DBG C=%0d PARSER_BATCH_DONE row=%0d batch=%0d",
                         cycle_count, dut.batch_row_id_w, dut.batch_id_w);
            end

            if (dut.stage_full) begin
                $display("DBG C=%0d STAGE_FULL row=%0d batch=%0d",
                         cycle_count, dut.stage_row_id, dut.stage_batch_id);
            end

            if (dut.replay_active && dut.replay_idx == 0) begin
                $display("DBG C=%0d REPLAY_START row=%0d batch=%0d",
                         cycle_count, dut.stage_row_id, dut.stage_batch_id);
            end

            if (dsp_in_valid && (dsp_in_row_start || (dut.u_ppbuf.dsp_in_idx == 10'd511))) begin
                $display("DBG C=%0d DSP_IN row_start=%0b re=%08h im=%08h idx=%0d",
                         cycle_count, dsp_in_row_start, dsp_in_re, dsp_in_im, dut.u_ppbuf.dsp_in_idx);
            end

            if (dsp_out_valid && (dut.u_ppbuf.dsp_out_idx == 10'd0 || dut.u_ppbuf.dsp_out_idx == 10'd511)) begin
                $display("DBG C=%0d DSP_OUT re=%08h im=%08h out_idx=%0d",
                         cycle_count, dsp_out_re, dsp_out_im, dut.u_ppbuf.dsp_out_idx);
            end

            if (dut.pp_tx_row_valid && dut.pp_tx_row_ready && dut.pp_tx_row_start) begin
                $display("DBG C=%0d PP_TX_ROW_START row_id=%0d",
                         cycle_count, dut.pp_tx_row_row_id);
            end

            if (dut.app_tx_tvalid && dut.app_tx_payload_ready && dut.tx_byte_idx == 0) begin
                $display("DBG C=%0d APP_TX_PKT_START row_id=%0d pkt_idx=%0d byte_idx=%0d",
                         cycle_count, dut.app_tx_loaded_row_id, dut.tx_packet_idx, dut.tx_byte_idx);
            end

            if (udp_tx_hdr_valid && udp_tx_hdr_ready) begin
                $display("DBG C=%0d TX_HDR dest_ip=%08h src_port=%0d dest_port=%0d len=%0d pkt_idx=%0d loaded_row=%0d",
                         cycle_count, udp_tx_dest_ip, udp_tx_src_port, udp_tx_dest_port, udp_tx_length,
                         dut.tx_packet_idx, dut.app_tx_loaded_row_id);
            end

            if (udp_tx_tvalid && udp_tx_tready && (dut.tx_byte_idx == 0 || udp_tx_tlast)) begin
                $display("DBG C=%0d TX_BYTE data=%02h last=%0b pkt_idx=%0d byte_idx=%0d hdr_pending=%0b stream_active=%0b",
                         cycle_count, udp_tx_tdata, udp_tx_tlast,
                         dut.tx_packet_idx, dut.tx_byte_idx, dut.tx_hdr_pending, dut.tx_stream_active);
            end

            if (dut.tx_row_finished) begin
                $display("DBG C=%0d TX_ROW_FINISHED loaded_row=%0d",
                         cycle_count, dut.app_tx_loaded_row_id);
            end
        end
    end

    // =========================================================================
    // Helpers to send UDP packets
    // =========================================================================

    task send_udp_header(input [31:0] src_ip, input [15:0] src_port, input [15:0] dest_port);
    begin
        // Wait until DUT is ready to accept a new UDP metadata header
        while (!udp_rx_hdr_ready)
            @(posedge clk);
    
        @(posedge clk);
        udp_rx_hdr_valid <= 1'b1;
        udp_rx_src_ip    <= src_ip;
        udp_rx_src_port  <= src_port;
        udp_rx_dest_port <= dest_port;
    
        // Hold until handshake
        while (!(udp_rx_hdr_valid && udp_rx_hdr_ready))
            @(posedge clk);
    
        @(posedge clk);
        udp_rx_hdr_valid <= 1'b0;
    end
    endtask

    task send_udp_byte(input [7:0] b, input logic last);
    begin
        while (!udp_rx_tready)
            @(posedge clk);

        @(posedge clk);
        udp_rx_tdata  <= b;
        udp_rx_tvalid <= 1'b1;
        udp_rx_tlast  <= last;
    end
    endtask

    task idle_udp(input int cycles);
        int i;
    begin
        for (i = 0; i < cycles; i++) begin
            @(posedge clk);
            udp_rx_tvalid <= 1'b0;
            udp_rx_tlast  <= 1'b0;
            udp_rx_tdata  <= 8'h00;
        end
    end
    endtask

    task send_app_packet(input [9:0] row_id, input [1:0] batch_id,
                         input [31:0] src_ip, input [15:0] src_port, input [15:0] dest_port);
        int i;
        int global_idx;
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

        for (i = 0; i < 128; i++) begin
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

        @(posedge clk);
        udp_rx_tvalid <= 1'b0;
        udp_rx_tlast  <= 1'b0;
    end
    endtask

    task wait_cycles(input int n);
        int i;
    begin
        for (i = 0; i < n; i++)
            @(posedge clk);
    end
    endtask

    // =========================================================================
    // Main sequence
    // =========================================================================
    initial begin
        udp_rx_hdr_valid = 0;
        udp_rx_src_ip    = 0;
        udp_rx_src_port  = 0;
        udp_rx_dest_port = 0;
        udp_rx_tdata     = 0;
        udp_rx_tvalid    = 0;
        udp_rx_tlast     = 0;

        udp_tx_hdr_ready = 1;
        udp_tx_tready    = 1;

        repeat (10) @(posedge clk);
        rst = 0;

        // ---------------------------------------------------------------------
        // TEST1: Wrong port is ignored
        // ---------------------------------------------------------------------
        verbose_test2 = 0;
        $display("TEST1: wrong UDP port ignored");
        clear_caps();

        send_app_packet(10'd3, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5002);
        wait_cycles(200);

        expect_local(tx_hdr_count == 0, "no TX headers for wrong port");
        expect_local(tx_byte_count == 0, "no TX bytes for wrong port");

        // ---------------------------------------------------------------------
        // TEST2: Four valid packets for one row -> four outgoing packets
        // ---------------------------------------------------------------------
        verbose_test2 = 1;
        $display("TEST2: one full row end-to-end");
        clear_caps();

        send_app_packet(10'd3, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_udp(10);
        send_app_packet(10'd3, 2'd1, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_udp(10);
        send_app_packet(10'd3, 2'd2, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_udp(10);
        send_app_packet(10'd3, 2'd3, 32'hC0A80A63, 16'd6000, 16'd5001);

        wait_cycles(15000);

        $display("DEBUG SUMMARY:");
        $display("  parser_batch_count  = %0d", parser_batch_count);
        $display("  replay_start_count  = %0d", replay_start_count);
        $display("  dsp_row_start_count = %0d", dsp_row_start_count);
        $display("  dsp_in_count        = %0d", dsp_in_count);
        $display("  app_tx_start_count  = %0d", app_tx_start_count);
        $display("  tx_hdr_count        = %0d", tx_hdr_count);
        $display("  tx_byte_count       = %0d", tx_byte_count);
        $display("  tx_tlast_count      = %0d", tx_tlast_count);

        expect_local(parser_batch_count == 4, "parser completed 4 batches");
        expect_local(replay_start_count == 4, "replay started 4 times");
        expect_local(dsp_row_start_count == 1, "DSP row started once");
        expect_local(dsp_in_count == 512, "DSP received 512 samples");

        expect_local(tx_hdr_count == 4, "four TX packet headers seen");
        expect_local(tx_tlast_count == 4, "four TX packet last signals seen");
        expect_local(tx_byte_count == 4112, "4112 TX bytes seen (4 * 1028)");
        expect_local(first_tx_dest_ip == 32'hC0A80A63, "reply dest IP matches sender");
        expect_local(first_tx_src_port == 16'd5001, "reply source port is accelerator port");
        expect_local(first_tx_dest_port == 16'd6000, "reply dest port matches sender port");
        expect_local(first_tx_length == 16'd1028, "reply payload length is 1028");

        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");
        $finish;
    end

endmodule
