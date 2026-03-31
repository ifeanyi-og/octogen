`timescale 1ns / 1ps
// =============================================================================
// tb_dspcorestub
//
// Holistic unit testbench for dsp_core_top first-half passthrough stub.
//
// Validates:
// - 1024 input samples per row are accepted
// - 512 output samples per row are emitted
// - output[k] = input[k] for k = 0..511
// - out_row_start pulses on first output sample only
// - row_done pulses on last output sample only
// - busy goes high during row processing and returns low after completion
// - multiple rows work correctly
// - input gaps during row fill do not break correctness
//
// Important DUT contract:
// - do not start a new row while busy=1
// =============================================================================

module tb_dspcorestub;

    localparam int IN_SAMPLES_PER_ROW  = 1024;
    localparam int OUT_SAMPLES_PER_ROW = 512;

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst;

    logic        in_valid;
    logic        in_row_start;
    logic [31:0] in_data;

    wire         out_valid;
    wire         out_row_start;
    wire [31:0]  out_data;
    wire         busy;
    wire         row_done;

    dsp_core_top #(
        .IN_SAMPLES_PER_ROW (IN_SAMPLES_PER_ROW),
        .OUT_SAMPLES_PER_ROW(OUT_SAMPLES_PER_ROW)
    ) dut (
        .clk          (clk),
        .rst          (rst),
        .in_valid     (in_valid),
        .in_row_start (in_row_start),
        .in_data      (in_data),
        .out_valid    (out_valid),
        .out_row_start(out_row_start),
        .out_data     (out_data),
        .busy         (busy),
        .row_done     (row_done)
    );

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Scoreboard
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    typedef struct {
        int          row_id;
        int          out_idx;
        logic [31:0] data;
    } exp_t;

    exp_t exp_q[$];

    int total_outputs_seen = 0;
    int total_rows_done    = 0;
    int current_row_seen   = 0;
    int current_out_idx    = 0;

    task automatic check(input bit cond, input string msg);
    begin
        if (cond) begin
            pass_count++;
        end else begin
            fail_count++;
            $display("FAIL [%0t] %s", $time, msg);
        end
    end
    endtask

    task automatic fatal_check(input bit cond, input string msg);
    begin
        check(cond, msg);
        if (!cond) begin
            $display("FATAL [%0t] %s", $time, msg);
            $display("PASS=%0d FAIL=%0d", pass_count, fail_count);
            $finish;
        end
    end
    endtask

    task automatic wait_clk(input int n);
        int i;
    begin
        for (i = 0; i < n; i++) @(posedge clk);
    end
    endtask

    task automatic drive_idle_cycle;
    begin
        @(posedge clk);
        in_valid     <= 1'b0;
        in_row_start <= 1'b0;
        in_data      <= 32'd0;
    end
    endtask

    task automatic drive_sample(
        input bit         valid_i,
        input bit         row_start_i,
        input logic [31:0] data_i
    );
    begin
        @(posedge clk);
        in_valid     <= valid_i;
        in_row_start <= row_start_i;
        in_data      <= data_i;
    end
    endtask

    task automatic reset_dut;
    begin
        rst          <= 1'b1;
        in_valid     <= 1'b0;
        in_row_start <= 1'b0;
        in_data      <= 32'd0;
        wait_clk(5);
        rst          <= 1'b0;
        wait_clk(2);
    end
    endtask

    task automatic push_expected_row(
        input int          row_id,
        input logic [31:0] base
    );
        int k;
        exp_t item;
    begin
        for (k = 0; k < OUT_SAMPLES_PER_ROW; k++) begin
            item.row_id  = row_id;
            item.out_idx = k;
            item.data    = base + k;
            exp_q.push_back(item);
        end
    end
    endtask

    // -------------------------------------------------------------------------
    // Send one row
    //
    // base defines sample pattern:
    // sample[i] = base + i
    //
    // gap_every_n_valids = 0 means fully contiguous
    // otherwise insert gap_len idle cycles after each N valid samples
    // -------------------------------------------------------------------------
    task automatic send_row(
        input int          row_id,
        input logic [31:0] base,
        input int          gap_every_n_valids,
        input int          gap_len
    );
        int i;
        int valids_sent;
        int g;
        logic [31:0] sample_val;
    begin
        fatal_check(busy == 1'b0, $sformatf("busy low before starting row %0d", row_id));

        push_expected_row(row_id, base);
        valids_sent = 0;

        for (i = 0; i < IN_SAMPLES_PER_ROW; i++) begin
            sample_val = base + i;
            drive_sample(1'b1, (i == 0), sample_val);
            valids_sent++;

            if ((gap_every_n_valids > 0) &&
                (valids_sent < IN_SAMPLES_PER_ROW) &&
                ((valids_sent % gap_every_n_valids) == 0)) begin
                for (g = 0; g < gap_len; g++) begin
                    drive_idle_cycle();
                end
            end
        end

        // release inputs after row send
        drive_idle_cycle();
    end
    endtask

    task automatic wait_until_idle(input int max_cycles);
        int i;
    begin
        for (i = 0; i < max_cycles; i++) begin
            if ((busy == 1'b0) && (exp_q.size() == 0)) begin
                return;
            end
            drive_idle_cycle();
        end
        fatal_check(0, "timed out waiting for DUT idle and empty expected queue");
    end
    endtask

    // -------------------------------------------------------------------------
    // Output monitor / checker
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            exp_q.delete();
            total_outputs_seen <= 0;
            total_rows_done    <= 0;
            current_row_seen   <= 0;
            current_out_idx    <= 0;
        end else begin
            if (out_valid) begin
                exp_t item;

                fatal_check(exp_q.size() > 0, "expected queue not empty when out_valid is high");
                item = exp_q.pop_front();

                total_outputs_seen <= total_outputs_seen + 1;

                check(out_data === item.data,
                      $sformatf("out_data matches expected row=%0d out_idx=%0d exp=%0d got=%0d",
                                item.row_id, item.out_idx, item.data, out_data));

                check(current_row_seen == item.row_id,
                      $sformatf("output row sequence correct exp=%0d got=%0d",
                                item.row_id, current_row_seen));

                check(current_out_idx == item.out_idx,
                      $sformatf("output index sequence correct row=%0d exp=%0d got=%0d",
                                item.row_id, item.out_idx, current_out_idx));

                if (item.out_idx == 0) begin
                    check(out_row_start == 1'b1,
                          $sformatf("out_row_start asserted on first output of row %0d", item.row_id));
                end else begin
                    check(out_row_start == 1'b0,
                          $sformatf("out_row_start deasserted on non-first output row=%0d out_idx=%0d",
                                    item.row_id, item.out_idx));
                end

                if (item.out_idx == OUT_SAMPLES_PER_ROW-1) begin
                    check(row_done == 1'b1,
                          $sformatf("row_done asserted on final output of row %0d", item.row_id));
                    total_rows_done <= total_rows_done + 1;
                    current_row_seen <= current_row_seen + 1;
                    current_out_idx <= 0;
                end else begin
                    check(row_done == 1'b0,
                          $sformatf("row_done deasserted on non-final output row=%0d out_idx=%0d",
                                    item.row_id, item.out_idx));
                    current_out_idx <= current_out_idx + 1;
                end
            end else begin
                check(out_row_start == 1'b0, "out_row_start only pulses with out_valid");
                check(row_done == 1'b0, "row_done only pulses with out_valid");
            end
        end
    end

    // -------------------------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------------------------
    initial begin
        rst          = 1'b1;
        in_valid     = 1'b0;
        in_row_start = 1'b0;
        in_data      = 32'd0;

        wait_clk(3);
        reset_dut();

        check(busy == 1'b0, "busy low after reset");
        check(out_valid == 1'b0, "out_valid low after reset");
        check(out_row_start == 1'b0, "out_row_start low after reset");
        check(row_done == 1'b0, "row_done low after reset");

        // ---------------------------------------------------------------------
        // TEST 1: single contiguous row
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 1: single contiguous row");
        $display("==================================================");

        send_row(0, 32'd100000, 0, 0);
        wait_until_idle(5000);

        check(total_outputs_seen == 512, "after test1 saw exactly 512 outputs");
        check(total_rows_done    == 1,   "after test1 saw exactly 1 completed row");
        check(busy == 1'b0, "busy low after test1");

        // ---------------------------------------------------------------------
        // TEST 2: second row contiguous, different data base
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 2: second contiguous row with different base");
        $display("==================================================");

        send_row(1, 32'd200000, 0, 0);
        wait_until_idle(5000);

        check(total_outputs_seen == 1024, "after test2 saw exactly 1024 total outputs");
        check(total_rows_done    == 2,    "after test2 saw exactly 2 completed rows");
        check(busy == 1'b0, "busy low after test2");

        // ---------------------------------------------------------------------
        // TEST 3: third row with input gaps during fill
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 3: third row with regular input gaps");
        $display("==================================================");

        send_row(2, 32'd300000, 37, 2);
        wait_until_idle(10000);

        check(total_outputs_seen == 1536, "after test3 saw exactly 1536 total outputs");
        check(total_rows_done    == 3,    "after test3 saw exactly 3 completed rows");
        check(busy == 1'b0, "busy low after test3");

        // ---------------------------------------------------------------------
        // TEST 4: idle stability
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("TEST 4: idle stability");
        $display("==================================================");

        repeat (50) drive_idle_cycle();

        check(out_valid == 1'b0, "no spurious out_valid during idle");
        check(out_row_start == 1'b0, "no spurious out_row_start during idle");
        check(row_done == 1'b0, "no spurious row_done during idle");
        check(busy == 1'b0, "busy remains low during idle");
        check(exp_q.size() == 0, "expected queue empty at end");

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        $display("==================================================");
        $display("FINAL SUMMARY");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);
        $display("TOTAL OUTPUTS SEEN = %0d", total_outputs_seen);
        $display("TOTAL ROWS DONE    = %0d", total_rows_done);
        $display("==================================================");

        if (fail_count == 0)
            $display("TB_DSPCORESTUB: PASS");
        else
            $display("TB_DSPCORESTUB: FAIL");

        $finish;
    end

endmodule

