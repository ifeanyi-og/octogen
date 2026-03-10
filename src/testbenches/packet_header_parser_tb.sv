
`timescale 1ns / 1ps

module packet_header_parser_tb;

    // ============================================================
    // DUT I/O
    // ============================================================
    logic        clk;
    logic        rst;

    logic [7:0]  s_udp_tdata;
    logic        s_udp_tvalid;
    wire         s_udp_tready;
    logic        s_udp_tlast;

    wire         hdr_valid;
    logic        hdr_ready;
    wire [3:0]   hdr_batch;
    wire [15:0]  hdr_seq;

    wire [31:0]  m_sample_tdata;
    wire         m_sample_tvalid;
    logic        m_sample_tready;
    wire         m_sample_tlast;
    wire [5:0]   m_sample_index;

    wire [1:0]   debug_state;
    wire [1:0]   debug_byte_count;
    wire [6:0]   debug_sample_count;
    wire [7:0]   debug_packet_type;
    wire         debug_valid_packet;

    // ============================================================
    // Instantiate DUT
    // ============================================================
    packet_header_parser dut (
        .clk               (clk),
        .rst               (rst),

        .s_udp_tdata       (s_udp_tdata),
        .s_udp_tvalid      (s_udp_tvalid),
        .s_udp_tready      (s_udp_tready),
        .s_udp_tlast       (s_udp_tlast),

        .hdr_valid         (hdr_valid),
        .hdr_ready         (hdr_ready),
        .hdr_batch         (hdr_batch),
        .hdr_seq           (hdr_seq),

        .m_sample_tdata    (m_sample_tdata),
        .m_sample_tvalid   (m_sample_tvalid),
        .m_sample_tready   (m_sample_tready),
        .m_sample_tlast    (m_sample_tlast),
        .m_sample_index    (m_sample_index),

        .debug_state       (debug_state),
        .debug_byte_count  (debug_byte_count),
        .debug_sample_count(debug_sample_count),
        .debug_packet_type (debug_packet_type),
        .debug_valid_packet(debug_valid_packet)
    );

    // ============================================================
    // Clock
    // ============================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // Scoreboard / counters / logging
    // ============================================================
    integer pass_count = 0;
    integer fail_count = 0;
    integer cycle_count = 0;

    integer hdr_hs_count = 0;
    integer sample_hs_count = 0;

    logic [3:0]   hdr_batch_hist [0:255];
    logic [15:0]  hdr_seq_hist   [0:255];
    integer       hdr_cycle_hist [0:255];

    logic [31:0]  sample_word_hist  [0:2047];
    logic [5:0]   sample_index_hist [0:2047];
    logic         sample_last_hist  [0:2047];
    integer       sample_cycle_hist [0:2047];

    bit verbose_cycle_log = 0;
    bit verbose_sample_log = 0;

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;

        if (verbose_cycle_log) begin
            $display(
                "CYCLE=%0d | rst=%0b | in: data=0x%02h valid=%0b ready=%0b last=%0b | hdr: valid=%0b ready=%0b batch=0x%0h seq=0x%04h | sample: valid=%0b ready=%0b data=0x%08h idx=%0d last=%0b | dbg: state=%0d byte_count=%0d sample_count=%0d valid_pkt=%0b",
                cycle_count,
                rst,
                s_udp_tdata, s_udp_tvalid, s_udp_tready, s_udp_tlast,
                hdr_valid, hdr_ready, hdr_batch, hdr_seq,
                m_sample_tvalid, m_sample_tready, m_sample_tdata, m_sample_index, m_sample_tlast,
                debug_state, debug_byte_count, debug_sample_count, debug_valid_packet
            );
        end

        if (hdr_valid && hdr_ready) begin
            hdr_batch_hist[hdr_hs_count] = hdr_batch;
            hdr_seq_hist[hdr_hs_count]   = hdr_seq;
            hdr_cycle_hist[hdr_hs_count] = cycle_count;
            hdr_hs_count = hdr_hs_count + 1;

            $display("HDR_HS  @ cycle %0d : batch=0x%0h seq=0x%04h", cycle_count, hdr_batch, hdr_seq);
        end

        if (m_sample_tvalid && m_sample_tready) begin
            sample_word_hist[sample_hs_count]  = m_sample_tdata;
            sample_index_hist[sample_hs_count] = m_sample_index;
            sample_last_hist[sample_hs_count]  = m_sample_tlast;
            sample_cycle_hist[sample_hs_count] = cycle_count;

            if (verbose_sample_log) begin
                $display("SAMPLE_HS @ cycle %0d : data=0x%08h idx=%0d last=%0b",
                         cycle_count, m_sample_tdata, m_sample_index, m_sample_tlast);
            end

            sample_hs_count = sample_hs_count + 1;
        end
    end

    // ============================================================
    // Utility tasks
    // ============================================================
    task automatic check_true(input string name, input bit cond);
    begin
        if (cond) begin
            pass_count = pass_count + 1;
            $display("PASS: %s", name);
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: %s", name);
        end
    end
    endtask

    task automatic check_eq_u32(input string name, input logic [31:0] got, input logic [31:0] exp);
    begin
        if (got === exp) begin
            pass_count = pass_count + 1;
            $display("PASS: %s | got=0x%08h", name, got);
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: %s | got=0x%08h exp=0x%08h", name, got, exp);
        end
    end
    endtask

    task automatic check_eq_u16(input string name, input logic [15:0] got, input logic [15:0] exp);
    begin
        if (got === exp) begin
            pass_count = pass_count + 1;
            $display("PASS: %s | got=0x%04h", name, got);
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: %s | got=0x%04h exp=0x%04h", name, got, exp);
        end
    end
    endtask

    task automatic check_eq_u6(input string name, input logic [5:0] got, input logic [5:0] exp);
    begin
        if (got === exp) begin
            pass_count = pass_count + 1;
            $display("PASS: %s | got=%0d", name, got);
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: %s | got=%0d exp=%0d", name, got, exp);
        end
    end
    endtask

    task automatic drive_idle;
    begin
        @(negedge clk);
        s_udp_tdata   <= 8'h00;
        s_udp_tvalid  <= 1'b0;
        s_udp_tlast   <= 1'b0;
        hdr_ready     <= 1'b0;
        m_sample_tready <= m_sample_tready; // hold as-is unless caller changes it
    end
    endtask

    task automatic apply_reset;
    begin
        rst = 1'b1;
        s_udp_tdata = 8'h00;
        s_udp_tvalid = 1'b0;
        s_udp_tlast = 1'b0;
        hdr_ready = 1'b0;
        m_sample_tready = 1'b0;
        verbose_cycle_log = 1'b0;
        verbose_sample_log = 1'b0;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
    end
    endtask

    // Clean one-byte sender:
    // - data/valid/last are driven on negedge
    // - handshake happens on posedge(s)
    // - signals are cleared on negedge after handshake
    task automatic send_byte(input logic [7:0] data, input logic last);
        integer timeout;
    begin
        @(negedge clk);
        s_udp_tdata  <= data;
        s_udp_tvalid <= 1'b1;
        s_udp_tlast  <= last;

        timeout = 0;
        while (s_udp_tready !== 1'b1) begin
            @(posedge clk);
            timeout = timeout + 1;
            if (timeout > 20) begin
                fail_count = fail_count + 1;
                $display("FAIL: send_byte timeout waiting for s_udp_tready");
                disable send_byte;
            end
        end

        // Consume on next posedge where valid & ready are high
        @(posedge clk);

        @(negedge clk);
        s_udp_tvalid <= 1'b0;
        s_udp_tlast  <= 1'b0;
        s_udp_tdata  <= 8'h00;
    end
    endtask

    task automatic send_header(
        input logic [7:0] magic,
        input logic [7:0] ptype,
        input logic [7:0] batch_byte,
        input logic [7:0] seq_byte,
        input logic       last_on_seq
    );
    begin
        send_byte(magic,      1'b0);
        send_byte(ptype,      1'b0);
        send_byte(batch_byte, 1'b0);
        send_byte(seq_byte,   last_on_seq);
    end
    endtask

    task automatic wait_hdr_valid(input integer max_cycles, output bit ok);
        integer k;
    begin
        ok = 0;
        for (k = 0; k < max_cycles; k = k + 1) begin
            if (hdr_valid === 1'b1) begin
                ok = 1;
                break;
            end
            @(posedge clk);
        end
    end
    endtask

    task automatic wait_hdr_low(input integer max_cycles, output bit ok);
        integer k;
    begin
        ok = 0;
        for (k = 0; k < max_cycles; k = k + 1) begin
            if (hdr_valid === 1'b0) begin
                ok = 1;
                break;
            end
            @(posedge clk);
        end
    end
    endtask

    task automatic pulse_hdr_ready;
    begin
        @(negedge clk);
        hdr_ready <= 1'b1;
        @(posedge clk);
        @(negedge clk);
        hdr_ready <= 1'b0;
    end
    endtask

    task automatic wait_sample_count_at_least(input integer target_count, input integer max_cycles, output bit ok);
        integer k;
    begin
        ok = 0;
        for (k = 0; k < max_cycles; k = k + 1) begin
            if (sample_hs_count >= target_count) begin
                ok = 1;
                break;
            end
            @(posedge clk);
        end
    end
    endtask

    task automatic wait_n_cycles(input integer n);
        integer k;
    begin
        for (k = 0; k < n; k = k + 1)
            @(posedge clk);
    end
    endtask

    function automatic logic [31:0] pack_be4(
        input logic [7:0] b0,
        input logic [7:0] b1,
        input logic [7:0] b2,
        input logic [7:0] b3
    );
    begin
        pack_be4 = {b0,b1,b2,b3};
    end
    endfunction

    task automatic send_sample_word_bytes(
        input logic [7:0] b0,
        input logic [7:0] b1,
        input logic [7:0] b2,
        input logic [7:0] b3,
        input logic       last_on_b3
    );
    begin
        send_byte(b0, 1'b0);
        send_byte(b1, 1'b0);
        send_byte(b2, 1'b0);
        send_byte(b3, last_on_b3);
    end
    endtask

    // ============================================================
    // Test sequence
    // ============================================================
    integer base_hdr;
    integer base_sample;
    integer i;

    bit ok;

    initial begin
        apply_reset();

        // ========================================================
        // TEST 1: valid DSP packet + verbose cycle logging
        // ========================================================
        $display("\n============================================================");
        $display("TEST 1: Valid DSP packet + verbose cycle logging");
        $display("============================================================");

        verbose_cycle_log  = 1'b1;
        verbose_sample_log = 1'b1;

        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;

        // Keep downstream ready
        @(negedge clk);
        m_sample_tready <= 1'b1;

        // Header: FF 00 AA 55
        send_header(8'hFF, 8'h00, 8'hAA, 8'h55, 1'b0);

        wait_hdr_valid(20, ok);
        check_true("T1 hdr_valid asserted", ok);
        if (ok) begin
            check_true("T1 hdr_batch = lower nibble of 0xAA", hdr_batch === 4'hA);
            check_eq_u16("T1 hdr_seq = zero-extended 0x55", hdr_seq, 16'h0055);

            pulse_hdr_ready();
            wait_hdr_low(10, ok);
            check_true("T1 hdr_valid drops after header handshake", ok);
        end

        // Send 64 sample words
        for (i = 0; i < 64; i = i + 1) begin
            logic last_word;
            logic [7:0] b0, b1, b2, b3;

            last_word = (i == 63);
            b0 = i[7:0];
            b1 = i[7:0] + 8'd1;
            b2 = i[7:0] + 8'd2;
            b3 = i[7:0] + 8'd3;

            send_sample_word_bytes(b0, b1, b2, b3, last_word);
        end

        wait_sample_count_at_least(base_sample + 64, 30, ok);
        check_true("T1 got 64 sample handshakes", ok);

        if (sample_hs_count >= base_sample + 64) begin
            check_eq_u6("T1 first sample index", sample_index_hist[base_sample + 0], 6'd0);
            check_eq_u6("T1 last sample index",  sample_index_hist[base_sample + 63], 6'd63);

            check_true("T1 first sample last=0", sample_last_hist[base_sample + 0]  === 1'b0);
            check_true("T1 last sample last=1",  sample_last_hist[base_sample + 63] === 1'b1);

            // Intended packing check. If this fails, it is likely a DUT issue, not a TB issue.
            check_eq_u32("T1 intended first sample word = 0x00010203",
                         sample_word_hist[base_sample + 0], pack_be4(8'h00,8'h01,8'h02,8'h03));
            check_eq_u32("T1 intended second sample word = 0x01020304",
                         sample_word_hist[base_sample + 1], pack_be4(8'h01,8'h02,8'h03,8'h04));
        end

        verbose_cycle_log  = 1'b0;
        verbose_sample_log = 1'b0;

        wait_n_cycles(5);

        // ========================================================
        // TEST 2: header backpressure / hold until hdr_ready
        // ========================================================
        $display("\n============================================================");
        $display("TEST 2: Header backpressure hold");
        $display("============================================================");

        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;

        @(negedge clk);
        m_sample_tready <= 1'b1;
        hdr_ready <= 1'b0;

        send_header(8'hFF, 8'h00, 8'hBC, 8'h33, 1'b0);

        wait_hdr_valid(20, ok);
        check_true("T2 hdr_valid asserted", ok);
        if (ok) begin
            check_true("T2 hdr_valid stays high before hdr_ready", hdr_valid === 1'b1);
            check_true("T2 hdr_batch stable while waiting", hdr_batch === 4'hC);
            check_eq_u16("T2 hdr_seq stable while waiting", hdr_seq, 16'h0033);

            wait_n_cycles(4);
            check_true("T2 hdr_valid still high after stall", hdr_valid === 1'b1);
            check_true("T2 no header handshake before hdr_ready", hdr_hs_count == base_hdr);

            pulse_hdr_ready();
            wait_hdr_low(10, ok);
            check_true("T2 hdr_valid drops after handshake", ok);
            check_true("T2 exactly one header handshake", hdr_hs_count == base_hdr + 1);
        end

        // terminate packet cleanly with tlast after no payload
        send_byte(8'h00, 1'b1);
        wait_n_cycles(3);

        // ========================================================
        // TEST 3: bad magic
        // ========================================================
        $display("\n============================================================");
        $display("TEST 3: Bad magic");
        $display("============================================================");

        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;

        send_header(8'hAA, 8'h00, 8'h00, 8'h00, 1'b1);
        wait_n_cycles(8);

        check_true("T3 no hdr_valid after bad magic", hdr_valid === 1'b0);
        check_true("T3 no header handshake after bad magic", hdr_hs_count == base_hdr);
        check_true("T3 no sample handshake after bad magic", sample_hs_count == base_sample);

        // ========================================================
        // TEST 4: bad type
        // ========================================================
        $display("\n============================================================");
        $display("TEST 4: Bad type 0x99");
        $display("============================================================");

        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;

        send_header(8'hFF, 8'h99, 8'h00, 8'h00, 1'b1);
        wait_n_cycles(8);

        check_true("T4 no hdr_valid after bad type", hdr_valid === 1'b0);
        check_true("T4 no header handshake after bad type", hdr_hs_count == base_hdr);
        check_true("T4 no sample handshake after bad type", sample_hs_count == base_sample);

        // ========================================================
        // TEST 5: discard packet types 0x01, 0x02, 0x03
        // ========================================================
        $display("\n============================================================");
        $display("TEST 5: Discard packet types 0x01, 0x02, 0x03");
        $display("============================================================");

        // foreach ({i}) begin end // no-op to keep some simulators happy with logic declarations above

        // type 0x01
        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;
        send_header(8'hFF, 8'h01, 8'h11, 8'h22, 1'b1);
        wait_n_cycles(6);
        check_true("T5.1 no header handshake for type 0x01", hdr_hs_count == base_hdr);
        check_true("T5.1 no sample handshake for type 0x01", sample_hs_count == base_sample);

        // type 0x02
        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;
        send_header(8'hFF, 8'h02, 8'h11, 8'h22, 1'b1);
        wait_n_cycles(6);
        check_true("T5.2 no header handshake for type 0x02", hdr_hs_count == base_hdr);
        check_true("T5.2 no sample handshake for type 0x02", sample_hs_count == base_sample);

        // type 0x03
        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;
        send_header(8'hFF, 8'h03, 8'h11, 8'h22, 1'b1);
        wait_n_cycles(6);
        check_true("T5.3 no header handshake for type 0x03", hdr_hs_count == base_hdr);
        check_true("T5.3 no sample handshake for type 0x03", sample_hs_count == base_sample);

        // ========================================================
        // TEST 6: back-to-back valid packets
        // ========================================================
        $display("\n============================================================");
        $display("TEST 6: Back-to-back valid packets");
        $display("============================================================");

        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;

        @(negedge clk);
        m_sample_tready <= 1'b1;

        // Packet A
        send_header(8'hFF, 8'h00, 8'h1A, 8'h10, 1'b0);
        wait_hdr_valid(20, ok);
        check_true("T6 pktA hdr_valid", ok);
        if (ok) begin
            check_true("T6 pktA batch", hdr_batch === 4'hA);
            check_eq_u16("T6 pktA seq", hdr_seq, 16'h0010);
            pulse_hdr_ready();
            wait_hdr_low(10, ok);
            check_true("T6 pktA hdr_valid drops", ok);
        end
        send_sample_word_bytes(8'h10,8'h11,8'h12,8'h13, 1'b1);

        // Packet B immediately after
        send_header(8'hFF, 8'h00, 8'h2B, 8'h20, 1'b0);
        wait_hdr_valid(20, ok);
        check_true("T6 pktB hdr_valid", ok);
        if (ok) begin
            check_true("T6 pktB batch", hdr_batch === 4'hB);
            check_eq_u16("T6 pktB seq", hdr_seq, 16'h0020);
            pulse_hdr_ready();
            wait_hdr_low(10, ok);
            check_true("T6 pktB hdr_valid drops", ok);
        end
        send_sample_word_bytes(8'h20,8'h21,8'h22,8'h23, 1'b1);

        wait_n_cycles(8);
        check_true("T6 two header handshakes occurred", hdr_hs_count >= base_hdr + 2);
        check_true("T6 two sample handshakes occurred", sample_hs_count >= base_sample + 2);

        // ========================================================
        // TEST 7: truncated header and truncated payload, then recovery
        // ========================================================
        $display("\n============================================================");
        $display("TEST 7: Truncated packet recovery");
        $display("============================================================");

        // 7A truncated header
        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;

        send_byte(8'hFF, 1'b0);
        send_byte(8'h00, 1'b1);  // ends in middle of header
        wait_n_cycles(6);

        check_true("T7A no header handshake after truncated header", hdr_hs_count == base_hdr);
        check_true("T7A no sample handshake after truncated header", sample_hs_count == base_sample);

        // 7B truncated payload
        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;

        send_header(8'hFF, 8'h00, 8'h44, 8'h66, 1'b0);
        wait_hdr_valid(20, ok);
        check_true("T7B hdr_valid asserted", ok);
        if (ok) begin
            pulse_hdr_ready();
            wait_hdr_low(10, ok);
            check_true("T7B hdr_valid drops after handshake", ok);
        end

        // only 2 payload bytes then tlast
        send_byte(8'hDE, 1'b0);
        send_byte(8'hAD, 1'b1);
        wait_n_cycles(6);

        check_true("T7B no sample handshake for partial payload word", sample_hs_count == base_sample);

        // recovery with next valid packet
        send_header(8'hFF, 8'h00, 8'h07, 8'h77, 1'b0);
        wait_hdr_valid(20, ok);
        check_true("T7B recovery packet hdr_valid", ok);
        if (ok) begin
            check_true("T7B recovery batch", hdr_batch === 4'h7);
            check_eq_u16("T7B recovery seq", hdr_seq, 16'h0077);
            pulse_hdr_ready();
            wait_hdr_low(10, ok);
            check_true("T7B recovery hdr_valid drops", ok);
        end
        send_sample_word_bytes(8'h01,8'h02,8'h03,8'h04,1'b1);
        wait_n_cycles(6);
        check_true("T7B recovery packet produced a sample handshake", sample_hs_count >= base_sample + 1);

        // ========================================================
        // TEST 8: downstream sample backpressure
        // This is a required integration test.
        // If it fails, the DUT is not safe in a larger stalled parser chain.
        // ========================================================
        $display("\n============================================================");
        $display("TEST 8: Sample backpressure stress");
        $display("============================================================");

        base_hdr    = hdr_hs_count;
        base_sample = sample_hs_count;

        @(negedge clk);
        m_sample_tready <= 1'b1;

        send_header(8'hFF, 8'h00, 8'h09, 8'h99, 1'b0);
        wait_hdr_valid(20, ok);
        check_true("T8 hdr_valid asserted", ok);
        if (ok) begin
            pulse_hdr_ready();
            wait_hdr_low(10, ok);
            check_true("T8 hdr_valid drops", ok);
        end

        // First word accepted
        send_sample_word_bytes(8'hA0,8'hA1,8'hA2,8'hA3,1'b0);
        wait_n_cycles(4);

        // Stall downstream during second word
        @(negedge clk);
        m_sample_tready <= 1'b0;
        send_sample_word_bytes(8'hB0,8'hB1,8'hB2,8'hB3,1'b0);
        wait_n_cycles(4);

        // Re-enable and send third word
        @(negedge clk);
        m_sample_tready <= 1'b1;
        send_sample_word_bytes(8'hC0,8'hC1,8'hC2,8'hC3,1'b1);
        wait_n_cycles(10);

        // Intended behavior for a robust parser: 3 sample words total.
        // Current DUT may fail this because it does not buffer output while not ready.
        check_true("T8 expected 3 sample handshakes total for 3 words (robust-stream expectation)",
                   sample_hs_count >= base_sample + 3);

        // ========================================================
        // Summary
        // ========================================================
        $display("\n============================================================");
        $display("FINAL SUMMARY");
        $display("============================================================");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule

