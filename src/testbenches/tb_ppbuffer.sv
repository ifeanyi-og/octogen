
`timescale 1ns/1ps

module tb_ppbuffer;

    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    integer cycle_count = 0;
    always @(posedge clk) begin
        if (!rst) cycle_count <= cycle_count + 1;
    end

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // DSP model: fixed 2-cycle latency
    // -------------------------------------------------------------------------
    logic [31:0] re0, re1, im0, im1;
    logic        v0, v1;

    always @(posedge clk) begin
        if (rst) begin
            re0 <= 0; re1 <= 0; im0 <= 0; im1 <= 0; v0 <= 0; v1 <= 0;
            dsp_out_valid <= 0; dsp_out_re <= 0; dsp_out_im <= 0;
        end
        else begin
            v0  <= dsp_in_valid;
            re0 <= dsp_in_re + 32'd1;
            im0 <= dsp_in_im + 32'd2;
            v1  <= v0;
            re1 <= re0;
            im1 <= im0;
            dsp_out_valid <= v1;
            dsp_out_re    <= re1;
            dsp_out_im    <= im1;
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
            //display("PASS: %s", msg);
            pass_count++;
        end
        else begin
            $display("FAIL: %s", msg);
            fail_count++;
        end
    end
    endtask

    function automatic [31:0] exp_re(input [9:0] row_id, input integer idx);
    begin
        exp_re = row_id * 32'd10000 + idx;
    end
    endfunction

    function automatic [31:0] exp_im(input [9:0] row_id, input integer idx);
    begin
        exp_im = 32'h8000_0000 + row_id * 32'd10000 + idx;
    end
    endfunction

    // -------------------------------------------------------------------------
    // Capture
    // -------------------------------------------------------------------------
    logic [31:0] dsp_cap_re [0:511];
    logic [31:0] dsp_cap_im [0:511];
    logic        dsp_cap_start [0:511];

    logic [31:0] tx_cap_re [0:511];
    logic [31:0] tx_cap_im [0:511];
    logic        tx_cap_start [0:511];
    logic [9:0]  tx_cap_row [0:511];

    integer dsp_count;
    integer tx_count;
    integer dsp_row_start_count;
    integer tx_row_start_count;
    integer overflow_count;
    integer row_done_count;

    bit debug_test1_raw_tail_enable;

    task clear_caps;
        integer i;
    begin
        dsp_count = 0;
        tx_count = 0;
        dsp_row_start_count = 0;
        tx_row_start_count = 0;
        overflow_count = 0;
        row_done_count = 0;
        for (i = 0; i < 512; i = i + 1) begin
            dsp_cap_re[i] = 0;
            dsp_cap_im[i] = 0;
            dsp_cap_start[i] = 0;
            tx_cap_re[i] = 0;
            tx_cap_im[i] = 0;
            tx_cap_start[i] = 0;
            tx_cap_row[i] = 0;
        end
    end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            clear_caps();
        end
        else begin
            if (dsp_in_valid) begin
                if (dsp_count < 512) begin
                    dsp_cap_re[dsp_count]    <= dsp_in_re;
                    dsp_cap_im[dsp_count]    <= dsp_in_im;
                    dsp_cap_start[dsp_count] <= dsp_in_row_start;
                end
                if (dsp_in_row_start) dsp_row_start_count <= dsp_row_start_count + 1;
                dsp_count <= dsp_count + 1;
            end

            if (tx_row_valid && tx_row_ready) begin
                if (tx_count < 512) begin
                    tx_cap_re[tx_count]    <= tx_row_re;
                    tx_cap_im[tx_count]    <= tx_row_im;
                    tx_cap_start[tx_count] <= tx_row_start;
                    tx_cap_row[tx_count]   <= tx_row_row_id;
                end
                if (tx_row_start) tx_row_start_count <= tx_row_start_count + 1;
                tx_count <= tx_count + 1;
            end

            if (rx_overflow) overflow_count <= overflow_count + 1;
            if (row_tx_done) row_done_count <= row_done_count + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Raw-tail-only debug for DSP-side final-sample duplication
    // Focus only on raw read issue / raw dout / DSP input for 508..511.
    // -------------------------------------------------------------------------
    logic [63:0] prev_raw0_doutb, prev_raw1_doutb;
    logic prev_raw0_enb, prev_raw1_enb;

    always @(posedge clk) begin
        if (rst) begin
            prev_raw0_doutb <= 64'd0;
            prev_raw1_doutb <= 64'd0;
            prev_raw0_enb   <= 1'b0;
            prev_raw1_enb   <= 1'b0;
        end
        else if (debug_test1_raw_tail_enable) begin
            // 1) raw read requests near the tail
            if ((dut.raw0_enb && (dut.raw0_addrb >= 9'd508)) ||
                (dut.raw1_enb && (dut.raw1_addrb >= 9'd508))) begin
                $display("RAWTAIL C=%0d RAW_RD_ISSUE slot=%0b addr=%0d | raw0_enb=%0b raw0_addr=%0d | raw1_enb=%0b raw1_addr=%0d",
                         cycle_count,
                         dut.raw1_enb ? 1'b1 : 1'b0,
                         dut.raw1_enb ? dut.raw1_addrb : dut.raw0_addrb,
                         dut.raw0_enb, dut.raw0_addrb,
                         dut.raw1_enb, dut.raw1_addrb);
            end

            // 2) tail metadata pipeline state when near the end
            if ((dut.dsp_issue_idx >= 10'd508) ||
                dut.dsp_rd_v[0] || dut.dsp_rd_v[1] || dut.dsp_rd_v[2] ||
                dut.dsp_data_v ||
                (dsp_count >= 508)) begin
                $display("RAWTAIL C=%0d DSP_PIPE issue_idx=%0d write_idx=%0d | rdv={%0b,%0b,%0b} slot={%0b,%0b,%0b} start={%0b,%0b,%0b} | dsp_data_v=%0b dsp_data_slot=%0b dsp_data_start=%0b",
                         cycle_count,
                         dut.dsp_issue_idx, dut.dsp_write_idx,
                         dut.dsp_rd_v[0], dut.dsp_rd_v[1], dut.dsp_rd_v[2],
                         dut.dsp_rd_slot[0], dut.dsp_rd_slot[1], dut.dsp_rd_slot[2],
                         dut.dsp_rd_start[0], dut.dsp_rd_start[1], dut.dsp_rd_start[2],
                         dut.dsp_data_v, dut.dsp_data_slot, dut.dsp_data_start);
            end

            // 3) raw dout changes near tail
            if ((((dut.raw0_doutb !== prev_raw0_doutb) || (dut.raw0_enb !== prev_raw0_enb)) &&
                 (dut.raw0_addrb >= 9'd508)) ||
                (((dut.raw1_doutb !== prev_raw1_doutb) || (dut.raw1_enb !== prev_raw1_enb)) &&
                 (dut.raw1_addrb >= 9'd508))) begin
                $display("RAWTAIL C=%0d RAW_MEM raw0_enb=%0b raw0_addr=%0d raw0_dout=%016h | raw1_enb=%0b raw1_addr=%0d raw1_dout=%016h",
                         cycle_count,
                         dut.raw0_enb, dut.raw0_addrb, dut.raw0_doutb,
                         dut.raw1_enb, dut.raw1_addrb, dut.raw1_doutb);
            end

            // 4) actual DSP inputs at the tail
            if (dsp_in_valid && (dsp_count >= 508)) begin
                $display("RAWTAIL C=%0d DSP_IN idx=%0d start=%0b re=%08h im=%08h",
                         cycle_count, dsp_count, dsp_in_row_start, dsp_in_re, dsp_in_im);
            end

            // 5) final DSP outputs / proc writes to correlate with the tail input
            if (dsp_out_valid && (dut.dsp_write_idx >= 508)) begin
                $display("RAWTAIL C=%0d DSP_OUT write_idx=%0d re=%08h im=%08h",
                         cycle_count, dut.dsp_write_idx, dsp_out_re, dsp_out_im);
            end

            if (dut.proc_wr_pending && (dut.proc_wr_addr >= 9'd508)) begin
                $display("RAWTAIL C=%0d PROC_WR addr=%0d data=%016h last=%0b slot=%0b",
                         cycle_count, dut.proc_wr_addr, dut.proc_wr_data, dut.proc_wr_last, dut.proc_wr_slot);
            end

            prev_raw0_doutb <= dut.raw0_doutb;
            prev_raw1_doutb <= dut.raw1_doutb;
            prev_raw0_enb   <= dut.raw0_enb;
            prev_raw1_enb   <= dut.raw1_enb;
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
            rx_sample_re    <= 0;
            rx_sample_im    <= 0;
            rx_sample_last  <= 0;
        end
    end
    endtask

    task send_batch(input [9:0] row_id, input [1:0] batch_id_val);
        integer i;
        integer global_idx;
    begin
        for (i = 0; i < 128; i = i + 1) begin
            global_idx = batch_id_val * 128 + i;
            @(posedge clk);
            rx_batch_start  <= (i == 0);
            rx_batch_row_id <= row_id;
            rx_batch_id     <= batch_id_val;
            rx_sample_valid <= 1;
            rx_sample_re    <= exp_re(row_id, global_idx);
            rx_sample_im    <= exp_im(row_id, global_idx);
            rx_sample_last  <= (i == 127);
        end
        @(posedge clk);
        rx_batch_start  <= 0;
        rx_batch_row_id <= 0;
        rx_batch_id     <= 0;
        rx_sample_valid <= 0;
        rx_sample_re    <= 0;
        rx_sample_im    <= 0;
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
                disable wf_loop;
            end
        end
        begin : wf_loop end
    end
    endtask

    task check_dsp_sequence(input [9:0] row_id);
        integer i;
    begin
        expect_local(dsp_count == 512, "DSP saw 512 samples");
        expect_local(dsp_row_start_count == 1, "DSP row_start once");
        if (dsp_count >= 512) begin
            for (i = 0; i < 512; i = i + 1) begin
                expect_local(dsp_cap_re[i] == exp_re(row_id, i), $sformatf("DSP re[%0d]", i));
                expect_local(dsp_cap_im[i] == exp_im(row_id, i), $sformatf("DSP im[%0d]", i));
                expect_local(dsp_cap_start[i] == (i == 0), $sformatf("DSP start[%0d]", i));
            end
        end
    end
    endtask

    task check_tx_sequence(input [9:0] row_id);
        integer i;
    begin
        expect_local(tx_count == 512, "TX saw 512 samples");
        expect_local(tx_row_start_count == 1, "TX row_start once");
        if (tx_count >= 512) begin
            for (i = 0; i < 512; i = i + 1) begin
                expect_local(tx_cap_re[i] == exp_re(row_id, i) + 32'd1, $sformatf("TX re[%0d]", i));
                expect_local(tx_cap_im[i] == exp_im(row_id, i) + 32'd2, $sformatf("TX im[%0d]", i));
                expect_local(tx_cap_row[i] == row_id, $sformatf("TX row_id[%0d]", i));
                expect_local(tx_cap_start[i] == (i == 0), $sformatf("TX start[%0d]", i));
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
        rx_batch_start           = 0;
        rx_batch_row_id          = 0;
        rx_batch_id              = 0;
        rx_sample_valid          = 0;
        rx_sample_re             = 0;
        rx_sample_im             = 0;
        rx_sample_last           = 0;
        tx_row_ready             = 1;
        debug_test1_raw_tail_enable = 0;

        repeat (10) @(posedge clk);
        rst = 0;

        // =====================================================================
        // TEST1: basic row reassembly / DSP / TX
        // raw-tail-only localization for idx/address 511 bug
        // =====================================================================
        $display("============================================================");
        $display("TEST1: basic row reassembly / DSP / TX");
        $display("============================================================");
        clear_caps();
        debug_test1_raw_tail_enable = 1;

        send_batch(10'd5, 2'd2);
        send_batch(10'd5, 2'd0);
        send_batch(10'd5, 2'd3);
        send_batch(10'd5, 2'd1);

        wait_for_done(1, 30000, ok);
        debug_test1_raw_tail_enable = 0;

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
                repeat (500) @(posedge clk);
                repeat (5000) begin
                    @(posedge clk);
                    tx_row_ready <= $urandom_range(0,1);
                    if (row_done_count >= 1)
                        disable bp_loop;
                end
                begin : bp_loop end
                tx_row_ready <= 1;
            end
        join
        wait_for_done(1, 40000, ok);
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
        wait_for_done(1, 30000, ok);
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
        wait_for_done(1, 30000, ok);
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
        wait_for_done(1, 30000, ok);
        expect_local(ok, "row 30 done");
        check_tx_sequence(10'd30);

        clear_caps();
        send_batch(10'd31, 2'd0);
        send_batch(10'd31, 2'd1);
        send_batch(10'd31, 2'd2);
        send_batch(10'd31, 2'd3);
        wait_for_done(1, 30000, ok);
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