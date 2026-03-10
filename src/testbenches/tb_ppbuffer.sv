
`timescale 1ns/1ps

module tb_ppbuffer;

    // =========================================================================
    // Clock / reset
    // =========================================================================
    logic clk = 0;
    logic rst = 1;

    always #5 clk = ~clk;

    // =========================================================================
    // DUT I/O
    // =========================================================================
    logic        rx_batch_start;
    logic [9:0]  rx_batch_row_id;
    logic [1:0]  rx_batch_id;

    logic        rx_sample_valid;
    logic [31:0] rx_sample_re;
    logic [31:0] rx_sample_im;
    logic        rx_sample_last;
    logic        rx_sample_ready;

    logic        dsp_in_valid;
    logic        dsp_in_row_start;
    logic [31:0] dsp_in_re;
    logic [31:0] dsp_in_im;

    logic        dsp_out_valid;
    logic [31:0] dsp_out_re;
    logic [31:0] dsp_out_im;

    logic        tx_row_valid;
    logic        tx_row_ready;
    logic        tx_row_start;
    logic [9:0]  tx_row_row_id;
    logic [31:0] tx_row_re;
    logic [31:0] tx_row_im;

    logic        rx_overflow;
    logic        row_tx_done;

    row_pingpong_buffer dut (
        .clk(clk),
        .rst(rst),

        .rx_batch_start(rx_batch_start),
        .rx_batch_row_id(rx_batch_row_id),
        .rx_batch_id(rx_batch_id),
        .rx_sample_valid(rx_sample_valid),
        .rx_sample_re(rx_sample_re),
        .rx_sample_im(rx_sample_im),
        .rx_sample_last(rx_sample_last),
        .rx_sample_ready(rx_sample_ready),

        .dsp_in_valid(dsp_in_valid),
        .dsp_in_row_start(dsp_in_row_start),
        .dsp_in_re(dsp_in_re),
        .dsp_in_im(dsp_in_im),

        .dsp_out_valid(dsp_out_valid),
        .dsp_out_re(dsp_out_re),
        .dsp_out_im(dsp_out_im),

        .tx_row_valid(tx_row_valid),
        .tx_row_ready(tx_row_ready),
        .tx_row_start(tx_row_start),
        .tx_row_row_id(tx_row_row_id),
        .tx_row_re(tx_row_re),
        .tx_row_im(tx_row_im),

        .rx_overflow(rx_overflow),
        .row_tx_done(row_tx_done)
    );

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
    // Simple DSP model:
    //   fixed latency = 2 cycles
    //   transform:
    //      out_re = in_re + 1
    //      out_im = in_im + 2
    // =========================================================================
    logic [31:0] pipe_re0, pipe_re1;
    logic [31:0] pipe_im0, pipe_im1;
    logic        pipe_v0, pipe_v1;

    always @(posedge clk) begin
        if (rst) begin
            pipe_re0     <= 0;
            pipe_re1     <= 0;
            pipe_im0     <= 0;
            pipe_im1     <= 0;
            pipe_v0      <= 0;
            pipe_v1      <= 0;
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
    // Capture DSP input and TX output for checking
    // =========================================================================
    logic [31:0] dsp_in_re_cap [0:2047];
    logic [31:0] dsp_in_im_cap [0:2047];
    int dsp_in_count;
    int dsp_row_start_count;

    logic [31:0] tx_re_cap [0:4095];
    logic [31:0] tx_im_cap [0:4095];
    logic [9:0]  tx_rowid_cap [0:4095];
    int tx_count;
    int tx_row_start_count;
    int tx_done_count;
    int overflow_count;

    always @(posedge clk) begin
        if (rst) begin
            dsp_in_count <= 0;
            dsp_row_start_count <= 0;
            tx_count <= 0;
            tx_row_start_count <= 0;
            tx_done_count <= 0;
            overflow_count <= 0;
        end else begin
            if (dsp_in_valid) begin
                dsp_in_re_cap[dsp_in_count] <= dsp_in_re;
                dsp_in_im_cap[dsp_in_count] <= dsp_in_im;
                dsp_in_count <= dsp_in_count + 1;
                if (dsp_in_row_start)
                    dsp_row_start_count <= dsp_row_start_count + 1;
            end

            if (tx_row_valid && tx_row_ready) begin
                tx_re_cap[tx_count] <= tx_row_re;
                tx_im_cap[tx_count] <= tx_row_im;
                tx_rowid_cap[tx_count] <= tx_row_row_id;
                tx_count <= tx_count + 1;
                if (tx_row_start)
                    tx_row_start_count <= tx_row_start_count + 1;
            end

            if (row_tx_done)
                tx_done_count <= tx_done_count + 1;

            if (rx_overflow)
                overflow_count <= overflow_count + 1;
        end
    end

    task clear_caps;
        int i;
    begin
        dsp_in_count = 0;
        dsp_row_start_count = 0;
        tx_count = 0;
        tx_row_start_count = 0;
        tx_done_count = 0;
        overflow_count = 0;

        for (i = 0; i < 4096; i++) begin
            tx_re_cap[i] = 0;
            tx_im_cap[i] = 0;
            tx_rowid_cap[i] = 0;
        end

        for (i = 0; i < 2048; i++) begin
            dsp_in_re_cap[i] = 0;
            dsp_in_im_cap[i] = 0;
        end
    end
    endtask

    // =========================================================================
    // Helpers
    // =========================================================================
    function automatic [31:0] expected_re(input [9:0] row_id, input int sample_idx);
    begin
        expected_re = row_id * 32'd10000 + sample_idx;
    end
    endfunction

    function automatic [31:0] expected_im(input [9:0] row_id, input int sample_idx);
    begin
        expected_im = 32'h8000_0000 + row_id * 32'd10000 + sample_idx;
    end
    endfunction

    task idle_cycles(input int n);
        int i;
    begin
        for (i = 0; i < n; i++) begin
            @(posedge clk);
            rx_batch_start <= 0;
            rx_sample_valid <= 0;
            rx_sample_last <= 0;
            rx_batch_row_id <= 0;
            rx_batch_id <= 0;
            rx_sample_re <= 0;
            rx_sample_im <= 0;
        end
    end
    endtask

    task send_batch(input [9:0] row_id, input [1:0] batch_id_val);
        int i;
        int global_idx;
    begin
        for (i = 0; i < 128; i++) begin
            global_idx = batch_id_val * 128 + i;

            @(posedge clk);
            rx_batch_start <= (i == 0);
            rx_batch_row_id <= row_id;
            rx_batch_id <= batch_id_val;
            rx_sample_valid <= 1'b1;
            rx_sample_re <= expected_re(row_id, global_idx);
            rx_sample_im <= expected_im(row_id, global_idx);
            rx_sample_last <= (i == 127);
        end

        @(posedge clk);
        rx_batch_start <= 0;
        rx_sample_valid <= 0;
        rx_sample_last <= 0;
        rx_batch_row_id <= 0;
        rx_batch_id <= 0;
        rx_sample_re <= 0;
        rx_sample_im <= 0;
    end
    endtask

    task wait_for_tx_done(input int wanted_done_count, input int timeout_cycles, output logic ok);
        int i;
    begin
        ok = 0;
        for (i = 0; i < timeout_cycles; i++) begin
            @(posedge clk);
            if (tx_done_count >= wanted_done_count) begin
                ok = 1;
                disable wait_done_block;
            end
        end
        begin : wait_done_block end
    end
    endtask

    // =========================================================================
    // Main sequence
    // =========================================================================
    logic ok;
    int i;

    initial begin
        rx_batch_start = 0;
        rx_batch_row_id = 0;
        rx_batch_id = 0;
        rx_sample_valid = 0;
        rx_sample_re = 0;
        rx_sample_im = 0;
        rx_sample_last = 0;
        tx_row_ready = 1;
        dsp_out_valid = 0;
        dsp_out_re = 0;
        dsp_out_im = 0;

        repeat (10) @(posedge clk);
        rst = 0;

        // ---------------------------------------------------------------------
        // TEST 1: Basic row reassembly with out-of-order batches
        // ---------------------------------------------------------------------
        $display("TEST1: basic row reassembly / DSP / TX");
        clear_caps();

        send_batch(10'd5, 2);
        send_batch(10'd5, 0);
        send_batch(10'd5, 3);
        send_batch(10'd5, 1);

        wait_for_tx_done(1, 5000, ok);

        expect_local(ok, "row 5 transmitted");
        expect_local(dsp_in_count == 512, "DSP got 512 input samples");
        expect_local(dsp_row_start_count == 1, "DSP row_start seen once");
        expect_local(tx_count == 512, "TX streamed 512 processed samples");
        expect_local(tx_row_start_count == 1, "TX row_start seen once");
        expect_local(tx_done_count == 1, "row_tx_done seen once");
        expect_local(overflow_count == 0, "no overflow in basic test");

        for (i = 0; i < 512; i++) begin
            expect_local(dsp_in_re_cap[i] == expected_re(5, i),
                $sformatf("DSP input Re sample %0d correct", i));
            expect_local(dsp_in_im_cap[i] == expected_im(5, i),
                $sformatf("DSP input Im sample %0d correct", i));

            expect_local(tx_re_cap[i] == expected_re(5, i) + 32'd1,
                $sformatf("TX output Re sample %0d correct", i));
            expect_local(tx_im_cap[i] == expected_im(5, i) + 32'd2,
                $sformatf("TX output Im sample %0d correct", i));
            expect_local(tx_rowid_cap[i] == 10'd5,
                $sformatf("TX output row_id sample %0d correct", i));
        end

        // ---------------------------------------------------------------------
        // TEST 2: Ping-pong overlap
        // Row 6 starts processing, row 7 assembles in the other slot
        // ---------------------------------------------------------------------
        $display("TEST2: ping-pong overlap");
        clear_caps();

        fork
            begin
                send_batch(10'd6, 0);
                send_batch(10'd6, 1);
                send_batch(10'd6, 2);
                send_batch(10'd6, 3);
            end
            begin
                // Let row 6 start processing, then assemble row 7
                repeat (600) @(posedge clk);
                send_batch(10'd7, 0);
                send_batch(10'd7, 1);
                send_batch(10'd7, 2);
                send_batch(10'd7, 3);
            end
        join

        wait_for_tx_done(2, 12000, ok);

        expect_local(ok, "two rows transmitted");
        expect_local(tx_done_count == 2, "two row_tx_done pulses seen");
        expect_local(tx_row_start_count == 2, "two TX row starts seen");

        // row 6 occupies samples 0..511, row 7 occupies 512..1023
        for (i = 0; i < 512; i++) begin
            expect_local(tx_re_cap[i] == expected_re(6, i) + 32'd1,
                $sformatf("row6 TX Re sample %0d correct", i));
            expect_local(tx_rowid_cap[i] == 10'd6,
                $sformatf("row6 TX row_id sample %0d correct", i));
        end

        for (i = 0; i < 512; i++) begin
            expect_local(tx_re_cap[512+i] == expected_re(7, i) + 32'd1,
                $sformatf("row7 TX Re sample %0d correct", i));
            expect_local(tx_rowid_cap[512+i] == 10'd7,
                $sformatf("row7 TX row_id sample %0d correct", i));
        end

        // ---------------------------------------------------------------------
        // TEST 3: TX backpressure
        // ---------------------------------------------------------------------
        $display("TEST3: TX backpressure");
        clear_caps();

        fork
            begin
                send_batch(10'd9, 0);
                send_batch(10'd9, 1);
                send_batch(10'd9, 2);
                send_batch(10'd9, 3);
            end
            begin
                tx_row_ready <= 1'b1;
                repeat (700) @(posedge clk); // allow row complete + DSP start
                repeat (5000) begin
                    @(posedge clk);
                    tx_row_ready <= $urandom_range(0,1);
                    if (tx_done_count >= 1)
                        disable bp_done;
                end
                begin : bp_done end
                tx_row_ready <= 1'b1;
            end
        join

        wait_for_tx_done(1, 12000, ok);

        expect_local(ok, "row transmitted under TX backpressure");
        expect_local(tx_count == 512, "512 TX samples under backpressure");
        expect_local(tx_row_start_count == 1, "one TX row start under backpressure");
        expect_local(tx_done_count == 1, "one row_tx_done under backpressure");

        for (i = 0; i < 512; i++) begin
            expect_local(tx_re_cap[i] == expected_re(9, i) + 32'd1,
                $sformatf("BP TX Re sample %0d correct", i));
            expect_local(tx_rowid_cap[i] == 10'd9,
                $sformatf("BP TX row_id sample %0d correct", i));
        end

        tx_row_ready <= 1'b1;

        // ---------------------------------------------------------------------
        // TEST 4: Overflow when both slots occupied
        // Fill slot0 with row10 batch0 only
        // Fill slot1 with row11 batch0 only
        // Then try to start row12 batch0 -> expect overflow pulse
        // ---------------------------------------------------------------------
        $display("TEST4: overflow when both slots occupied");
        clear_caps();

        send_batch(10'd10, 0);
        idle_cycles(5);
        send_batch(10'd11, 0);
        idle_cycles(5);

        // third row should overflow because both slots allocated and neither free
        send_batch(10'd12, 0);
        idle_cycles(10);

        expect_local(overflow_count > 0, "overflow detected when both slots occupied");
        expect_local(tx_done_count == 0, "no TX row done during overflow setup");

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");
        $finish;
    end

endmodule