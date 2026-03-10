

`timescale 1ns / 1ps

module udp_processing_top_tb;

    reg         clk;
    reg         rst;

    // UDP RX
    reg         udp_rx_hdr_valid;
    wire        udp_rx_hdr_ready;
    reg [31:0]  udp_rx_src_ip;
    reg [15:0]  udp_rx_src_port;
    reg [15:0]  udp_rx_dest_port;
    reg [7:0]   udp_rx_tdata;
    reg         udp_rx_tvalid;
    wire        udp_rx_tready;
    reg         udp_rx_tlast;

    // UDP TX
    wire        udp_tx_hdr_valid;
    reg         udp_tx_hdr_ready;
    wire [31:0] udp_tx_dest_ip;
    wire [15:0] udp_tx_src_port;
    wire [15:0] udp_tx_dest_port;
    wire [7:0]  udp_tx_tdata;
    wire        udp_tx_tvalid;
    reg         udp_tx_tready;
    wire        udp_tx_tlast;

    // Debug
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

    // Counters
    integer tests_run;
    integer tests_passed;
    integer tests_failed;
    integer i;
    integer timeout;

    // Packet / response buffers
    reg [7:0] packet   [0:511];
    reg [7:0] response [0:511];

    integer response_size;
    integer observed_tlast_count;
    integer observed_tvalid_count;

    // Captured TX header fields
    reg [31:0] cap_tx_dest_ip;
    reg [15:0] cap_tx_src_port;
    reg [15:0] cap_tx_dest_port;

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

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------------
    task report_test;
        input pass;
        input [255:0] message;
        begin
            tests_run = tests_run + 1;
            if (pass) begin
                tests_passed = tests_passed + 1;
                $display("  PASS: %s", message);
            end
            else begin
                tests_failed = tests_failed + 1;
                $display("  FAIL: %s", message);
            end
        end
    endtask

    task clear_rx_signals;
        begin
            udp_rx_hdr_valid = 0;
            udp_rx_src_ip    = 0;
            udp_rx_src_port  = 0;
            udp_rx_dest_port = 0;
            udp_rx_tdata     = 0;
            udp_rx_tvalid    = 0;
            udp_rx_tlast     = 0;
        end
    endtask

    task clear_tx_ready_signals;
        begin
            udp_tx_hdr_ready = 0;
            udp_tx_tready    = 0;
        end
    endtask

    task apply_reset;
        begin
            rst = 1;
            clear_rx_signals();
            clear_tx_ready_signals();
            tests_run = 0;
            tests_passed = 0;
            tests_failed = 0;
            response_size = 0;
            observed_tlast_count = 0;
            observed_tvalid_count = 0;
            cap_tx_dest_ip = 0;
            cap_tx_src_port = 0;
            cap_tx_dest_port = 0;

            repeat (4) @(posedge clk);
            rst = 0;
            repeat (2) @(posedge clk);
        end
    endtask

    task clear_response_buffer;
        integer k;
        begin
            for (k = 0; k < 512; k = k + 1)
                response[k] = 8'h00;
            response_size = 0;
            observed_tlast_count = 0;
            observed_tvalid_count = 0;
            cap_tx_dest_ip = 0;
            cap_tx_src_port = 0;
            cap_tx_dest_port = 0;
        end
    endtask

    // Drive RX header first, then payload. Payload bytes are driven on negedge
    // and only advanced after a posedge with tready=1.
    task send_udp_packet;
        input [31:0] src_ip;
        input [15:0] src_port;
        input [15:0] dest_port;
        input integer data_size;
        integer idx;
        integer wait_count;
        begin
            // Header phase
            @(negedge clk);
            udp_rx_hdr_valid <= 1'b1;
            udp_rx_src_ip    <= src_ip;
            udp_rx_src_port  <= src_port;
            udp_rx_dest_port <= dest_port;
            udp_rx_tvalid    <= 1'b0;
            udp_rx_tlast     <= 1'b0;
            udp_rx_tdata     <= 8'h00;

            wait_count = 0;
            while (udp_rx_hdr_ready !== 1'b1) begin
                @(posedge clk);
                wait_count = wait_count + 1;
                if (wait_count > 50) begin
                    $display("  FAIL: send_udp_packet timeout waiting for udp_rx_hdr_ready");
                    tests_run = tests_run + 1;
                    tests_failed = tests_failed + 1;
                    disable send_udp_packet;
                end
            end

            @(posedge clk);
            @(negedge clk);
            udp_rx_hdr_valid <= 1'b0;

            // Payload phase
            for (idx = 0; idx < data_size; idx = idx + 1) begin
                @(negedge clk);
                udp_rx_tdata  <= packet[idx];
                udp_rx_tvalid <= 1'b1;
                udp_rx_tlast  <= (idx == data_size - 1);

                wait_count = 0;
                while (udp_rx_tready !== 1'b1) begin
                    @(posedge clk);
                    wait_count = wait_count + 1;
                    if (wait_count > 200) begin
                        $display("  FAIL: send_udp_packet timeout waiting for udp_rx_tready at byte %0d", idx);
                        tests_run = tests_run + 1;
                        tests_failed = tests_failed + 1;
                        disable send_udp_packet;
                    end
                end

                @(posedge clk);
            end

            @(negedge clk);
            udp_rx_tvalid <= 1'b0;
            udp_rx_tlast  <= 1'b0;
            udp_rx_tdata  <= 8'h00;
        end
    endtask

    task send_udp_packet_with_tx_backpressure;
        input [31:0] src_ip;
        input [15:0] src_port;
        input [15:0] dest_port;
        input integer data_size;
        input integer stall_every_n;
        input integer stall_len;
        integer idx;
        integer resp_idx;
        integer hdr_timeout;
        integer payload_timeout;
        integer stall_ctr;
        begin
            clear_response_buffer();

            // Start packet send in-line
            fork
                begin
                    send_udp_packet(src_ip, src_port, dest_port, data_size);
                end
                begin
                    // Receive with periodic stalls
                    hdr_timeout = 0;
                    while (!udp_tx_hdr_valid && hdr_timeout < 2000) begin
                        @(posedge clk);
                        hdr_timeout = hdr_timeout + 1;
                    end

                    if (hdr_timeout >= 2000) begin
                        $display("  FAIL: timeout waiting for TX header in backpressure test");
                        tests_run = tests_run + 1;
                        tests_failed = tests_failed + 1;
                    end
                    else begin
                        cap_tx_dest_ip   = udp_tx_dest_ip;
                        cap_tx_src_port  = udp_tx_src_port;
                        cap_tx_dest_port = udp_tx_dest_port;

                        @(negedge clk);
                        udp_tx_hdr_ready <= 1'b1;
                        @(posedge clk);
                        @(negedge clk);
                        udp_tx_hdr_ready <= 1'b0;

                        resp_idx = 0;
                        stall_ctr = 0;
                        payload_timeout = 0;
                        udp_tx_tready = 1'b1;

                        while (payload_timeout < 10000) begin
                            @(posedge clk);
                            payload_timeout = payload_timeout + 1;

                            if (udp_tx_tvalid && udp_tx_tready) begin
                                response[resp_idx] = udp_tx_tdata;
                                resp_idx = resp_idx + 1;
                                observed_tvalid_count = observed_tvalid_count + 1;

                                if (udp_tx_tlast)
                                    observed_tlast_count = observed_tlast_count + 1;

                                stall_ctr = stall_ctr + 1;
                                if (stall_ctr == stall_every_n) begin
                                    @(negedge clk);
                                    udp_tx_tready <= 1'b0;
                                    repeat (stall_len) @(posedge clk);
                                    @(negedge clk);
                                    udp_tx_tready <= 1'b1;
                                    stall_ctr = 0;
                                end

                                if (udp_tx_tlast) begin
                                    response_size = resp_idx;
                                    @(negedge clk);
                                    udp_tx_tready <= 1'b0;
                                    disable receive_done_bp;
                                end
                            end
                        end

                        begin : receive_done_bp
                        end
                    end
                end
            join
        end
    endtask

    task receive_response;
        integer resp_idx;
        integer hdr_timeout;
        integer payload_timeout;
        begin
            clear_response_buffer();

            hdr_timeout = 0;
            while (!udp_tx_hdr_valid && hdr_timeout < 2000) begin
                @(posedge clk);
                hdr_timeout = hdr_timeout + 1;
            end

            if (hdr_timeout >= 2000) begin
                response_size = -1;
                disable receive_response;
            end

            cap_tx_dest_ip   = udp_tx_dest_ip;
            cap_tx_src_port  = udp_tx_src_port;
            cap_tx_dest_port = udp_tx_dest_port;

            @(negedge clk);
            udp_tx_hdr_ready <= 1'b1;
            @(posedge clk);
            @(negedge clk);
            udp_tx_hdr_ready <= 1'b0;

            resp_idx = 0;
            payload_timeout = 0;

            @(negedge clk);
            udp_tx_tready <= 1'b1;

            while (payload_timeout < 10000) begin
                @(posedge clk);
                payload_timeout = payload_timeout + 1;

                if (udp_tx_tvalid && udp_tx_tready) begin
                    response[resp_idx] = udp_tx_tdata;
                    resp_idx = resp_idx + 1;
                    observed_tvalid_count = observed_tvalid_count + 1;

                    if (udp_tx_tlast)
                        observed_tlast_count = observed_tlast_count + 1;

                    if (udp_tx_tlast) begin
                        response_size = resp_idx;
                        @(negedge clk);
                        udp_tx_tready <= 1'b0;
                        disable receive_loop_done;
                    end
                end
            end

            response_size = -2; // payload timeout
            @(negedge clk);
            udp_tx_tready <= 1'b0;

            begin : receive_loop_done
            end
        end
    endtask

    task expect_no_response;
        input integer max_cycles;
        reg seen_hdr;
        reg seen_payload;
        integer k;
        begin
            seen_hdr = 0;
            seen_payload = 0;
            for (k = 0; k < max_cycles; k = k + 1) begin
                @(posedge clk);
                if (udp_tx_hdr_valid)
                    seen_hdr = 1;
                if (udp_tx_tvalid)
                    seen_payload = 1;
            end

            report_test(!seen_hdr,    "No TX header observed");
            report_test(!seen_payload,"No TX payload observed");
        end
    endtask

    task build_valid_packet_repeated_word;
        input [7:0] batch;
        input [7:0] seq;
        input [7:0] b0;
        input [7:0] b1;
        input [7:0] b2;
        input [7:0] b3;
        begin
            packet[0] = 8'hFF;
            packet[1] = 8'h00;
            packet[2] = batch;
            packet[3] = seq;
            for (i = 0; i < 64; i = i + 1) begin
                packet[4 + i*4 + 0] = b0;
                packet[4 + i*4 + 1] = b1;
                packet[4 + i*4 + 2] = b2;
                packet[4 + i*4 + 3] = b3;
            end
        end
    endtask

    task build_header_only_or_partial;
        input [7:0] b0;
        input [7:0] b1;
        input [7:0] b2;
        input [7:0] b3;
        input integer size_bytes;
        begin
            packet[0] = b0;
            packet[1] = b1;
            packet[2] = b2;
            packet[3] = b3;
            for (i = 4; i < size_bytes; i = i + 1)
                packet[i] = 8'h00;
        end
    endtask

    task check_full_response_pattern;
        input [7:0] e0;
        input [7:0] e1;
        input [7:0] e2;
        input [7:0] e3;
        integer k;
        reg ok;
        begin
            ok = (response_size == 256);
            for (k = 0; k < 64; k = k + 1) begin
                if (response[k*4 + 0] !== e0) ok = 0;
                if (response[k*4 + 1] !== e1) ok = 0;
                if (response[k*4 + 2] !== e2) ok = 0;
                if (response[k*4 + 3] !== e3) ok = 0;
            end
            report_test(ok, "All 256 response bytes match expected sample pattern");
        end
    endtask

    // ------------------------------------------------------------------------
    // Main sequence
    // ------------------------------------------------------------------------
    initial begin
        apply_reset();

        $display("");
        $display("================================================================================");
        $display("UDP_PROCESSING_TOP INTEGRATION TEST");
        $display("================================================================================");

        // --------------------------------------------------------------------
        // TEST 1: Valid packet, full routing + full payload + tlast
        // --------------------------------------------------------------------
        $display("\nTEST 1: Valid DSP packet to port 5001");
        build_valid_packet_repeated_word(8'h01, 8'h42, 8'h11, 8'h22, 8'h33, 8'h44);

        fork
            begin
                send_udp_packet({8'd192,8'd168,8'd10,8'd10}, 16'd5678, 16'd5001, 260);
            end
            begin
                receive_response();
            end
        join

        report_test(response_size == 256, "Response size is exactly 256 bytes");
        report_test(cap_tx_dest_ip   == {8'd192,8'd168,8'd10,8'd10}, "TX dest IP matches original RX source IP");
        report_test(cap_tx_src_port  == 16'd5001, "TX source port matches original RX destination port");
        report_test(cap_tx_dest_port == 16'd5678, "TX destination port matches original RX source port");
        report_test(observed_tlast_count == 1, "Exactly one udp_tx_tlast observed");
        report_test(response[0]   == 8'h11, "Response byte[0] correct");
        report_test(response[1]   == 8'h22, "Response byte[1] correct");
        report_test(response[2]   == 8'h33, "Response byte[2] correct");
        report_test(response[3]   == 8'h44, "Response byte[3] correct");
        report_test(response[252] == 8'h11, "Response byte[252] correct");
        report_test(response[253] == 8'h22, "Response byte[253] correct");
        report_test(response[254] == 8'h33, "Response byte[254] correct");
        report_test(response[255] == 8'h44, "Response byte[255] correct");
        check_full_response_pattern(8'h11, 8'h22, 8'h33, 8'h44);

        repeat (3) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 2: Wrong destination port, no response
        // --------------------------------------------------------------------
        $display("\nTEST 2: Wrong destination port");
        build_valid_packet_repeated_word(8'h00, 8'h00, 8'h55, 8'h55, 8'h55, 8'h55);

        send_udp_packet({8'd192,8'd168,8'd10,8'd10}, 16'd5678, 16'd5002, 260);
        expect_no_response(400);

        repeat (3) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 3: Bad magic
        // --------------------------------------------------------------------
        $display("\nTEST 3: Bad magic");
        build_valid_packet_repeated_word(8'h00, 8'h00, 8'h66, 8'h66, 8'h66, 8'h66);
        packet[0] = 8'hAA;

        send_udp_packet({8'd192,8'd168,8'd10,8'd10}, 16'd5678, 16'd5001, 260);
        expect_no_response(400);

        repeat (3) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 4: Invalid packet type
        // --------------------------------------------------------------------
        $display("\nTEST 4: Invalid packet type");
        build_valid_packet_repeated_word(8'h00, 8'h00, 8'h77, 8'h77, 8'h77, 8'h77);
        packet[1] = 8'h99;

        send_udp_packet({8'd192,8'd168,8'd10,8'd10}, 16'd5678, 16'd5001, 260);
        expect_no_response(400);

        repeat (3) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 5: Discard packet types 0x01, 0x02, 0x03
        // --------------------------------------------------------------------
        $display("\nTEST 5: Discard packet types 0x01 / 0x02 / 0x03");

        build_valid_packet_repeated_word(8'h00, 8'h00, 8'h88, 8'h88, 8'h88, 8'h88);
        packet[1] = 8'h01;
        send_udp_packet({8'd1,8'd2,8'd3,8'd4}, 16'd1000, 16'd5001, 260);
        expect_no_response(300);

        build_valid_packet_repeated_word(8'h00, 8'h00, 8'h99, 8'h99, 8'h99, 8'h99);
        packet[1] = 8'h02;
        send_udp_packet({8'd1,8'd2,8'd3,8'd5}, 16'd1001, 16'd5001, 260);
        expect_no_response(300);

        build_valid_packet_repeated_word(8'h00, 8'h00, 8'hAA, 8'hAA, 8'hAA, 8'hAA);
        packet[1] = 8'h03;
        send_udp_packet({8'd1,8'd2,8'd3,8'd6}, 16'd1002, 16'd5001, 260);
        expect_no_response(300);

        repeat (3) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 6: Back-to-back valid packets with different routing and payload
        // --------------------------------------------------------------------
        $display("\nTEST 6: Back-to-back valid packets");

        build_valid_packet_repeated_word(8'h0A, 8'h10, 8'h10, 8'h11, 8'h12, 8'h13);
        fork
            begin
                send_udp_packet({8'd10,8'd0,8'd0,8'd1}, 16'd6001, 16'd5001, 260);
            end
            begin
                receive_response();
            end
        join
        report_test(response_size == 256, "Packet A produced 256-byte response");
        report_test(cap_tx_dest_ip == {8'd10,8'd0,8'd0,8'd1}, "Packet A routing dest IP correct");
        report_test(cap_tx_dest_port == 16'd6001, "Packet A routing dest port correct");
        check_full_response_pattern(8'h10, 8'h11, 8'h12, 8'h13);

        build_valid_packet_repeated_word(8'h0B, 8'h20, 8'h20, 8'h21, 8'h22, 8'h23);
        fork
            begin
                send_udp_packet({8'd10,8'd0,8'd0,8'd2}, 16'd6002, 16'd5001, 260);
            end
            begin
                receive_response();
            end
        join
        report_test(response_size == 256, "Packet B produced 256-byte response");
        report_test(cap_tx_dest_ip == {8'd10,8'd0,8'd0,8'd2}, "Packet B routing dest IP correct");
        report_test(cap_tx_dest_port == 16'd6002, "Packet B routing dest port correct");
        check_full_response_pattern(8'h20, 8'h21, 8'h22, 8'h23);

        repeat (3) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 7: Truncated header, then valid recovery packet
        // --------------------------------------------------------------------
        $display("\nTEST 7: Truncated header recovery");

        build_header_only_or_partial(8'hFF, 8'h00, 8'h01, 8'h42, 2); // only FF 00
        send_udp_packet({8'd20,8'd1,8'd1,8'd1}, 16'd7001, 16'd5001, 2);
        expect_no_response(250);

        build_valid_packet_repeated_word(8'h05, 8'h55, 8'h31, 8'h32, 8'h33, 8'h34);
        fork
            begin
                send_udp_packet({8'd20,8'd1,8'd1,8'd2}, 16'd7002, 16'd5001, 260);
            end
            begin
                receive_response();
            end
        join
        report_test(response_size == 256, "Recovery after truncated header succeeds");
        check_full_response_pattern(8'h31, 8'h32, 8'h33, 8'h34);

        repeat (3) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 8: Truncated payload, then valid recovery packet
        // --------------------------------------------------------------------
        $display("\nTEST 8: Truncated payload recovery");

        packet[0] = 8'hFF;
        packet[1] = 8'h00;
        packet[2] = 8'h01;
        packet[3] = 8'h77;
        packet[4] = 8'hDE;
        packet[5] = 8'hAD; // partial sample only
        send_udp_packet({8'd30,8'd1,8'd1,8'd1}, 16'd7101, 16'd5001, 6);
        expect_no_response(250);

        build_valid_packet_repeated_word(8'h06, 8'h66, 8'h41, 8'h42, 8'h43, 8'h44);
        fork
            begin
                send_udp_packet({8'd30,8'd1,8'd1,8'd2}, 16'd7102, 16'd5001, 260);
            end
            begin
                receive_response();
            end
        join
        report_test(response_size == 256, "Recovery after truncated payload succeeds");
        check_full_response_pattern(8'h41, 8'h42, 8'h43, 8'h44);

        repeat (3) @(posedge clk);

        // --------------------------------------------------------------------
        // TEST 9: TX backpressure
        // --------------------------------------------------------------------
        $display("\nTEST 9: TX payload backpressure");

        build_valid_packet_repeated_word(8'h07, 8'h77, 8'h51, 8'h52, 8'h53, 8'h54);
        send_udp_packet_with_tx_backpressure(
            {8'd40,8'd1,8'd1,8'd1},
            16'd7201,
            16'd5001,
            260,
            7,   // stall every 7 accepted TX bytes
            3    // for 3 cycles
        );

        report_test(response_size == 256, "TX backpressure test still returns 256 bytes");
        report_test(observed_tlast_count == 1, "TX backpressure test has exactly one tlast");
        check_full_response_pattern(8'h51, 8'h52, 8'h53, 8'h54);

        // --------------------------------------------------------------------
        // Summary
        // --------------------------------------------------------------------
        $display("");
        $display("================================================================================");
        $display("TEST SUMMARY");
        $display("================================================================================");
        $display("Tests Run:    %0d", tests_run);
        $display("Tests Passed: %0d", tests_passed);
        $display("Tests Failed: %0d", tests_failed);

        if (tests_failed == 0) begin
            $display("");
            $display("ALL TESTS PASSED");
            $display("");
        end
        else begin
            $display("");
            $display("SOME TESTS FAILED");
            $display("");
        end

        $display("================================================================================");
        $finish;
    end

endmodule

