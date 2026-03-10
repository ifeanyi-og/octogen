`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/09/2026 09:55:26 PM
// Design Name: 
// Module Name: tb_packet_tx
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

module tb_packet_tx;

    // ========================================================================
    // Clock / reset
    // ========================================================================
    logic clk = 0;
    logic rst = 1;

    always #5 clk = ~clk;

    // ========================================================================
    // DUT I/O
    // ========================================================================
    logic        row_in_valid;
    logic        row_in_ready;
    logic        row_in_start;
    logic [9:0]  row_in_row_id;
    logic [31:0] row_in_re;
    logic [31:0] row_in_im;

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
        .row_in_row_id(row_in_row_id),
        .row_in_re(row_in_re),
        .row_in_im(row_in_im),

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
    localparam ROW_SAMPLES      = 512;
    localparam BATCH_SAMPLES    = 128;
    localparam HEADER_BYTES     = 4;
    localparam PAYLOAD_BYTES    = 1024;
    localparam BYTES_PER_PACKET = 1028;
    localparam TOTAL_BYTES      = 4 * BYTES_PER_PACKET;

    logic [7:0] captured_bytes [0:8191];
    int captured_count;
    int pkt_start_count;
    int tlast_count;
    logic seen_row_done;

    always @(posedge clk) begin
        if (rst) begin
            captured_count <= 0;
            pkt_start_count <= 0;
            tlast_count <= 0;
            seen_row_done <= 0;
        end else begin
            if (pkt_start)
                pkt_start_count <= pkt_start_count + 1;

            if (row_done)
                seen_row_done <= 1;

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
        captured_count = 0;
        pkt_start_count = 0;
        tlast_count = 0;
        seen_row_done = 0;
        for (i = 0; i < 8192; i++) begin
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
            row_in_valid  <= 0;
            row_in_start  <= 0;
            row_in_row_id <= '0;
            row_in_re     <= '0;
            row_in_im     <= '0;
        end
    end
    endtask

    task send_row(input [9:0] row_id);
        int i;
        logic [31:0] re_val;
        logic [31:0] im_val;
    begin
        for (i = 0; i < ROW_SAMPLES; i++) begin
            re_val = i;
            im_val = i + 1000;

            @(posedge clk);
            row_in_valid  <= 1'b1;
            row_in_start  <= (i == 0);
            row_in_row_id <= row_id;
            row_in_re     <= re_val;
            row_in_im     <= im_val;
        end

        @(posedge clk);
        row_in_valid  <= 1'b0;
        row_in_start  <= 1'b0;
        row_in_row_id <= '0;
        row_in_re     <= '0;
        row_in_im     <= '0;
    end
    endtask

    function automatic [7:0] expected_byte(
        input int row_id,
        input int packet_idx,
        input int byte_idx
    );
        int payload_index;
        int sample_local_index;
        int global_sample_index;
        int byte_in_sample;
        logic [31:0] re_val;
        logic [31:0] im_val;
        logic [31:0] hdr_word;
    begin
        hdr_word = {8'hFF, 8'hFF, packet_idx[1:0], 4'b0000, row_id[9:0]};

        if (byte_idx == 0)
            expected_byte = hdr_word[7:0];
        else if (byte_idx == 1)
            expected_byte = hdr_word[15:8];
        else if (byte_idx == 2)
            expected_byte = hdr_word[23:16];
        else if (byte_idx == 3)
            expected_byte = hdr_word[31:24];
        else begin
            payload_index      = byte_idx - HEADER_BYTES;
            sample_local_index = payload_index / 8;
            global_sample_index = packet_idx * BATCH_SAMPLES + sample_local_index;
            byte_in_sample     = payload_index % 8;

            re_val = global_sample_index;
            im_val = global_sample_index + 1000;

            case (byte_in_sample)
                0: expected_byte = re_val[7:0];
                1: expected_byte = re_val[15:8];
                2: expected_byte = re_val[23:16];
                3: expected_byte = re_val[31:24];
                4: expected_byte = im_val[7:0];
                5: expected_byte = im_val[15:8];
                6: expected_byte = im_val[23:16];
                7: expected_byte = im_val[31:24];
                default: expected_byte = 8'h00;
            endcase
        end
    end
    endfunction

    task wait_for_row_done_or_timeout(input int max_cycles, output logic ok);
        int i;
    begin
        ok = 0;
        for (i = 0; i < max_cycles; i++) begin
            @(posedge clk);
            if (seen_row_done) begin
                ok = 1;
                disable wait_loop_done;
            end
        end
        begin : wait_loop_done end
    end
    endtask

    // ========================================================================
    // Main test sequence
    // ========================================================================
    logic ok;
    int i;
    int pkt;
    int idx;
    int absolute_index;

    initial begin
        row_in_valid  = 0;
        row_in_start  = 0;
        row_in_row_id = 0;
        row_in_re     = 0;
        row_in_im     = 0;
        tx_tready     = 1;

        repeat (10) @(posedge clk);
        rst = 0;

        // --------------------------------------------------------------------
        // TEST 1: No output before full row is captured
        // --------------------------------------------------------------------
        $display("TEST1: no output before full row captured");
        clear_captures();

        // send partial row only
        for (i = 0; i < 100; i++) begin
            @(posedge clk);
            row_in_valid  <= 1'b1;
            row_in_start  <= (i == 0);
            row_in_row_id <= 10'd10;
            row_in_re     <= i;
            row_in_im     <= i + 1000;
        end
        @(posedge clk);
        row_in_valid <= 0;
        row_in_start <= 0;

        idle_input(10);

        expect_local(captured_count == 0, "no TX bytes emitted before full row capture");
        expect_local(!seen_row_done, "row_done not asserted before full row capture");

        // RESET BETWEEN TESTS
        @(posedge clk);
        rst <= 1'b1;
        @(posedge clk);
        @(posedge clk);
        rst <= 1'b0;
        clear_captures();
        idle_input(2);

        // --------------------------------------------------------------------
        // TEST 2: Basic row capture and transmit, always-ready sink
        // --------------------------------------------------------------------
        $display("TEST2: full row packetization always-ready");
        clear_captures();

        send_row(10'd10);
        wait_for_row_done_or_timeout(10000, ok);

        expect_local(ok, "row_done seen");
        expect_local(captured_count == TOTAL_BYTES, "correct total byte count (4112)");
        expect_local(pkt_start_count == 4, "pkt_start seen 4 times");
        expect_local(tlast_count == 4, "tx_tlast seen 4 times");

        // Check every byte of all 4 packets
        for (pkt = 0; pkt < 4; pkt++) begin
            for (idx = 0; idx < BYTES_PER_PACKET; idx++) begin
                absolute_index = pkt * BYTES_PER_PACKET + idx;
                expect_local(
                    captured_bytes[absolute_index] === expected_byte(10, pkt, idx),
                    $sformatf("packet %0d byte %0d correct", pkt, idx)
                );
            end
        end

        // --------------------------------------------------------------------
        // TEST 3: Backpressure on TX
        // --------------------------------------------------------------------
        $display("TEST3: backpressure handling");
        clear_captures();

        fork
            begin
                send_row(10'd25);
            end
            begin
                // irregular backpressure during TX phase
                tx_tready <= 1'b1;
                repeat (550) @(posedge clk); // enough time to finish capture and enter TX
                repeat (5000) begin
                    @(posedge clk);
                    tx_tready <= $urandom_range(0,1);
                    if (seen_row_done)
                        disable bp_loop_done;
                end
                begin : bp_loop_done end
                tx_tready <= 1'b1;
            end
        join

        wait_for_row_done_or_timeout(12000, ok);

        expect_local(ok, "row_done seen with backpressure");
        expect_local(captured_count == TOTAL_BYTES, "correct total bytes with backpressure");
        expect_local(pkt_start_count == 4, "pkt_start count correct with backpressure");
        expect_local(tlast_count == 4, "tlast count correct with backpressure");

        for (pkt = 0; pkt < 4; pkt++) begin
            // spot-check critical positions
            expect_local(
                captured_bytes[pkt*BYTES_PER_PACKET + 0] === expected_byte(25, pkt, 0),
                $sformatf("BP packet %0d header byte0 correct", pkt)
            );
            expect_local(
                captured_bytes[pkt*BYTES_PER_PACKET + 1] === expected_byte(25, pkt, 1),
                $sformatf("BP packet %0d header byte1 correct", pkt)
            );
            expect_local(
                captured_bytes[pkt*BYTES_PER_PACKET + 4] === expected_byte(25, pkt, 4),
                $sformatf("BP packet %0d first payload byte correct", pkt)
            );
            expect_local(
                captured_bytes[pkt*BYTES_PER_PACKET + BYTES_PER_PACKET - 1] === expected_byte(25, pkt, BYTES_PER_PACKET-1),
                $sformatf("BP packet %0d last byte correct", pkt)
            );
        end

        tx_tready <= 1'b1;

        // --------------------------------------------------------------------
        // TEST 4: Second row after first row completes
        // --------------------------------------------------------------------
        $display("TEST4: sequential rows");
        clear_captures();

        send_row(10'd56);
        wait_for_row_done_or_timeout(10000, ok);
        expect_local(ok, "first sequential row done");
        expect_local(captured_bytes[0] == expected_byte(56, 0, 0), "first sequential row header correct");

        clear_captures();

        send_row(10'd57);
        wait_for_row_done_or_timeout(10000, ok);
        expect_local(ok, "second sequential row done");
        expect_local(captured_bytes[0] == expected_byte(57, 0, 0), "second sequential row header correct");
        expect_local(captured_bytes[1] == expected_byte(57, 0, 1), "second sequential row header byte1 correct");

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