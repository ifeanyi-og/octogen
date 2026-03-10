`timescale 1ns / 1ps

module udp_processing_top (
    input  wire        clk,
    input  wire        rst,

    // -------------------------------------------------------------------------
    // UDP RX from eth_io_top
    // -------------------------------------------------------------------------
    input  wire        udp_rx_hdr_valid,
    output wire        udp_rx_hdr_ready,
    input  wire [31:0] udp_rx_src_ip,
    input  wire [15:0] udp_rx_src_port,
    input  wire [15:0] udp_rx_dest_port,

    input  wire [7:0]  udp_rx_tdata,
    input  wire        udp_rx_tvalid,
    output wire        udp_rx_tready,
    input  wire        udp_rx_tlast,

    // -------------------------------------------------------------------------
    // UDP TX to eth_io_top
    // -------------------------------------------------------------------------
    output wire        udp_tx_hdr_valid,
    input  wire        udp_tx_hdr_ready,
    output wire [31:0] udp_tx_dest_ip,
    output wire [15:0] udp_tx_src_port,
    output wire [15:0] udp_tx_dest_port,
    output wire [15:0] udp_tx_length,

    output wire [7:0]  udp_tx_tdata,
    output wire        udp_tx_tvalid,
    input  wire        udp_tx_tready,
    output wire        udp_tx_tlast,

    // -------------------------------------------------------------------------
    // DSP interface to dsp_core_top
    // -------------------------------------------------------------------------
    output wire        dsp_in_valid,
    output wire        dsp_in_row_start,
    output wire [31:0] dsp_in_re,
    output wire [31:0] dsp_in_im,

    input  wire        dsp_out_valid,
    input  wire [31:0] dsp_out_re,
    input  wire [31:0] dsp_out_im
);

    localparam APP_UDP_PORT      = 16'd5001;
    localparam BATCH_SAMPLES     = 128;
    localparam APP_PAYLOAD_BYTES = 16'd1028;
    localparam PACKETS_PER_ROW   = 4;
    localparam BYTES_PER_PACKET  = 11'd1028;

    // =========================================================================
    // Packet admission control
    // Only accept a new UDP header when there is room for the whole packet path.
    // =========================================================================
    reg        cur_pkt_active;
    reg        cur_pkt_accept;
    reg [31:0] cur_pkt_src_ip;
    reg [15:0] cur_pkt_src_port;
    reg [15:0] cur_pkt_dest_port;

    reg        stage_full;
    reg        replay_active;

    wire pkt_path_free = !cur_pkt_active && !stage_full && !replay_active;
    assign udp_rx_hdr_ready = pkt_path_free;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cur_pkt_active    <= 1'b0;
            cur_pkt_accept    <= 1'b0;
            cur_pkt_src_ip    <= 32'd0;
            cur_pkt_src_port  <= 16'd0;
            cur_pkt_dest_port <= 16'd0;
        end else begin
            if (udp_rx_hdr_valid && udp_rx_hdr_ready) begin
                cur_pkt_active    <= 1'b1;
                cur_pkt_accept    <= (udp_rx_dest_port == APP_UDP_PORT);
                cur_pkt_src_ip    <= udp_rx_src_ip;
                cur_pkt_src_port  <= udp_rx_src_port;
                cur_pkt_dest_port <= udp_rx_dest_port;
            end

            if (udp_rx_tvalid && udp_rx_tready && udp_rx_tlast) begin
                cur_pkt_active <= 1'b0;
                cur_pkt_accept <= 1'b0;
            end
        end
    end

    // Payload is accepted only for admitted packets.
    assign udp_rx_tready = cur_pkt_active ? 1'b1 : 1'b0;

    // =========================================================================
    // app_packet_rx
    // Feed only accepted payload bytes.
    // =========================================================================
    wire [7:0]  parser_tdata  = udp_rx_tdata;
    wire        parser_tvalid = udp_rx_tvalid && udp_rx_tready && cur_pkt_accept;
    wire        parser_tlast  = udp_rx_tvalid && udp_rx_tready && udp_rx_tlast && cur_pkt_accept;

    wire        batch_valid_w;
    wire [9:0]  batch_row_id_w;
    wire [1:0]  batch_id_w;
    wire [31:0] sample_re_w;
    wire [31:0] sample_im_w;
    wire        sample_valid_w;
    wire        sample_last_w;
    wire        hdr_error_w;

    app_packet_rx u_rx (
        .clk           (clk),
        .rst           (rst),
        .udp_rx_tdata  (parser_tdata),
        .udp_rx_tvalid (parser_tvalid),
        .udp_rx_tready (),
        .udp_rx_tlast  (parser_tlast),
        .batch_valid   (batch_valid_w),
        .batch_row_id  (batch_row_id_w),
        .batch_id      (batch_id_w),
        .sample_re     (sample_re_w),
        .sample_im     (sample_im_w),
        .sample_valid  (sample_valid_w),
        .sample_last   (sample_last_w),
        .hdr_error     (hdr_error_w)
    );

    // =========================================================================
    // Single batch staging buffer
    // =========================================================================
    reg [63:0] stage_mem [0:BATCH_SAMPLES-1];
    reg [6:0]  stage_wr_idx;
    reg [9:0]  stage_row_id;
    reg [1:0]  stage_batch_id;

    reg [31:0] stage_src_ip;
    reg [15:0] stage_src_port;
    reg [15:0] stage_dest_port;

    reg [6:0]  replay_idx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stage_wr_idx    <= 7'd0;
            stage_row_id    <= 10'd0;
            stage_batch_id  <= 2'd0;
            stage_src_ip    <= 32'd0;
            stage_src_port  <= 16'd0;
            stage_dest_port <= 16'd0;
            stage_full      <= 1'b0;
            replay_active   <= 1'b0;
            replay_idx      <= 7'd0;
        end else begin
            if (sample_valid_w) begin
                stage_mem[stage_wr_idx] <= {sample_re_w, sample_im_w};

                if (sample_last_w) begin
                    stage_wr_idx    <= 7'd0;
                    stage_row_id    <= batch_row_id_w;
                    stage_batch_id  <= batch_id_w;
                    stage_src_ip    <= cur_pkt_src_ip;
                    stage_src_port  <= cur_pkt_src_port;
                    stage_dest_port <= cur_pkt_dest_port;
                    stage_full      <= 1'b1;
                end else begin
                    stage_wr_idx <= stage_wr_idx + 7'd1;
                end
            end

            if (!replay_active && stage_full) begin
                replay_active <= 1'b1;
                replay_idx    <= 7'd0;
            end else if (replay_active) begin
                if (replay_idx == BATCH_SAMPLES-1) begin
                    replay_active <= 1'b0;
                    replay_idx    <= 7'd0;
                    stage_full    <= 1'b0;
                end else begin
                    replay_idx <= replay_idx + 7'd1;
                end
            end
        end
    end

    // =========================================================================
    // 2-entry routing table
    // =========================================================================
    reg        route0_valid, route1_valid;
    reg [9:0]  route0_row_id, route1_row_id;
    reg [31:0] route0_ip, route1_ip;
    reg [15:0] route0_src_port, route1_src_port;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            route0_valid    <= 1'b0;
            route1_valid    <= 1'b0;
            route0_row_id   <= 10'd0;
            route1_row_id   <= 10'd0;
            route0_ip       <= 32'd0;
            route1_ip       <= 32'd0;
            route0_src_port <= 16'd0;
            route1_src_port <= 16'd0;
        end else begin
            if (sample_valid_w && sample_last_w) begin
                if (route0_valid && (route0_row_id == batch_row_id_w)) begin
                    route0_ip       <= cur_pkt_src_ip;
                    route0_src_port <= cur_pkt_src_port;
                end else if (route1_valid && (route1_row_id == batch_row_id_w)) begin
                    route1_ip       <= cur_pkt_src_ip;
                    route1_src_port <= cur_pkt_src_port;
                end else if (!route0_valid) begin
                    route0_valid    <= 1'b1;
                    route0_row_id   <= batch_row_id_w;
                    route0_ip       <= cur_pkt_src_ip;
                    route0_src_port <= cur_pkt_src_port;
                end else begin
                    route1_valid    <= 1'b1;
                    route1_row_id   <= batch_row_id_w;
                    route1_ip       <= cur_pkt_src_ip;
                    route1_src_port <= cur_pkt_src_port;
                end
            end

            if (tx_row_finished) begin
                if (route0_valid && (route0_row_id == app_tx_loaded_row_id))
                    route0_valid <= 1'b0;
                if (route1_valid && (route1_row_id == app_tx_loaded_row_id))
                    route1_valid <= 1'b0;
            end
        end
    end

    reg [31:0] route_lookup_ip;
    reg [15:0] route_lookup_dest_port;

    always @(*) begin
        route_lookup_ip        = 32'd0;
        route_lookup_dest_port = 16'd0;

        if (route0_valid && (route0_row_id == app_tx_loaded_row_id)) begin
            route_lookup_ip        = route0_ip;
            route_lookup_dest_port = route0_src_port;
        end else if (route1_valid && (route1_row_id == app_tx_loaded_row_id)) begin
            route_lookup_ip        = route1_ip;
            route_lookup_dest_port = route1_src_port;
        end
    end

    // =========================================================================
    // row_pingpong_buffer
    // =========================================================================
    wire        pp_dsp_in_valid;
    wire        pp_dsp_in_row_start;
    wire [31:0] pp_dsp_in_re;
    wire [31:0] pp_dsp_in_im;

    wire        pp_tx_row_valid;
    wire        pp_tx_row_ready;
    wire        pp_tx_row_start;
    wire [9:0]  pp_tx_row_row_id;
    wire [31:0] pp_tx_row_re;
    wire [31:0] pp_tx_row_im;

    wire        pp_rx_overflow;
    wire        pp_row_tx_done;

    row_pingpong_buffer u_ppbuf (
        .clk            (clk),
        .rst            (rst),
        .rx_batch_start (replay_active && (replay_idx == 7'd0)),
        .rx_batch_row_id(stage_row_id),
        .rx_batch_id    (stage_batch_id),
        .rx_sample_valid(replay_active),
        .rx_sample_re   (stage_mem[replay_idx][63:32]),
        .rx_sample_im   (stage_mem[replay_idx][31:0]),
        .rx_sample_last (replay_active && (replay_idx == (BATCH_SAMPLES-1))),
        .rx_sample_ready(),
        .dsp_in_valid   (pp_dsp_in_valid),
        .dsp_in_row_start(pp_dsp_in_row_start),
        .dsp_in_re      (pp_dsp_in_re),
        .dsp_in_im      (pp_dsp_in_im),
        .dsp_out_valid  (dsp_out_valid),
        .dsp_out_re     (dsp_out_re),
        .dsp_out_im     (dsp_out_im),
        .tx_row_valid   (pp_tx_row_valid),
        .tx_row_ready   (pp_tx_row_ready),
        .tx_row_start   (pp_tx_row_start),
        .tx_row_row_id  (pp_tx_row_row_id),
        .tx_row_re      (pp_tx_row_re),
        .tx_row_im      (pp_tx_row_im),
        .rx_overflow    (pp_rx_overflow),
        .row_tx_done    (pp_row_tx_done)
    );

    assign dsp_in_valid     = pp_dsp_in_valid;
    assign dsp_in_row_start = pp_dsp_in_row_start;
    assign dsp_in_re        = pp_dsp_in_re;
    assign dsp_in_im        = pp_dsp_in_im;

    // =========================================================================
    // app_packet_tx
    // =========================================================================
    wire [7:0]  app_tx_tdata;
    wire        app_tx_tvalid;
    wire        app_tx_tlast;
    wire        app_tx_payload_ready;

    reg [9:0] app_tx_loaded_row_id;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            app_tx_loaded_row_id <= 10'd0;
        end else begin
            if (pp_tx_row_valid && pp_tx_row_ready && pp_tx_row_start)
                app_tx_loaded_row_id <= pp_tx_row_row_id;
        end
    end

    app_packet_tx u_app_tx (
        .clk          (clk),
        .rst          (rst),
        .row_in_valid (pp_tx_row_valid),
        .row_in_ready (pp_tx_row_ready),
        .row_in_start (pp_tx_row_start),
        .row_in_row_id(pp_tx_row_row_id),
        .row_in_re    (pp_tx_row_re),
        .row_in_im    (pp_tx_row_im),
        .tx_tdata     (app_tx_tdata),
        .tx_tvalid    (app_tx_tvalid),
        .tx_tready    (app_tx_payload_ready),
        .tx_tlast     (app_tx_tlast),
        .pkt_start    (),
        .pkt_batch_id (),
        .pkt_row_id   (),
        .row_done     ()
    );

    // =========================================================================
    // UDP TX framing controller
    // =========================================================================
    reg        tx_stream_active;
    reg        tx_hdr_pending;
    reg [10:0] tx_byte_idx;
    reg [1:0]  tx_packet_idx;

    wire at_packet_end = (tx_byte_idx == (BYTES_PER_PACKET-1));
    wire final_packet  = (tx_packet_idx == (PACKETS_PER_ROW-1));

    assign app_tx_payload_ready = tx_stream_active && !tx_hdr_pending && udp_tx_tready;

    assign udp_tx_hdr_valid = tx_stream_active && tx_hdr_pending;
    assign udp_tx_dest_ip   = route_lookup_ip;
    assign udp_tx_src_port  = APP_UDP_PORT;
    assign udp_tx_dest_port = route_lookup_dest_port;
    assign udp_tx_length    = APP_PAYLOAD_BYTES;

    assign udp_tx_tdata  = app_tx_tdata;
    assign udp_tx_tvalid = tx_stream_active && !tx_hdr_pending && app_tx_tvalid;
    assign udp_tx_tlast  = tx_stream_active && !tx_hdr_pending && app_tx_tlast;

    wire udp_hdr_hs = udp_tx_hdr_valid && udp_tx_hdr_ready;
    wire udp_pay_hs = udp_tx_tvalid && udp_tx_tready;

    wire tx_row_finished = udp_pay_hs && at_packet_end && final_packet;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_stream_active <= 1'b0;
            tx_hdr_pending   <= 1'b0;
            tx_byte_idx      <= 11'd0;
            tx_packet_idx    <= 2'd0;
        end else begin
            if (!tx_stream_active && app_tx_tvalid) begin
                tx_stream_active <= 1'b1;
                tx_hdr_pending   <= 1'b1;
                tx_byte_idx      <= 11'd0;
                tx_packet_idx    <= 2'd0;
            end else begin
                if (udp_hdr_hs)
                    tx_hdr_pending <= 1'b0;

                if (udp_pay_hs) begin
                    if (at_packet_end) begin
                        if (final_packet) begin
                            tx_stream_active <= 1'b0;
                            tx_hdr_pending   <= 1'b0;
                            tx_byte_idx      <= 11'd0;
                            tx_packet_idx    <= 2'd0;
                        end else begin
                            tx_hdr_pending <= 1'b1;
                            tx_byte_idx    <= 11'd0;
                            tx_packet_idx  <= tx_packet_idx + 2'd1;
                        end
                    end else begin
                        tx_byte_idx <= tx_byte_idx + 11'd1;
                    end
                end
            end
        end
    end

endmodule

