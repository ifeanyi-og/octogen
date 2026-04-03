
`timescale 1ns/1ps

module tb_udp_processing_top;

    localparam int APP_UDP_PORT        = 16'd5001;

    localparam int RX_BATCH_SAMPLES    = 256;
    localparam int RX_PACKETS_PER_ROW  = 4;

    localparam int TX_BATCH_SAMPLES    = 256;
    localparam int TX_PACKETS_PER_ROW  = 2;

    localparam int BYTES_PER_PACKET    = 1028;
    localparam int TOTAL_TX_BYTES      = TX_PACKETS_PER_ROW * BYTES_PER_PACKET;

    localparam logic [15:0] RX_HDR_TAG  = 16'hFF01;
    localparam logic [15:0] CAL_HDR_TAG = 16'hFF02;
    localparam logic [15:0] TX_HDR_TAG  = 16'hFF03;

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
    logic [31:0] dsp_in_data;

    logic        dsp_out_valid;
    logic [31:0] dsp_out_data;

    logic        allow_cal;
    logic        dsp_busy;

    logic        cal_loading;
    logic        cal_done_pulse;
    logic        cal_error;
    logic        cal_rejected_busy;
    logic        cal_rejected_mode;
    logic [7:0]  runtime_valid;

    logic        bg_wr_en;
    logic [0:0]  bg_wr_we;
    logic [9:0]  bg_wr_addr;
    logic [31:0] bg_wr_data;

    logic        disp_a_wr_en;
    logic [0:0]  disp_a_wr_we;
    logic [9:0]  disp_a_wr_addr;
    logic [31:0] disp_a_wr_data;

    logic        disp_b_wr_en;
    logic [0:0]  disp_b_wr_we;
    logic [9:0]  disp_b_wr_addr;
    logic [31:0] disp_b_wr_data;

    logic        klin_a_wr_en;
    logic [0:0]  klin_a_wr_we;
    logic [9:0]  klin_a_wr_addr;
    logic [31:0] klin_a_wr_data;

    logic        klin_b_wr_en;
    logic [0:0]  klin_b_wr_we;
    logic [9:0]  klin_b_wr_addr;
    logic [31:0] klin_b_wr_data;

    logic        klin_c_wr_en;
    logic [0:0]  klin_c_wr_we;
    logic [9:0]  klin_c_wr_addr;
    logic [31:0] klin_c_wr_data;

    logic        klin_d_wr_en;
    logic [0:0]  klin_d_wr_we;
    logic [9:0]  klin_d_wr_addr;
    logic [31:0] klin_d_wr_data;

    logic        klin_e_wr_en;
    logic [0:0]  klin_e_wr_we;
    logic [9:0]  klin_e_wr_addr;
    logic [31:0] klin_e_wr_data;

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
        .dsp_in_data(dsp_in_data),

        .dsp_out_valid(dsp_out_valid),
        .dsp_out_data(dsp_out_data),

        .allow_cal(allow_cal),
        .dsp_busy(dsp_busy),

        .cal_loading(cal_loading),
        .cal_done_pulse(cal_done_pulse),
        .cal_error(cal_error),
        .cal_rejected_busy(cal_rejected_busy),
        .cal_rejected_mode(cal_rejected_mode),
        .runtime_valid(runtime_valid),

        .bg_wr_en(bg_wr_en),
        .bg_wr_we(bg_wr_we),
        .bg_wr_addr(bg_wr_addr),
        .bg_wr_data(bg_wr_data),

        .disp_a_wr_en(disp_a_wr_en),
        .disp_a_wr_we(disp_a_wr_we),
        .disp_a_wr_addr(disp_a_wr_addr),
        .disp_a_wr_data(disp_a_wr_data),

        .disp_b_wr_en(disp_b_wr_en),
        .disp_b_wr_we(disp_b_wr_we),
        .disp_b_wr_addr(disp_b_wr_addr),
        .disp_b_wr_data(disp_b_wr_data),

        .klin_a_wr_en(klin_a_wr_en),
        .klin_a_wr_we(klin_a_wr_we),
        .klin_a_wr_addr(klin_a_wr_addr),
        .klin_a_wr_data(klin_a_wr_data),

        .klin_b_wr_en(klin_b_wr_en),
        .klin_b_wr_we(klin_b_wr_we),
        .klin_b_wr_addr(klin_b_wr_addr),
        .klin_b_wr_data(klin_b_wr_data),

        .klin_c_wr_en(klin_c_wr_en),
        .klin_c_wr_we(klin_c_wr_we),
        .klin_c_wr_addr(klin_c_wr_addr),
        .klin_c_wr_data(klin_c_wr_data),

        .klin_d_wr_en(klin_d_wr_en),
        .klin_d_wr_we(klin_d_wr_we),
        .klin_d_wr_addr(klin_d_wr_addr),
        .klin_d_wr_data(klin_d_wr_data),

        .klin_e_wr_en(klin_e_wr_en),
        .klin_e_wr_we(klin_e_wr_we),
        .klin_e_wr_addr(klin_e_wr_addr),
        .klin_e_wr_data(klin_e_wr_data)
    );

    // =========================================================================
    // External memories to emulate dsp_core ownership
    // =========================================================================
    logic        bg_rd_en;
    logic [9:0]  bg_rd_addr;
    logic [31:0] bg_rd_data;

    logic        klin_a_rd_en;
    logic [9:0]  klin_a_rd_addr;
    logic [9:0]  klin_a_rd_data_rb;

    bgsub_blk_mem_gen u_bg (
        .clka(clk),
        .ena(bg_wr_en),
        .wea(bg_wr_we),
        .addra(bg_wr_addr),
        .dina(bg_wr_data),
        .clkb(clk),
        .enb(bg_rd_en),
        .addrb(bg_rd_addr),
        .doutb(bg_rd_data)
    );

    klin_base_rom u_klin_a (
        .clka(clk),
        .ena(klin_a_wr_en),
        .wea(klin_a_wr_we),
        .addra(klin_a_wr_addr),
        .dina(klin_a_wr_data[9:0]),
        .clkb(clk),
        .enb(klin_a_rd_en),
        .addrb(klin_a_rd_addr),
        .doutb(klin_a_rd_data_rb)
    );

    // =========================================================================
    // Simple DSP model
    // =========================================================================
    int dsp_in_count_model;
    logic [31:0] pipe_d0, pipe_d1;
    logic        pipe_v0, pipe_v1;

    always @(posedge clk) begin
        if (rst) begin
            dsp_in_count_model <= 0;
            pipe_d0            <= '0;
            pipe_d1            <= '0;
            pipe_v0            <= 1'b0;
            pipe_v1            <= 1'b0;
            dsp_out_valid      <= 1'b0;
            dsp_out_data       <= '0;
        end else begin
            pipe_v0 <= dsp_in_valid && (dsp_in_count_model < 512);
            pipe_d0 <= dsp_in_data + 32'd1;

            if (dsp_in_valid)
                dsp_in_count_model <= dsp_in_count_model + 1;

            pipe_v1 <= pipe_v0;
            pipe_d1 <= pipe_d0;

            dsp_out_valid <= pipe_v1;
            dsp_out_data  <= pipe_d1;
        end
    end

    // =========================================================================
    // Pulse capture
    // =========================================================================
    logic clear_latches;
    logic saw_done;
    logic saw_error;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            saw_done  <= 1'b0;
            saw_error <= 1'b0;
        end else if (clear_latches) begin
            saw_done  <= 1'b0;
            saw_error <= 1'b0;
        end else begin
            if (cal_done_pulse)
                saw_done <= 1'b1;
            if (cal_error)
                saw_error <= 1'b1;
        end
    end

    // =========================================================================
    // Pass / fail
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

    task automatic reset_latches;
    begin
        @(negedge clk);
        clear_latches = 1'b1;
        @(negedge clk);
        clear_latches = 1'b0;
    end
    endtask

    // =========================================================================
    // Observability counters
    // =========================================================================
    integer cycle_count;

    int parser_batch_count;
    int replay_start_count;
    int dsp_row_start_count;
    int dsp_in_count_obs;

    int tx_hdr_count;
    int tx_byte_count;
    int tx_tlast_count;

    int bg_write_count;
    int klin_a_write_count;

    always @(posedge clk) begin
        if (rst) begin
            cycle_count         <= 0;
            parser_batch_count  <= 0;
            replay_start_count  <= 0;
            dsp_row_start_count <= 0;
            dsp_in_count_obs    <= 0;
            tx_hdr_count        <= 0;
            tx_byte_count       <= 0;
            tx_tlast_count      <= 0;
            bg_write_count      <= 0;
            klin_a_write_count  <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            // Data-path observability
            if (dut.data_sample_valid_w && dut.data_sample_last_w)
                parser_batch_count <= parser_batch_count + 1;

            if (dut.replay_active && (dut.replay_idx == 0))
                replay_start_count <= replay_start_count + 1;

            if (dsp_in_valid) begin
                dsp_in_count_obs <= dsp_in_count_obs + 1;
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

            // Calibration-path observability
            if (bg_wr_en && bg_wr_we[0])
                bg_write_count <= bg_write_count + 1;

            if (klin_a_wr_en && klin_a_wr_we[0])
                klin_a_write_count <= klin_a_write_count + 1;
        end
    end

    task automatic clear_counts;
    begin
        parser_batch_count  = 0;
        replay_start_count  = 0;
        dsp_row_start_count = 0;
        dsp_in_count_obs    = 0;
        tx_hdr_count        = 0;
        tx_byte_count       = 0;
        tx_tlast_count      = 0;
        dsp_in_count_model  = 0;
        bg_write_count      = 0;
        klin_a_write_count  = 0;
    end
    endtask

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
    bit saw_row_finished;

    always @(posedge clk) begin
        if (rst) begin
            tx_hdr_q.delete();
            pending_hdr_q.delete();
            tx_pkts.delete();
            active_pkt_idx   <= -1;
            active_byte_idx  <= 0;
            active_pkt_open  <= 1'b0;
            saw_row_finished <= 1'b0;
        end else begin
            if (dut.tx_row_finished)
                saw_row_finished <= 1'b1;

            if (udp_tx_hdr_valid && udp_tx_hdr_ready) begin
                tx_hdr_t h;
                h.dest_ip   = udp_tx_dest_ip;
                h.src_port  = udp_tx_src_port;
                h.dest_port = udp_tx_dest_port;
                h.length    = udp_tx_length;
                tx_hdr_q.push_back(h);
                pending_hdr_q.push_back(h);
            end

            if (udp_tx_tvalid && udp_tx_tready) begin
                if (!active_pkt_open) begin
                    if (pending_hdr_q.size() == 0) begin
                        $display("ERROR: payload byte with no pending header at cycle %0d", cycle_count);
                        fail++;
                    end else begin
                        pending_hdr_q.pop_front();
                        tx_pkts.push_back({});
                        active_pkt_idx  <= tx_pkts.size() - 1;
                        active_byte_idx <= 0;
                        active_pkt_open <= 1'b1;
                        tx_pkts[tx_pkts.size()-1].push_back(udp_tx_tdata);

                        if (udp_tx_tlast) begin
                            if (0 != BYTES_PER_PACKET-1) begin
                                $display("ERROR: tlast at wrong first-byte position");
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
                            $display("ERROR: tlast at wrong byte index %0d exp %0d",
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

    // =========================================================================
    // Helpers
    // =========================================================================
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

    function automatic logic [31:0] expected_cal_header_word(
        input logic [9:0] rid,
        input logic [1:0] bid
    );
        expected_cal_header_word = {CAL_HDR_TAG, bid, 4'b0000, rid};
    endfunction

    function automatic logic [31:0] expected_tx_header_word(
        input logic [9:0] tx_row_id,
        input logic [1:0] batch_id
    );
        expected_tx_header_word = {TX_HDR_TAG, batch_id, 4'b0000, tx_row_id};
    endfunction

    task automatic check_single_packet_payload(
        input int pkt_idx,
        input logic [9:0] exp_tx_row_id
    );
        int s;
        logic [31:0] hdr_word;
        logic [31:0] exp_hdr_word;
        logic [31:0] got_data;
        logic [31:0] exp_data;
    begin
        expect_local(pkt_idx < tx_pkts.size(), $sformatf("packet %0d captured", pkt_idx));
        if (pkt_idx >= tx_pkts.size())
            return;

        expect_local(tx_pkts[pkt_idx].size() == BYTES_PER_PACKET,
                     $sformatf("packet %0d has %0d bytes", pkt_idx, BYTES_PER_PACKET));
        if (tx_pkts[pkt_idx].size() != BYTES_PER_PACKET)
            return;

        hdr_word     = bytes_to_u32_le(tx_pkts[pkt_idx][0], tx_pkts[pkt_idx][1], tx_pkts[pkt_idx][2], tx_pkts[pkt_idx][3]);
        exp_hdr_word = expected_tx_header_word(exp_tx_row_id, pkt_idx[1:0]);

        expect_local(hdr_word == exp_hdr_word,
                     $sformatf("packet %0d app header matches tx_row=%0d batch=%0d",
                               pkt_idx, exp_tx_row_id, pkt_idx));

        for (s = 0; s < TX_BATCH_SAMPLES; s++) begin
            int base;
            int global_idx;
            base = 4 + (s * 4);
            global_idx = pkt_idx * TX_BATCH_SAMPLES + s;

            got_data = bytes_to_u32_le(tx_pkts[pkt_idx][base+0],
                                       tx_pkts[pkt_idx][base+1],
                                       tx_pkts[pkt_idx][base+2],
                                       tx_pkts[pkt_idx][base+3]);

            exp_data = global_idx + 32'd1;

            if (got_data !== exp_data) begin
                $display("FAIL: packet %0d sample %0d DATA mismatch got=%08h exp=%08h",
                         pkt_idx, s, got_data, exp_data);
                fail++;
            end else begin
                pass++;
            end
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
        expect_local(tx_hdr_count    == TX_PACKETS_PER_ROW, "header count is 2");
        expect_local(tx_tlast_count  == TX_PACKETS_PER_ROW, "tlast count is 2");
        expect_local(tx_byte_count   == TOTAL_TX_BYTES, "total TX bytes is 2056");
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

            check_single_packet_payload(i, exp_tx_row_id);
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
        logic [31:0] data_val;
    begin
        send_udp_header(src_ip, src_port, dest_port);

        hdr = expected_rx_header_word(row_id, batch_id);

        send_udp_byte(hdr[7:0],   1'b0);
        send_udp_byte(hdr[15:8],  1'b0);
        send_udp_byte(hdr[23:16], 1'b0);
        send_udp_byte(hdr[31:24], 1'b0);

        for (i = 0; i < RX_BATCH_SAMPLES; i++) begin
            global_idx = batch_id * RX_BATCH_SAMPLES + i;
            data_val   = global_idx;

            send_udp_byte(data_val[7:0],   1'b0);
            send_udp_byte(data_val[15:8],  1'b0);
            send_udp_byte(data_val[23:16], 1'b0);
            send_udp_byte(data_val[31:24], (i == RX_BATCH_SAMPLES-1));
        end
    end
    endtask

    task automatic send_cal_packet(
        input logic [9:0]  rid,
        input logic [1:0]  bid,
        input logic [31:0] base,
        input int          nsamp,
        input logic [31:0] src_ip,
        input logic [15:0] src_port
    );
        int i;
        logic [31:0] hdr;
        logic [31:0] d;
    begin
        send_udp_header(src_ip, src_port, APP_UDP_PORT);

        hdr = expected_cal_header_word(rid, bid);

        send_udp_byte(hdr[7:0],   1'b0);
        send_udp_byte(hdr[15:8],  1'b0);
        send_udp_byte(hdr[23:16], 1'b0);
        send_udp_byte(hdr[31:24], (nsamp == 0));

        for (i = 0; i < nsamp; i++) begin
            d = base + i;
            send_udp_byte(d[7:0],   1'b0);
            send_udp_byte(d[15:8],  1'b0);
            send_udp_byte(d[23:16], 1'b0);
            send_udp_byte(d[31:24], (i == (nsamp-1)));
        end
    end
    endtask

    task automatic send_full_cal(
        input logic [9:0] rid,
        input logic [31:0] base
    );
        int b;
    begin
        for (b = 0; b < 4; b++) begin
            send_cal_packet(rid, b[1:0], base + (b * 32'h1000), 256, 32'hC0A80101, 16'd6000);
            idle_rx(2);
        end
    end
    endtask

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

    task automatic read_bg_addr(input [9:0] addr, output logic [31:0] data);
    begin
        @(negedge clk);
        bg_rd_en   = 1'b1;
        bg_rd_addr = addr;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        data = bg_rd_data;
        bg_rd_en   = 1'b0;
        bg_rd_addr = '0;
    end
    endtask

    task automatic read_klin_a_addr(input [9:0] addr, output logic [9:0] data);
    begin
        @(negedge clk);
        klin_a_rd_en   = 1'b1;
        klin_a_rd_addr = addr;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        data = klin_a_rd_data_rb;
        klin_a_rd_en   = 1'b0;
        klin_a_rd_addr = '0;
    end
    endtask

    task automatic reset_dut;
    begin
        rst <= 1'b1;
        clear_latches <= 1'b0;
        udp_rx_hdr_valid <= 1'b0;
        udp_rx_src_ip    <= '0;
        udp_rx_src_port  <= '0;
        udp_rx_dest_port <= '0;
        udp_rx_tdata     <= '0;
        udp_rx_tvalid    <= 1'b0;
        udp_rx_tlast     <= 1'b0;
        udp_tx_hdr_ready <= 1'b1;
        udp_tx_tready    <= 1'b1;
        allow_cal        <= 1'b1;
        dsp_busy         <= 1'b0;
        bg_rd_en         <= 1'b0;
        bg_rd_addr       <= 10'd0;
        klin_a_rd_en     <= 1'b0;
        klin_a_rd_addr   <= 10'd0;

        repeat (8) @(posedge clk);
        clear_counts();
        clear_tx_capture();
        rst <= 1'b0;
        repeat (4) @(posedge clk);
    end
    endtask

    // =========================================================================
    // Data-path tests
    // =========================================================================
    task automatic test_wrong_port_ignored;
    begin
        $display("--------------------------------------------------");
        $display("TEST1: wrong port ignored");
        $display("--------------------------------------------------");

        reset_dut();

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

        reset_dut();
        run_tx_ready_always_on();

        send_app_packet(10'd3, 2'd0, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_rx(3);
        send_app_packet(10'd3, 2'd1, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_rx(3);
        send_app_packet(10'd3, 2'd2, 32'hC0A80A63, 16'd6000, 16'd5001);
        idle_rx(3);
        send_app_packet(10'd3, 2'd3, 32'hC0A80A63, 16'd6000, 16'd5001);

        wait_for_tx_packets(2, 40000, ok);
        fatal_if_fail(ok, "received all 2 TX packets");

        expect_local(parser_batch_count == 4, "parser completed 4 data batches");
        expect_local(replay_start_count == 4, "replay started 4 times");
        expect_local(dsp_row_start_count == 1, "DSP row started once");
        expect_local(dsp_in_count_obs == 1024, "DSP saw 1024 samples");

        check_row_tx(10'd0, 32'hC0A80A63, 16'd6000);
    end
    endtask

    task automatic test_tx_backpressure_exact_bytes;
        bit ok;
    begin
        $display("--------------------------------------------------");
        $display("TEST3: TX backpressure with exact packet framing");
        $display("--------------------------------------------------");

        reset_dut();

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

        wait_for_tx_packets(2, 50000, ok);
        fatal_if_fail(ok, "received 2 packets under backpressure");

        check_row_tx(10'd0, 32'hC0A80A63, 16'd6001);
    end
    endtask

    task automatic test_route_update_same_row_new_sender;
        bit ok;
    begin
        $display("--------------------------------------------------");
        $display("TEST4: same-row route updates to latest sender");
        $display("--------------------------------------------------");

        reset_dut();
        run_tx_ready_always_on();

        send_app_packet(10'd11, 2'd0, 32'hC0A80A11, 16'd6010, 16'd5001);
        idle_rx(2);
        send_app_packet(10'd11, 2'd1, 32'hC0A80A11, 16'd6010, 16'd5001);
        idle_rx(2);
        send_app_packet(10'd11, 2'd2, 32'hC0A80A11, 16'd6010, 16'd5001);
        idle_rx(2);
        send_app_packet(10'd11, 2'd3, 32'hC0A80A22, 16'd6022, 16'd5001);

        wait_for_tx_packets(2, 40000, ok);
        fatal_if_fail(ok, "received both TX packets for row 11");

        check_row_tx(10'd0, 32'hC0A80A22, 16'd6022);
    end
    endtask

    // =========================================================================
    // Calibration integration tests
    // =========================================================================
    task automatic test_valid_bg_calibration;
        logic [31:0] bg_got;
    begin
        $display("--------------------------------------------------");
        $display("TEST5: valid BG calibration through udp_processing_top");
        $display("--------------------------------------------------");

        reset_dut();
        reset_latches();

        send_full_cal(10'd0, 32'h0001_0000);
        idle_rx(20);

        expect_local(runtime_valid[0] == 1'b1, "BG runtime_valid set");
        expect_local(saw_done == 1'b1, "BG done pulse seen");
        expect_local(bg_write_count == 1024, "BG forwarded 1024 writes");
        expect_local(dsp_in_count_obs == 0, "Calibration traffic did not enter DSP data path");

        read_bg_addr(10'd0, bg_got);
        expect_local(bg_got == 32'h0001_0000, "BG[0] correct");

        read_bg_addr(10'd1023, bg_got);
        expect_local(bg_got == 32'h0001_30FF, "BG[1023] correct");
    end
    endtask

    // =========================================================================
    // Sticky debug capture for malformed-cal diagnosis
    // =========================================================================
    logic saw_hdr_valid_cal;
    logic saw_hdr_error;
    logic saw_pkt_is_cal_pulse;
    logic saw_sample_valid_any;
    logic saw_sample_last_any;
    logic saw_batch_valid_any;
    logic saw_cal_loading_any;
    logic saw_bg_write_any;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            saw_hdr_valid_cal   <= 1'b0;
            saw_hdr_error       <= 1'b0;
            saw_pkt_is_cal_pulse<= 1'b0;
            saw_sample_valid_any<= 1'b0;
            saw_sample_last_any <= 1'b0;
            saw_batch_valid_any <= 1'b0;
            saw_cal_loading_any <= 1'b0;
            saw_bg_write_any    <= 1'b0;
        end else if (clear_latches) begin
            saw_hdr_valid_cal   <= 1'b0;
            saw_hdr_error       <= 1'b0;
            saw_pkt_is_cal_pulse<= 1'b0;
            saw_sample_valid_any<= 1'b0;
            saw_sample_last_any <= 1'b0;
            saw_batch_valid_any <= 1'b0;
            saw_cal_loading_any <= 1'b0;
            saw_bg_write_any    <= 1'b0;
        end else begin
            if (dut.hdr_valid_w && dut.pkt_is_cal_w)
                saw_hdr_valid_cal <= 1'b1;

            if (dut.pkt_is_cal_w)
                saw_pkt_is_cal_pulse <= 1'b1;

            if (dut.hdr_error_w)
                saw_hdr_error <= 1'b1;

            if (dut.sample_valid_w)
                saw_sample_valid_any <= 1'b1;

            if (dut.sample_last_w)
                saw_sample_last_any <= 1'b1;

            if (dut.batch_valid_w)
                saw_batch_valid_any <= 1'b1;

            if (cal_loading)
                saw_cal_loading_any <= 1'b1;

            if (bg_wr_en && bg_wr_we[0])
                saw_bg_write_any <= 1'b1;
        end
    end


    task automatic test_valid_klin_a_calibration;
        logic [9:0] klin_a_got;
    begin
        $display("--------------------------------------------------");
        $display("TEST6: valid KLIN_A calibration through udp_processing_top");
        $display("--------------------------------------------------");

        reset_dut();
        reset_latches();

        send_full_cal(10'd24, 32'h0030_0000);
        idle_rx(20);

        expect_local(runtime_valid[3] == 1'b1, "KLIN_A runtime_valid set");
        expect_local(saw_done == 1'b1, "KLIN_A done pulse seen");
        expect_local(klin_a_write_count == 1024, "KLIN_A forwarded 1024 writes");

        read_klin_a_addr(10'd0, klin_a_got);
        expect_local(klin_a_got == 10'h000, "KLIN_A[0] truncated LSBs correct");

        read_klin_a_addr(10'd255, klin_a_got);
        expect_local(klin_a_got == 10'h0FF, "KLIN_A[255] truncated LSBs correct");
    end
    endtask

    task automatic test_malformed_bg_calibration;
    begin
        $display("--------------------------------------------------");
        $display("TEST7: malformed BG packet diagnostic");
        $display("--------------------------------------------------");

        reset_dut();

        // ------------------------------------------------------
        // Prime a known-good BG calibration first
        // ------------------------------------------------------
        reset_latches();
        send_full_cal(10'd0, 32'h0001_0000);
        idle_rx(20);

        expect_local(runtime_valid[0] == 1'b1, "Prime BG valid set");

        // ------------------------------------------------------
        // Malformed packet: valid CAL header, only 101 samples
        // ------------------------------------------------------
        reset_latches();
        send_cal_packet(10'd0, 2'd0, 32'h0100_0000, 101, 32'hC0A80101, 16'd6000);
        idle_rx(2049);

        $display("DBG malformed-cal sticky results:");
        $display("  saw_hdr_valid_cal    = %0b", saw_hdr_valid_cal);
        $display("  saw_pkt_is_cal_pulse = %0b", saw_pkt_is_cal_pulse);
        $display("  saw_hdr_error        = %0b", saw_hdr_error);
        $display("  saw_sample_valid_any = %0b", saw_sample_valid_any);
        $display("  saw_sample_last_any  = %0b", saw_sample_last_any);
        $display("  saw_batch_valid_any  = %0b", saw_batch_valid_any);
        $display("  saw_cal_loading_any  = %0b", saw_cal_loading_any);
        $display("  saw_bg_write_any     = %0b", saw_bg_write_any);
        $display("  runtime_valid        = 0x%02h", runtime_valid);
        $display("  saw_error            = %0b", saw_error);
        $display("  saw_done             = %0b", saw_done);
        $display("  bg_write_count       = %0d", bg_write_count);

        // ------------------------------------------------------
        // Diagnostic expectations
        // These tell you where the malformed packet stopped.
        // ------------------------------------------------------
        expect_local(saw_hdr_valid_cal == 1'b1,
                     "Malformed packet header was recognized as calibration");

        expect_local(saw_pkt_is_cal_pulse == 1'b1,
                     "Malformed packet produced pkt_is_cal pulse");

        // Optional: this may be 0 or 1 depending on parser behavior,
        // but checking it explicitly tells you whether parser flags the short packet.
        $display("NOTE: hdr_error behavior depends on parser design.");

        // This is the crucial divider:
        // If this is 0, the parser is suppressing payload emission.
        // If this is 1 but batch_valid_any is 0, the parser forwarded samples
        // but never produced a terminal batch event.
        expect_local(saw_sample_valid_any == 1'b1,
                     "Malformed packet forwarded some payload samples");

        // This tells you whether the parser exposed packet termination at all.
        $display("NOTE: sample_last and batch_valid determine whether cal_loader can react.");

        // ------------------------------------------------------
        // Final policy checks
        // Keep these, but now they are interpreted in context.
        // ------------------------------------------------------
        expect_local(runtime_valid[0] == 1'b0,
                     "Malformed BG clears runtime_valid[0]");

        expect_local(saw_error == 1'b1,
                     "Malformed BG raises cal_error pulse");

        expect_local(saw_done == 1'b0,
                     "Malformed BG does not raise done pulse");
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
        allow_cal        = 1'b1;
        dsp_busy         = 1'b0;
        bg_rd_en         = 1'b0;
        bg_rd_addr       = 10'd0;
        klin_a_rd_en     = 1'b0;
        klin_a_rd_addr   = 10'd0;
        clear_latches    = 1'b0;

        test_wrong_port_ignored();
        test_one_row_exact_bytes();
        test_tx_backpressure_exact_bytes();
        test_route_update_same_row_new_sender();
        test_valid_bg_calibration();
        test_valid_klin_a_calibration();
        test_malformed_bg_calibration();

        $display("==================================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("==================================================");

        $finish;
    end

endmodule
