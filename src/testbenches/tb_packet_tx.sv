`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_packet_tx
// Purpose:
//   Verifies app_packet_tx with internally generated row IDs:
//
//   - row_id starts at 0 after reset
//   - row_in_row_id is ignored by DUT
//   - each accepted new row gets next internal row ID
//   - sequential rows produce 0,1,2,... headers
//   - packet sizing matches 512 real samples -> 2 packets
//////////////////////////////////////////////////////////////////////////////////

module tb_packet_tx;

    // ========================================================================
    // Clock / reset
    // ========================================================================
    logic clk = 0;
    logic rst = 1;

    always #5 clk = ~clk;   // 100 MHz

    // ========================================================================
    // DUT I/O
    // ========================================================================
    logic        row_in_valid;
    logic        row_in_ready;
    logic        row_in_start;
    logic [9:0]  row_in_row_id;
    logic [31:0] row_in_data;

    logic [7:0]  tx_tdata;
    logic        tx_tvalid;
    logic        tx_tready;
    logic        tx_tlast;

    logic        pkt_start;
    logic [1:0]  pkt_batch_id;
    logic [9:0]  pkt_row_id;
    logic        row_done;

    // ========================================================================
    // DUT
    // ========================================================================
    app_packet_tx dut (
        .clk(clk),
        .rst(rst),

        .row_in_valid(row_in_valid),
        .row_in_ready(row_in_ready),
        .row_in_start(row_in_start),
        .row_in_row_id(row_in_row_id),   // ignored by DUT
        .row_in_data(row_in_data),

        .tx_tdata(tx_tdata),
        .tx_tvalid(tx_tvalid),
        .tx_tready(tx_tready),
        .tx_tlast(tx_tlast),

        .pkt_start(pkt_start),
        .pkt_batch_id(pkt_batch_id),
        .pkt_row_id(pkt_row_id),
        .row_done(row_done)
    );

    // ========================================================================
    // Params
    // ========================================================================
    localparam ROW_SAMPLES      = 512;
    localparam BATCH_SAMPLES    = 256;
    localparam HEADER_BYTES     = 4;
    localparam PAYLOAD_BYTES    = 1024;
    localparam BYTES_PER_PACKET = 1028;
    localparam PACKETS_PER_ROW  = 2;
    localparam TOTAL_BYTES      = PACKETS_PER_ROW * BYTES_PER_PACKET;

    // ========================================================================
    // Scoreboard / counters
    // ========================================================================
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

    // ========================================================================
    // Capture outgoing bytes
    // ========================================================================
    logic [7:0] captured_bytes [0:4095];
    int captured_count;
    int pkt_start_count;
    int tlast_count;
    logic seen_row_done;

    always @(posedge clk) begin
        if (rst) begin
            captured_count  <= 0;
            pkt_start_count <= 0;
            tlast_count     <= 0;
            seen_row_done   <= 0;
        end else begin
            if (pkt_start)
                pkt_start_count <= pkt_start_count + 1;

            if (row_done)
                seen_row_done <= 1'b1;

            if (tx_tvalid && tx_tready) begin
                captured_bytes[captured_count] <= tx_tdata;
                captured_count <= captured_count + 1;

                if (tx_tlast)
                    tlast_count <= tlast_count + 1;
            end
        end
    end

    task clear_captures;
        int i;
    begin
        captured_count  = 0;
        pkt_start_count = 0;
        tlast_count     = 0;
        seen_row_done   = 0;
        for (i = 0; i < 4096; i++) begin
            captured_bytes[i] = 8'h00;
        end
    end
    endtask

    // ========================================================================
    // Stimulus helpers
    // ========================================================================
    task idle_input(input int cycles);
        int i;
    begin
        for (i = 0; i < cycles; i++) begin
            @(posedge clk);
            row_in_valid  <= 1'b0;
            row_in_start  <= 1'b0;
            row_in_row_id <= 10'd0;
            row_in_data   <= 32'd0;
        end
    end
    endtask

    // ext_row_id is intentionally meaningless now
    task send_row(input [9:0] ext_row_id);
        int i;
        logic [31:0] val;
    begin
        for (i = 0; i < ROW_SAMPLES; i++) begin
            val = i + 32'h2000;

            @(posedge clk);
            row_in_valid  <= 1'b1;
            row_in_start  <= (i == 0);
            row_in_row_id <= ext_row_id;   // ignored by DUT
            row_in_data   <= val;
        end

        @(posedge clk);
        row_in_valid  <= 1'b0;
        row_in_start  <= 1'b0;
        row_in_row_id <= 10'd0;
        row_in_data   <= 32'd0;
    end
    endtask

    function automatic [7:0] expected_byte(
        input int expected_row_id,
        input int packet_idx_f,
        input int byte_idx_f
    );
        int payload_index;
        int sample_local_index;
        int global_sample_index;
        int byte_in_sample;
        logic [31:0] val;
        logic [31:0] hdr_word;
    begin
        hdr_word = {8'hFF, 8'hFF, packet_idx_f[1:0], 4'b0000, expected_row_id[9:0]};

        if (byte_idx_f == 0)
            expected_byte = hdr_word[7:0];
        else if (byte_idx_f == 1)
            expected_byte = hdr_word[15:8];
        else if (byte_idx_f == 2)
            expected_byte = hdr_word[23:16];
        else if (byte_idx_f == 3)
            expected_byte = hdr_word[31:24];
        else begin
            payload_index       = byte_idx_f - HEADER_BYTES;
            sample_local_index  = payload_index / 4;
            global_sample_index = packet_idx_f * BATCH_SAMPLES + sample_local_index;
            byte_in_sample      = payload_index % 4;

            val = global_sample_index + 32'h2000;

            case (byte_in_sample)
                0: expected_byte = val[7:0];
                1: expected_byte = val[15:8];
                2: expected_byte = val[23:16];
                3: expected_byte = val[31:24];
                default: expected_byte = 8'h00;
            endcase
        end
    end
    endfunction

    task wait_for_row_done_or_timeout(input int max_cycles, output logic ok);
        int i;
    begin
        ok = 1'b0;
        for (i = 0; i < max_cycles; i++) begin
            @(posedge clk);
            if (seen_row_done) begin
                ok = 1'b1;
                i  = max_cycles;
            end
        end
    end
    endtask

    task check_full_row_bytes(input int expected_row_id);
        int pkt;
        int idx;
        int absolute_index;
    begin
        expect_local(captured_count == TOTAL_BYTES, "correct total byte count");
        expect_local(pkt_start_count == PACKETS_PER_ROW, "pkt_start seen 2 times");
        expect_local(tlast_count == PACKETS_PER_ROW, "tx_tlast seen 2 times");

        for (pkt = 0; pkt < PACKETS_PER_ROW; pkt++) begin
            for (idx = 0; idx < BYTES_PER_PACKET; idx++) begin
                absolute_index = pkt * BYTES_PER_PACKET + idx;
                expect_local(
                    captured_bytes[absolute_index] === expected_byte(expected_row_id, pkt, idx),
                    $sformatf("row_id=%0d packet=%0d byte=%0d correct", expected_row_id, pkt, idx)
                );
            end
        end
    end
    endtask

    // ========================================================================
    // Main test sequence
    // ========================================================================
    logic ok;
    int pkt;

    initial begin
        row_in_valid  = 0;
        row_in_start  = 0;
        row_in_row_id = 0;
        row_in_data   = 0;
        tx_tready     = 1;

        repeat (10) @(posedge clk);
        rst = 0;

        // --------------------------------------------------------------------
        // TEST 1: No output before full row is captured
        // --------------------------------------------------------------------
        $display("TEST1: no output before full row captured");
        clear_captures();

        for (int i = 0; i < 100; i++) begin
            @(posedge clk);
            row_in_valid  <= 1'b1;
            row_in_start  <= (i == 0);
            row_in_row_id <= 10'd123;   // ignored
            row_in_data   <= i + 32'h2000;
        end

        @(posedge clk);
        row_in_valid <= 1'b0;
        row_in_start <= 1'b0;

        idle_input(10);

        expect_local(captured_count == 0, "no TX bytes before full row capture");
        expect_local(!seen_row_done, "row_done not asserted before full row capture");

        // clean reset so internal row counter restarts at 0
        @(posedge clk);
        rst <= 1'b1;
        @(posedge clk);
        @(posedge clk);
        rst <= 1'b0;
        clear_captures();
        idle_input(2);

        // --------------------------------------------------------------------
        // TEST 2: First full row after reset should transmit row_id = 0
        // --------------------------------------------------------------------
        $display("TEST2: first full row should use row_id 0");
        clear_captures();

        send_row(10'd10);   // ignored by DUT
        wait_for_row_done_or_timeout(10000, ok);

        expect_local(ok, "row_done seen");
        check_full_row_bytes(0);

        // --------------------------------------------------------------------
        // TEST 3: Backpressure on TX, second row should be row_id = 1
        // --------------------------------------------------------------------
        $display("TEST3: backpressure handling, second row should be row_id 1");
        clear_captures();

        fork
            begin
                send_row(10'd25);   // ignored by DUT
            end
            begin
                tx_tready <= 1'b1;
                repeat (550) @(posedge clk);
                repeat (5000) begin
                    @(posedge clk);
                    tx_tready <= $urandom_range(0,1);
                    if (seen_row_done)
                        disable bp_done;
                end
                begin : bp_done end
                tx_tready <= 1'b1;
            end
        join

        wait_for_row_done_or_timeout(12000, ok);

        expect_local(ok, "row_done seen with backpressure");
        expect_local(captured_count == TOTAL_BYTES, "correct total bytes with backpressure");
        expect_local(pkt_start_count == PACKETS_PER_ROW, "pkt_start count correct with backpressure");
        expect_local(tlast_count == PACKETS_PER_ROW, "tlast count correct with backpressure");

        for (pkt = 0; pkt < PACKETS_PER_ROW; pkt++) begin
            expect_local(
                captured_bytes[pkt*BYTES_PER_PACKET + 0] === expected_byte(1, pkt, 0),
                $sformatf("BP packet %0d header byte0 correct", pkt)
            );
            expect_local(
                captured_bytes[pkt*BYTES_PER_PACKET + 1] === expected_byte(1, pkt, 1),
                $sformatf("BP packet %0d header byte1 correct", pkt)
            );
            expect_local(
                captured_bytes[pkt*BYTES_PER_PACKET + 4] === expected_byte(1, pkt, 4),
                $sformatf("BP packet %0d first payload byte correct", pkt)
            );
            expect_local(
                captured_bytes[pkt*BYTES_PER_PACKET + BYTES_PER_PACKET - 1] === expected_byte(1, pkt, BYTES_PER_PACKET-1),
                $sformatf("BP packet %0d last byte correct", pkt)
            );
        end

        tx_tready <= 1'b1;

        // --------------------------------------------------------------------
        // TEST 4: Sequential rows should increment internal row IDs
        // --------------------------------------------------------------------
        $display("TEST4: sequential rows increment internal row IDs");
        clear_captures();

        send_row(10'd56);   // ignored
        wait_for_row_done_or_timeout(10000, ok);
        expect_local(ok, "third row done");
        expect_local(captured_bytes[0] == expected_byte(2, 0, 0), "third row header correct for row_id 2");
        expect_local(captured_bytes[1] == expected_byte(2, 0, 1), "third row header byte1 correct for row_id 2");

        clear_captures();

        send_row(10'd57);   // ignored
        wait_for_row_done_or_timeout(10000, ok);
        expect_local(ok, "fourth row done");
        expect_local(captured_bytes[0] == expected_byte(3, 0, 0), "fourth row header correct for row_id 3");
        expect_local(captured_bytes[1] == expected_byte(3, 0, 1), "fourth row header byte1 correct for row_id 3");

        // --------------------------------------------------------------------
        // TEST 5: row_in_row_id is ignored
        // --------------------------------------------------------------------
        $display("TEST5: external row_in_row_id does not affect transmitted header");
        clear_captures();

        send_row(10'd499);  // ignored
        wait_for_row_done_or_timeout(10000, ok);

        expect_local(ok, "fifth row done");
        expect_local(captured_bytes[0] == expected_byte(4, 0, 0), "header uses internal row_id 4, not external 499");
        expect_local(captured_bytes[1] == expected_byte(4, 0, 1), "header byte1 uses internal row_id 4");

        // --------------------------------------------------------------------
        // Summary
        // --------------------------------------------------------------------
        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");

        $finish;
    end

endmodule

