`timescale 1ns/1ps

module tb_ppbuffer;

    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    logic        rx_batch_start;
    logic [9:0]  rx_batch_row_id;
    logic [1:0]  rx_batch_id;
    logic        rx_sample_valid;
    logic [31:0] rx_sample_data;
    logic        rx_sample_last;
    logic        rx_sample_ready;

    logic        dsp_in_valid;
    logic        dsp_in_row_start;
    logic [31:0] dsp_in_data;

    logic        dsp_out_valid;
    logic [31:0] dsp_out_data;

    logic        tx_row_valid;
    logic        tx_row_ready;
    logic        tx_row_start;
    logic [9:0]  tx_row_row_id;
    logic [31:0] tx_row_data;

    logic        rx_overflow;
    logic        row_tx_done;

    row_pingpong_buffer dut (
        .clk(clk),
        .rst(rst),

        .rx_batch_start(rx_batch_start),
        .rx_batch_row_id(rx_batch_row_id),
        .rx_batch_id(rx_batch_id),
        .rx_sample_valid(rx_sample_valid),
        .rx_sample_data(rx_sample_data),
        .rx_sample_last(rx_sample_last),
        .rx_sample_ready(rx_sample_ready),

        .dsp_in_valid(dsp_in_valid),
        .dsp_in_row_start(dsp_in_row_start),
        .dsp_in_data(dsp_in_data),

        .dsp_out_valid(dsp_out_valid),
        .dsp_out_data(dsp_out_data),

        .tx_row_valid(tx_row_valid),
        .tx_row_ready(tx_row_ready),
        .tx_row_start(tx_row_start),
        .tx_row_row_id(tx_row_row_id),
        .tx_row_data(tx_row_data),

        .rx_overflow(rx_overflow),
        .row_tx_done(row_tx_done)
    );

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam int RAW_ROW_SAMPLES  = 1024;
    localparam int PROC_ROW_SAMPLES = 512;
    localparam int BATCH_SAMPLES    = 256;

    // -------------------------------------------------------------------------
    // DSP model:
    // - consumes all 1024 real inputs
    // - produces 512 real outputs
    // - output[i] = input[i] + 1
    // - fixed 2-cycle latency from accepted DSP input sample to output sample
    // - only first 512 DSP inputs produce outputs
    // -------------------------------------------------------------------------
    logic [31:0] p0_data, p1_data;
    logic        p0_valid, p1_valid;

    int dsp_model_in_count;

    always @(posedge clk) begin
        if (rst) begin
            p0_data            <= 32'd0;
            p1_data            <= 32'd0;
            p0_valid           <= 1'b0;
            p1_valid           <= 1'b0;
            dsp_out_valid      <= 1'b0;
            dsp_out_data       <= 32'd0;
            dsp_model_in_count <= 0;
        end
        else begin
            p0_valid <= 1'b0;
            if (dsp_in_valid) begin
                if (dsp_model_in_count < PROC_ROW_SAMPLES) begin
                    p0_valid <= 1'b1;
                    p0_data  <= dsp_in_data + 32'd1;
                end
                dsp_model_in_count <= dsp_model_in_count + 1;
            end

            p1_valid      <= p0_valid;
            p1_data       <= p0_data;
            dsp_out_valid <= p1_valid;
            dsp_out_data  <= p1_data;
        end
    end

    // -------------------------------------------------------------------------
    // Scoreboard
    // -------------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    task expect_local(input logic cond, input string msg);
    begin
        if (cond) begin
            pass_count++;
        end
        else begin
            $display("FAIL: %s", msg);
            fail_count++;
        end
    end
    endtask

    function automatic [31:0] exp_raw(input [9:0] row_id, input integer idx);
    begin
        exp_raw = row_id * 32'd10000 + idx;
    end
    endfunction

    function automatic [31:0] exp_tx(input [9:0] row_id, input integer idx);
    begin
        exp_tx = exp_raw(row_id, idx) + 32'd1;
    end
    endfunction

    // -------------------------------------------------------------------------
    // Capture
    // -------------------------------------------------------------------------
    logic [31:0] dsp_cap_data  [0:RAW_ROW_SAMPLES-1];
    logic        dsp_cap_start [0:RAW_ROW_SAMPLES-1];

    logic [31:0] tx_cap_data   [0:PROC_ROW_SAMPLES-1];
    logic        tx_cap_start  [0:PROC_ROW_SAMPLES-1];
    logic [9:0]  tx_cap_row    [0:PROC_ROW_SAMPLES-1];

    integer dsp_count;
    integer tx_count;
    integer dsp_row_start_count;
    integer tx_row_start_count;
    integer overflow_count;
    integer row_done_count;

    task clear_caps;
        integer i;
    begin
        dsp_count = 0;
        tx_count = 0;
        dsp_row_start_count = 0;
        tx_row_start_count = 0;
        overflow_count = 0;
        row_done_count = 0;
        dsp_model_in_count = 0;

        for (i = 0; i < RAW_ROW_SAMPLES; i = i + 1) begin
            dsp_cap_data[i] = 32'd0;
            dsp_cap_start[i] = 1'b0;
        end

        for (i = 0; i < PROC_ROW_SAMPLES; i = i + 1) begin
            tx_cap_data[i] = 32'd0;
            tx_cap_start[i] = 1'b0;
            tx_cap_row[i] = 10'd0;
        end
    end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            clear_caps();
        end
        else begin
            if (dsp_in_valid) begin
                if (dsp_count < RAW_ROW_SAMPLES) begin
                    dsp_cap_data[dsp_count]  <= dsp_in_data;
                    dsp_cap_start[dsp_count] <= dsp_in_row_start;
                end
                if (dsp_in_row_start)
                    dsp_row_start_count <= dsp_row_start_count + 1;
                dsp_count <= dsp_count + 1;
            end

            if (tx_row_valid && tx_row_ready) begin
                if (tx_count < PROC_ROW_SAMPLES) begin
                    tx_cap_data[tx_count]  <= tx_row_data;
                    tx_cap_start[tx_count] <= tx_row_start;
                    tx_cap_row[tx_count]   <= tx_row_row_id;
                end
                if (tx_row_start)
                    tx_row_start_count <= tx_row_start_count + 1;
                tx_count <= tx_count + 1;
            end

            if (rx_overflow)
                overflow_count <= overflow_count + 1;

            if (row_tx_done)
                row_done_count <= row_done_count + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Stimulus helpers
    // -------------------------------------------------------------------------
    task idle_cycles(input integer n);
        integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk);
            rx_batch_start  <= 0;
            rx_batch_row_id <= 0;
            rx_batch_id     <= 0;
            rx_sample_valid <= 0;
            rx_sample_data  <= 0;
            rx_sample_last  <= 0;
        end
    end
    endtask

    task send_batch(input [9:0] row_id, input [1:0] batch_id_val);
        integer i;
        integer global_idx;
    begin
        for (i = 0; i < BATCH_SAMPLES; i = i + 1) begin
            global_idx = batch_id_val * BATCH_SAMPLES + i;
            @(posedge clk);
            rx_batch_start  <= (i == 0);
            rx_batch_row_id <= row_id;
            rx_batch_id     <= batch_id_val;
            rx_sample_valid <= 1;
            rx_sample_data  <= exp_raw(row_id, global_idx);
            rx_sample_last  <= (i == (BATCH_SAMPLES-1));
        end

        @(posedge clk);
        rx_batch_start  <= 0;
        rx_batch_row_id <= 0;
        rx_batch_id     <= 0;
        rx_sample_valid <= 0;
        rx_sample_data  <= 0;
        rx_sample_last  <= 0;
    end
    endtask

    task wait_for_done(input integer wanted_done_count, input integer timeout_cycles, output logic ok);
        integer i;
    begin
        ok = 0;
        for (i = 0; i < timeout_cycles; i = i + 1) begin
            @(posedge clk);
            if (row_done_count >= wanted_done_count) begin
                ok = 1;
                i = timeout_cycles;
            end
        end
    end
    endtask

    task check_dsp_sequence(input [9:0] row_id);
        integer i;
    begin
        expect_local(dsp_count == RAW_ROW_SAMPLES, "DSP saw 1024 samples");
        expect_local(dsp_row_start_count == 1, "DSP row_start once");

        if (dsp_count >= RAW_ROW_SAMPLES) begin
            for (i = 0; i < RAW_ROW_SAMPLES; i = i + 1) begin
                expect_local(dsp_cap_data[i] == exp_raw(row_id, i), $sformatf("DSP data[%0d]", i));
                expect_local(dsp_cap_start[i] == (i == 0), $sformatf("DSP start[%0d]", i));
            end
        end
    end
    endtask

    task check_tx_sequence(input [9:0] row_id);
        integer i;
    begin
        expect_local(tx_count == PROC_ROW_SAMPLES, "TX saw 512 samples");
        expect_local(tx_row_start_count == 1, "TX row_start once");

        if (tx_count >= PROC_ROW_SAMPLES) begin
            for (i = 0; i < PROC_ROW_SAMPLES; i = i + 1) begin
                expect_local(tx_cap_data[i] == exp_tx(row_id, i), $sformatf("TX data[%0d]", i));
                expect_local(tx_cap_row[i]  == row_id,         $sformatf("TX row_id[%0d]", i));
                expect_local(tx_cap_start[i] == (i == 0),      $sformatf("TX start[%0d]", i));
            end
        end
    end
    endtask

    task print_summary(input string label);
    begin
        $display("SUMMARY %s:", label);
        $display("  dsp_count            = %0d", dsp_count);
        $display("  dsp_row_start_count  = %0d", dsp_row_start_count);
        $display("  tx_count             = %0d", tx_count);
        $display("  tx_row_start_count   = %0d", tx_row_start_count);
        $display("  overflow_count       = %0d", overflow_count);
        $display("  row_done_count       = %0d", row_done_count);
    end
    endtask

    logic ok;

    initial begin
        rx_batch_start  = 0;
        rx_batch_row_id = 0;
        rx_batch_id     = 0;
        rx_sample_valid = 0;
        rx_sample_data  = 0;
        rx_sample_last  = 0;
        tx_row_ready    = 1;

        repeat (10) @(posedge clk);
        rst = 0;

        // =====================================================================
        // TEST1: basic row reassembly / DSP / TX
        // =====================================================================
        $display("============================================================");
        $display("TEST1: basic row reassembly / DSP / TX");
        $display("============================================================");
        clear_caps();

        send_batch(10'd5, 2'd2);
        send_batch(10'd5, 2'd0);
        send_batch(10'd5, 2'd3);
        send_batch(10'd5, 2'd1);

        wait_for_done(1, 50000, ok);

        print_summary("TEST1");
        expect_local(ok, "row 5 transmitted");
        expect_local(overflow_count == 0, "no overflow TEST1");
        expect_local(row_done_count == 1, "row_done TEST1");
        check_dsp_sequence(10'd5);
        check_tx_sequence(10'd5);

        // =====================================================================
        // TEST2: TX backpressure
        // =====================================================================
        $display("============================================================");
        $display("TEST2: TX backpressure");
        $display("============================================================");
        clear_caps();

        fork
            begin
                send_batch(10'd9, 2'd0);
                send_batch(10'd9, 2'd1);
                send_batch(10'd9, 2'd2);
                send_batch(10'd9, 2'd3);
            end
            begin
                tx_row_ready <= 1;
                repeat (1200) @(posedge clk);
                repeat (8000) begin
                    @(posedge clk);
                    tx_row_ready <= $urandom_range(0,1);
                    if (row_done_count >= 1)
                        disable bp_loop;
                end
                begin : bp_loop end
                tx_row_ready <= 1;
            end
        join

        wait_for_done(1, 60000, ok);
        print_summary("TEST2");
        expect_local(ok, "row 9 under backpressure");
        expect_local(overflow_count == 0, "no overflow TEST2");
        check_tx_sequence(10'd9);
        tx_row_ready <= 1;

        // =====================================================================
        // TEST3: same-row slot reuse
        // =====================================================================
        $display("============================================================");
        $display("TEST3: same-row slot reuse");
        $display("============================================================");
        clear_caps();

        send_batch(10'd12, 2'd0);
        idle_cycles(3);
        send_batch(10'd12, 2'd2);
        idle_cycles(3);
        send_batch(10'd12, 2'd1);
        idle_cycles(3);
        send_batch(10'd12, 2'd3);

        wait_for_done(1, 50000, ok);
        expect_local(ok, "row 12 transmitted");
        expect_local(overflow_count == 0, "same-row reuse no overflow");
        check_tx_sequence(10'd12);

        // =====================================================================
        // TEST4: overflow on third partial row
        // =====================================================================
        $display("============================================================");
        $display("TEST4: overflow on third partial row");
        $display("============================================================");
        clear_caps();

        send_batch(10'd20, 2'd0);
        idle_cycles(2);
        send_batch(10'd21, 2'd0);
        idle_cycles(2);
        send_batch(10'd22, 2'd0);
        idle_cycles(20);

        expect_local(overflow_count > 0, "overflow detected");

        // =====================================================================
        // TEST5: reset recovery
        // =====================================================================
        $display("============================================================");
        $display("TEST5: reset recovery");
        $display("============================================================");
        clear_caps();

        @(posedge clk); rst <= 1;
        @(posedge clk); @(posedge clk); rst <= 0;

        send_batch(10'd7, 2'd0);
        send_batch(10'd7, 2'd1);
        send_batch(10'd7, 2'd2);
        send_batch(10'd7, 2'd3);

        wait_for_done(1, 50000, ok);
        expect_local(ok, "row 7 after reset");
        expect_local(overflow_count == 0, "no overflow TEST5");
        check_tx_sequence(10'd7);

        // =====================================================================
        // TEST6: two sequential rows
        // =====================================================================
        $display("============================================================");
        $display("TEST6: two sequential rows");
        $display("============================================================");
        clear_caps();

        send_batch(10'd30, 2'd0);
        send_batch(10'd30, 2'd1);
        send_batch(10'd30, 2'd2);
        send_batch(10'd30, 2'd3);
        wait_for_done(1, 50000, ok);
        expect_local(ok, "row 30 done");
        check_tx_sequence(10'd30);

        clear_caps();

        send_batch(10'd31, 2'd0);
        send_batch(10'd31, 2'd1);
        send_batch(10'd31, 2'd2);
        send_batch(10'd31, 2'd3);
        wait_for_done(1, 50000, ok);
        expect_local(ok, "row 31 done");
        check_tx_sequence(10'd31);

        $display("============================================================");
        $display("FINAL SUMMARY");
        $display("============================================================");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
