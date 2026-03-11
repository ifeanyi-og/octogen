
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
            $display("PASS: %s", msg);
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

    bit debug_test1_enable;

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
    // TEST1 DEBUG LOGGING
    // -------------------------------------------------------------------------
    
     // -------------------------------------------------------------------------
    // TEST1 DEBUG LOGGING
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst && debug_test1_enable) begin
    
            // ================================================================
            // RX: batch boundaries, slot selection, slot state
            // ================================================================
            if (rx_sample_valid && (rx_batch_start || rx_sample_last || rx_overflow)) begin
                $display("DBG C=%0d RX: batch_start=%0b row=%0d batch=%0d last=%0b re=%08h im=%08h | ready=%0b",
                         cycle_count,
                         rx_batch_start, rx_batch_row_id, rx_batch_id, rx_sample_last,
                         rx_sample_re, rx_sample_im, rx_sample_ready);
    
                $display("DBG C=%0d RX_CTRL: target_found=%0b target_slot=%0b rx_active=%0b rx_drop=%0b rx_slot_sel=%0b rx_addr=%0d batch_id_reg=%0d overflow=%0b",
                         cycle_count,
                         dut.rx_target_found, dut.rx_target_slot,
                         dut.rx_active, dut.rx_drop, dut.rx_slot_sel,
                         dut.rx_addr, dut.rx_batch_id_reg, rx_overflow);
    
                $display("DBG C=%0d SLOT: v0=%0b row0=%0d mask0=%b raw0=%0b proc0=%0b busy_dsp0=%0b busy_tx0=%0b | v1=%0b row1=%0d mask1=%b raw1=%0b proc1=%0b busy_dsp1=%0b busy_tx1=%0b",
                         cycle_count,
                         dut.slot_valid0, dut.slot_row_id0, dut.slot_batch_mask0, dut.slot_raw_ready0, dut.slot_proc_ready0, dut.slot_busy_dsp0, dut.slot_busy_tx0,
                         dut.slot_valid1, dut.slot_row_id1, dut.slot_batch_mask1, dut.slot_raw_ready1, dut.slot_proc_ready1, dut.slot_busy_dsp1, dut.slot_busy_tx1);
            end
    
            // ================================================================
            // DSP raw-memory read pipeline and DSP input stream
            // ================================================================
            if (dut.dsp_active ||
                dut.dsp_rd_v[0] || dut.dsp_rd_v[1] || dut.dsp_rd_v[2] ||
                dsp_in_valid || dsp_out_valid) begin
    
                if ((dut.dsp_issue_idx < 10'd8) ||
                    (dut.dsp_issue_idx >= 10'd255 && dut.dsp_issue_idx <= 10'd257) ||
                    (dut.dsp_issue_idx >= 10'd509) ||
                    dsp_in_valid || dsp_out_valid) begin
    
                    $display("DBG C=%0d DSP_CTRL: active=%0b slot=%0b issue_idx=%0d write_idx=%0d | p0v=%0b p0slot=%0b p0start=%0b | p1v=%0b p1slot=%0b p1start=%0b | p2v=%0b p2slot=%0b p2start=%0b",
                             cycle_count,
                             dut.dsp_active, dut.dsp_slot_sel, dut.dsp_issue_idx, dut.dsp_write_idx,
                             dut.dsp_rd_v[0], dut.dsp_rd_slot[0], dut.dsp_rd_start[0],
                             dut.dsp_rd_v[1], dut.dsp_rd_slot[1], dut.dsp_rd_start[1],
                             dut.dsp_rd_v[2], dut.dsp_rd_slot[2], dut.dsp_rd_start[2]);
    
                    $display("DBG C=%0d DSP_MEM: raw0_enb=%0b raw0_addrb=%0d raw0_doutb=%016h | raw1_enb=%0b raw1_addrb=%0d raw1_doutb=%016h",
                             cycle_count,
                             dut.raw0_enb, dut.raw0_addrb, dut.raw0_doutb,
                             dut.raw1_enb, dut.raw1_addrb, dut.raw1_doutb);
    
                    if (dsp_in_valid) begin
                        $display("DBG C=%0d DSP_IN : count=%0d start=%0b re=%08h im=%08h",
                                 cycle_count, dsp_count, dsp_in_row_start, dsp_in_re, dsp_in_im);
                    end
                end
            end
    
            // ================================================================
            // DSP output write into processed memory
            // ================================================================
            if (dsp_out_valid) begin
                $display("DBG C=%0d DSP_WR : write_idx=%0d | dsp_out_re=%08h dsp_out_im=%08h | proc0_ena=%0b proc0_wea=%0b proc0_addra=%0d proc0_dina=%016h | proc1_ena=%0b proc1_wea=%0b proc1_addra=%0d proc1_dina=%016h",
                         cycle_count,
                         dut.dsp_write_idx,
                         dsp_out_re, dsp_out_im,
                         dut.proc0_ena, dut.proc0_wea, dut.proc0_addra, dut.proc0_dina,
                         dut.proc1_ena, dut.proc1_wea, dut.proc1_addra, dut.proc1_dina);
    
                $display("DBG C=%0d DSP_OUT: re=%08h im=%08h",
                         cycle_count, dsp_out_re, dsp_out_im);
            end
    
            // ================================================================
            // TX processed-memory read pipeline
            // ================================================================
            if (dut.tx_active ||
                dut.tx_rd_v[0] || dut.tx_rd_v[1] || dut.tx_rd_v[2] ||
                dut.tx_cap_valid ||
                tx_row_valid || row_tx_done) begin
    
                if ((dut.tx_issue_idx < 10'd8) ||
                    (dut.tx_issue_idx >= 10'd255 && dut.tx_issue_idx <= 10'd257) ||
                    (dut.tx_issue_idx >= 10'd509) ||
                    dut.tx_cap_valid ||
                    tx_row_valid || row_tx_done) begin
    
                    $display("DBG C=%0d TX_RD : issue_idx=%0d | p0v=%0b p0slot=%0b p0start=%0b p0last=%0b | p1v=%0b p1slot=%0b p1start=%0b p1last=%0b | p2v=%0b p2slot=%0b p2start=%0b p2last=%0b",
                             cycle_count,
                             dut.tx_issue_idx,
                             dut.tx_rd_v[0], dut.tx_rd_slot[0], dut.tx_rd_start[0], dut.tx_rd_last[0],
                             dut.tx_rd_v[1], dut.tx_rd_slot[1], dut.tx_rd_start[1], dut.tx_rd_last[1],
                             dut.tx_rd_v[2], dut.tx_rd_slot[2], dut.tx_rd_start[2], dut.tx_rd_last[2]);
    
                    $display("DBG C=%0d TX_CAP: valid=%0b slot=%0b start=%0b last=%0b data=%016h",
                             cycle_count,
                             dut.tx_cap_valid, dut.tx_cap_slot, dut.tx_cap_start, dut.tx_cap_last, dut.tx_cap_data);
    
                    $display("DBG C=%0d TX_MEM: proc0_enb=%0b proc0_addrb=%0d proc0_doutb=%016h | proc1_enb=%0b proc1_addrb=%0d proc1_doutb=%016h",
                             cycle_count,
                             dut.proc0_enb, dut.proc0_addrb, dut.proc0_doutb,
                             dut.proc1_enb, dut.proc1_addrb, dut.proc1_doutb);
                end
            end
    
            // ================================================================
            // TX held beat and actual output handshake
            // ================================================================
            if (tx_row_valid || dut.tx_valid_reg || row_tx_done) begin
                $display("DBG C=%0d TX_HOLD: valid_reg=%0b start_reg=%0b last_reg=%0b row_id_reg=%0d re_reg=%08h im_reg=%08h accept=%0b ready=%0b",
                         cycle_count,
                         dut.tx_valid_reg, dut.tx_start_reg, dut.tx_last_reg,
                         dut.tx_row_id_reg, dut.tx_re_reg, dut.tx_im_reg,
                         dut.tx_accept, tx_row_ready);
    
                if (tx_row_valid && tx_row_ready) begin
                    $display("DBG C=%0d TX_OUT : count=%0d start=%0b row=%0d re=%08h im=%08h",
                             cycle_count, tx_count, tx_row_start, tx_row_row_id, tx_row_re, tx_row_im);
                end
    
                if (row_tx_done) begin
                    $display("DBG C=%0d TX_DONE", cycle_count);
                end
            end
        end
    end
 
 
    /* 
    always @(posedge clk) begin
        if (!rst && debug_test1_enable) begin

            // RX batch boundary and slot-selection relevant signals
            if (rx_sample_valid && (rx_batch_start || rx_sample_last || rx_overflow)) begin
                $display("DBG C=%0d RX: batch_start=%0b row=%0d batch=%0d last=%0b re=%08h im=%08h | ready=%0b",
                         cycle_count,
                         rx_batch_start, rx_batch_row_id, rx_batch_id, rx_sample_last,
                         rx_sample_re, rx_sample_im, rx_sample_ready);

                $display("DBG C=%0d RX_CTRL: target_found=%0b target_slot=%0b rx_active=%0b rx_drop=%0b rx_slot_sel=%0b rx_addr=%0d batch_id_reg=%0d overflow=%0b",
                         cycle_count,
                         dut.rx_target_found, dut.rx_target_slot,
                         dut.rx_active, dut.rx_drop, dut.rx_slot_sel,
                         dut.rx_addr, dut.rx_batch_id_reg, rx_overflow);

                $display("DBG C=%0d SLOT: v0=%0b row0=%0d mask0=%b raw0=%0b proc0=%0b busy_dsp0=%0b busy_tx0=%0b | v1=%0b row1=%0d mask1=%b raw1=%0b proc1=%0b busy_dsp1=%0b busy_tx1=%0b",
                         cycle_count,
                         dut.slot_valid0, dut.slot_row_id0, dut.slot_batch_mask0, dut.slot_raw_ready0, dut.slot_proc_ready0, dut.slot_busy_dsp0, dut.slot_busy_tx0,
                         dut.slot_valid1, dut.slot_row_id1, dut.slot_batch_mask1, dut.slot_raw_ready1, dut.slot_proc_ready1, dut.slot_busy_dsp1, dut.slot_busy_tx1);
            end

            // DSP launch / read pipeline / endpoints
            if (dut.dsp_active ||
                dut.dsp_rd_p1_valid || dut.dsp_rd_p2_valid ||
                dsp_in_valid || dsp_out_valid) begin

                if ((dut.dsp_issue_idx < 8) ||
                    (dut.dsp_issue_idx >= 10'd255 && dut.dsp_issue_idx <= 10'd257) ||
                    (dut.dsp_issue_idx >= 10'd509) ||
                    dsp_in_valid || dsp_out_valid) begin

                    $display("DBG C=%0d DSP_CTRL: active=%0b slot=%0b issue_idx=%0d out_idx=%0d | p1v=%0b p1slot=%0b p1start=%0b | p2v=%0b p2slot=%0b p2start=%0b",
                             cycle_count,
                             dut.dsp_active, dut.dsp_slot_sel, dut.dsp_issue_idx, dut.dsp_out_idx,
                             dut.dsp_rd_p1_valid, dut.dsp_rd_p1_slot, dut.dsp_rd_p1_start,
                             dut.dsp_rd_p2_valid, dut.dsp_rd_p2_slot, dut.dsp_rd_p2_start);

                    $display("DBG C=%0d DSP_MEM: raw0_enb=%0b raw0_addrb=%0d raw0_doutb=%016h | raw1_enb=%0b raw1_addrb=%0d raw1_doutb=%016h",
                             cycle_count,
                             dut.raw0_enb, dut.raw0_addrb, dut.raw0_doutb,
                             dut.raw1_enb, dut.raw1_addrb, dut.raw1_doutb);

                    if (dsp_in_valid) begin
                        $display("DBG C=%0d DSP_IN : count=%0d start=%0b re=%08h im=%08h",
                                 cycle_count, dsp_count, dsp_in_row_start, dsp_in_re, dsp_in_im);
                    end

                    if (dsp_out_valid) begin
                        $display("DBG C=%0d DSP_OUT: re=%08h im=%08h",
                                 cycle_count, dsp_out_re, dsp_out_im);
                    end
                end
            end

            // TX launch / read pipeline / handshakes
            if (dut.tx_active ||
                dut.tx_rd_p1_valid || dut.tx_rd_p2_valid ||
                tx_row_valid || row_tx_done) begin

                if ((dut.tx_issue_idx < 8) ||
                    (dut.tx_issue_idx >= 10'd255 && dut.tx_issue_idx <= 10'd257) ||
                    (dut.tx_issue_idx >= 10'd509) ||
                    tx_row_valid || row_tx_done) begin

                    $display("DBG C=%0d TX_CTRL: active=%0b slot=%0b issue_idx=%0d | p1v=%0b p1slot=%0b p1start=%0b p1last=%0b | p2v=%0b p2slot=%0b p2start=%0b p2last=%0b",
                             cycle_count,
                             dut.tx_active, dut.tx_slot_sel, dut.tx_issue_idx,
                             dut.tx_rd_p1_valid, dut.tx_rd_p1_slot, dut.tx_rd_p1_start, dut.tx_rd_p1_last,
                             dut.tx_rd_p2_valid, dut.tx_rd_p2_slot, dut.tx_rd_p2_start, dut.tx_rd_p2_last);

                    $display("DBG C=%0d TX_HOLD: valid_reg=%0b start_reg=%0b last_reg=%0b row_id_reg=%0d re_reg=%08h im_reg=%08h accept=%0b ready=%0b",
                             cycle_count,
                             dut.tx_valid_reg, dut.tx_start_reg, dut.tx_last_reg,
                             dut.tx_row_id_reg, dut.tx_re_reg, dut.tx_im_reg,
                             dut.tx_accept, tx_row_ready);

                    $display("DBG C=%0d TX_MEM : proc0_enb=%0b proc0_addrb=%0d proc0_doutb=%016h | proc1_enb=%0b proc1_addrb=%0d proc1_doutb=%016h",
                             cycle_count,
                             dut.proc0_enb, dut.proc0_addrb, dut.proc0_doutb,
                             dut.proc1_enb, dut.proc1_addrb, dut.proc1_doutb);

                    if (tx_row_valid && tx_row_ready) begin
                        $display("DBG C=%0d TX_OUT : count=%0d start=%0b row=%0d re=%08h im=%08h",
                                 cycle_count, tx_count, tx_row_start, tx_row_row_id, tx_row_re, tx_row_im);
                    end

                    if (row_tx_done) begin
                        $display("DBG C=%0d TX_DONE", cycle_count);
                    end
                end
            end
        end
    end */

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
        rx_batch_start  = 0;
        rx_batch_row_id = 0;
        rx_batch_id     = 0;
        rx_sample_valid = 0;
        rx_sample_re    = 0;
        rx_sample_im    = 0;
        rx_sample_last  = 0;
        tx_row_ready    = 1;
        debug_test1_enable = 0;

        repeat (10) @(posedge clk);
        rst = 0;

        // =====================================================================
        // TEST1: debug-verbose
        // =====================================================================
        $display("============================================================");
        $display("TEST1: basic row reassembly / DSP / TX");
        $display("============================================================");
        clear_caps();
        debug_test1_enable = 1;

        send_batch(10'd5, 2'd2);
        send_batch(10'd5, 2'd0);
        send_batch(10'd5, 2'd3);
        send_batch(10'd5, 2'd1);

        wait_for_done(1, 30000, ok);
        debug_test1_enable = 0;

        print_summary("TEST1");
        expect_local(ok, "row 5 transmitted");
        expect_local(overflow_count == 0, "no overflow TEST1");
        expect_local(row_done_count == 1, "row_done TEST1");
        check_dsp_sequence(10'd5);
        check_tx_sequence(10'd5);

        // =====================================================================
        // TEST2+
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


