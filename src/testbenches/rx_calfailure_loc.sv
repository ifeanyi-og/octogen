
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/08/2026 07:39:33 PM
// Design Name:
// Module Name: rx_calfailure_loc
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

module tb_rx_plus_cal_loader;

    // =========================================================================
    // Clock / reset
    // =========================================================================
    logic clk = 0;
    logic rst = 1;

    always #5 clk = ~clk;

    // =========================================================================
    // UDP byte-stream stimulus into app_packet_rx
    // =========================================================================
    logic [7:0] udp_rx_tdata;
    logic       udp_rx_tvalid;
    logic       udp_rx_tlast;
    logic       udp_rx_tready;

    // =========================================================================
    // app_packet_rx outputs -> calibration_loader inputs
    // =========================================================================
    logic        hdr_valid;
    logic        hdr_error;
    logic        pkt_is_data;
    logic        pkt_is_cal;
    logic [7:0]  pkt_msg_type;
    logic [1:0]  batch_id;
    logic [9:0]  row_id;

    logic        batch_valid;
    logic [31:0] sample_data;
    logic        sample_valid;
    logic        sample_last;

    // =========================================================================
    // calibration_loader controls / outputs
    // =========================================================================
    logic       allow_cal;
    logic       dsp_busy;

    logic       cal_loading;
    logic       cal_done_pulse;
    logic       cal_error;
    logic       cal_rejected_busy;
    logic       cal_rejected_mode;
    logic [7:0] runtime_valid;
    logic [7:0] cal_seen;

    // =========================================================================
    // BRAM write buses from calibration_loader
    // =========================================================================
    logic        bg_wr_en;
    logic [0:0]  bg_wr_we;
    logic [9:0]  bg_wr_addr;
    logic [31:0] bg_wr_data;

    logic        disp_a_wr_en;
    logic [0:0]  disp_a_wr_we;
    logic [9:0]  disp_a_wr_addr;
    logic [31:0] disp_a_wr_data;

    logic        disp_b_wr_en;
    logic [0:0]  disp_b_wr_we;
    logic [9:0]  disp_b_wr_addr;
    logic [31:0] disp_b_wr_data;

    logic        klin_a_wr_en;
    logic [0:0]  klin_a_wr_we;
    logic [9:0]  klin_a_wr_addr;
    logic [31:0] klin_a_wr_data;

    logic        klin_b_wr_en;
    logic [0:0]  klin_b_wr_we;
    logic [9:0]  klin_b_wr_addr;
    logic [31:0] klin_b_wr_data;

    logic        klin_c_wr_en;
    logic [0:0]  klin_c_wr_we;
    logic [9:0]  klin_c_wr_addr;
    logic [31:0] klin_c_wr_data;

    logic        klin_d_wr_en;
    logic [0:0]  klin_d_wr_we;
    logic [9:0]  klin_d_wr_addr;
    logic [31:0] klin_d_wr_data;

    logic        klin_e_wr_en;
    logic [0:0]  klin_e_wr_we;
    logic [9:0]  klin_e_wr_addr;
    logic [31:0] klin_e_wr_data;

    // =========================================================================
    // DUTs
    // =========================================================================
    app_packet_rx u_rx (
        .clk           (clk),
        .rst           (rst),

        .udp_rx_tdata  (udp_rx_tdata),
        .udp_rx_tvalid (udp_rx_tvalid),
        .udp_rx_tready (udp_rx_tready),
        .udp_rx_tlast  (udp_rx_tlast),

        .hdr_valid     (hdr_valid),
        .hdr_error     (hdr_error),
        .pkt_is_data   (pkt_is_data),
        .pkt_is_cal    (pkt_is_cal),
        .pkt_msg_type  (pkt_msg_type),
        .batch_id      (batch_id),
        .row_id        (row_id),

        .batch_valid   (batch_valid),
        .sample_data   (sample_data),
        .sample_valid  (sample_valid),
        .sample_last   (sample_last)
    );

    calibration_loader #(
        .WATCHDOG_CYCLES(1029)
    ) u_cal_loader (
        .clk               (clk),
        .rst               (rst),

        .hdr_valid         (hdr_valid),
        .pkt_is_cal        (pkt_is_cal),
        .pkt_msg_type      (pkt_msg_type),
        .batch_id          (batch_id),
        .row_id            (row_id),

        .sample_valid      (sample_valid),
        .sample_data       (sample_data),
        .sample_last       (sample_last),
        .batch_valid       (batch_valid),

        .allow_cal         (allow_cal),
        .dsp_busy          (dsp_busy),

        .cal_loading       (cal_loading),
        .cal_done_pulse    (cal_done_pulse),
        .cal_error         (cal_error),
        .cal_rejected_busy (cal_rejected_busy),
        .cal_rejected_mode (cal_rejected_mode),
        .runtime_valid     (runtime_valid),
        .cal_seen          (cal_seen),

        .bg_wr_en          (bg_wr_en),
        .bg_wr_we          (bg_wr_we),
        .bg_wr_addr        (bg_wr_addr),
        .bg_wr_data        (bg_wr_data),

        .disp_a_wr_en      (disp_a_wr_en),
        .disp_a_wr_we      (disp_a_wr_we),
        .disp_a_wr_addr    (disp_a_wr_addr),
        .disp_a_wr_data    (disp_a_wr_data),

        .disp_b_wr_en      (disp_b_wr_en),
        .disp_b_wr_we      (disp_b_wr_we),
        .disp_b_wr_addr    (disp_b_wr_addr),
        .disp_b_wr_data    (disp_b_wr_data),

        .klin_a_wr_en      (klin_a_wr_en),
        .klin_a_wr_we      (klin_a_wr_we),
        .klin_a_wr_addr    (klin_a_wr_addr),
        .klin_a_wr_data    (klin_a_wr_data),

        .klin_b_wr_en      (klin_b_wr_en),
        .klin_b_wr_we      (klin_b_wr_we),
        .klin_b_wr_addr    (klin_b_wr_addr),
        .klin_b_wr_data    (klin_b_wr_data),

        .klin_c_wr_en      (klin_c_wr_en),
        .klin_c_wr_we      (klin_c_wr_we),
        .klin_c_wr_addr    (klin_c_wr_addr),
        .klin_c_wr_data    (klin_c_wr_data),

        .klin_d_wr_en      (klin_d_wr_en),
        .klin_d_wr_we      (klin_d_wr_we),
        .klin_d_wr_addr    (klin_d_wr_addr),
        .klin_d_wr_data    (klin_d_wr_data),

        .klin_e_wr_en      (klin_e_wr_en),
        .klin_e_wr_we      (klin_e_wr_we),
        .klin_e_wr_addr    (klin_e_wr_addr),
        .klin_e_wr_data    (klin_e_wr_data)
    );

    // =========================================================================
    // Constants
    // =========================================================================
    localparam int SAMPLES_PER_BATCH = 256;

    localparam logic [9:0] CAL_BG_ROWID     = 10'd0;
    localparam logic [9:0] CAL_DISP_A_ROWID = 10'd20;
    localparam logic [9:0] CAL_DISP_B_ROWID = 10'd21;
    localparam logic [9:0] CAL_KLIN_A_ROWID = 10'd24;
    localparam logic [9:0] CAL_KLIN_B_ROWID = 10'd25;
    localparam logic [9:0] CAL_KLIN_C_ROWID = 10'd26;
    localparam logic [9:0] CAL_KLIN_D_ROWID = 10'd27;
    localparam logic [9:0] CAL_KLIN_E_ROWID = 10'd28;

    // runtime_valid / cal_seen index map from calibration_loader
    localparam int IDX_BG     = 0;
    localparam int IDX_DISP_A = 1;
    localparam int IDX_DISP_B = 2;
    localparam int IDX_KLIN_A = 3;
    localparam int IDX_KLIN_B = 4;
    localparam int IDX_KLIN_C = 5;
    localparam int IDX_KLIN_D = 6;
    localparam int IDX_KLIN_E = 7;

    // =========================================================================
    // Scoreboard / pulse counters
    // =========================================================================
    int pass = 0;
    int fail = 0;

    int cal_error_pulses = 0;
    int cal_done_pulses  = 0;

    task automatic expect_local(input bit cond, input string msg);
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

    task automatic fatal_if_fail(input bit cond, input string msg);
    begin
        expect_local(cond, msg);
        if (!cond) begin
            $display("=================================");
            $display("TOTAL PASS = %0d", pass);
            $display("TOTAL FAIL = %0d", fail);
            $display("=================================");
            $finish;
        end
    end
    endtask

    task automatic clear_pulse_counters;
    begin
        cal_error_pulses = 0;
        cal_done_pulses  = 0;
    end
    endtask

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic clear_inputs;
    begin
        udp_rx_tdata  = 8'h00;
        udp_rx_tvalid = 1'b0;
        udp_rx_tlast  = 1'b0;
    end
    endtask

    task automatic idle_cycles(input int n);
        int i;
    begin
        for (i = 0; i < n; i++) begin
            @(posedge clk);
            udp_rx_tvalid <= 1'b0;
            udp_rx_tlast  <= 1'b0;
            udp_rx_tdata  <= 8'h00;
        end
    end
    endtask

    task automatic send_byte(input [7:0] b, input logic last);
    begin
        @(posedge clk);
        udp_rx_tdata  <= b;
        udp_rx_tvalid <= 1'b1;
        udp_rx_tlast  <= last;
    end
    endtask

    task automatic end_stream_cycle;
    begin
        @(posedge clk);
        udp_rx_tvalid <= 1'b0;
        udp_rx_tlast  <= 1'b0;
        udp_rx_tdata  <= 8'h00;
    end
    endtask

    task automatic send_header(input [7:0] msg_type, input [9:0] row, input [1:0] batch);
        logic [31:0] hdr;
    begin
        hdr = {8'hFF, msg_type, batch, 4'b0000, row};

        send_byte(hdr[7:0],   1'b0);
        send_byte(hdr[15:8],  1'b0);
        send_byte(hdr[23:16], 1'b0);
        send_byte(hdr[31:24], 1'b0);
    end
    endtask

    task automatic send_full_payload(input [31:0] base);
        int i;
        logic [31:0] val;
    begin
        for (i = 0; i < SAMPLES_PER_BATCH; i++) begin
            val = base + i;
            send_byte(val[7:0],   1'b0);
            send_byte(val[15:8],  1'b0);
            send_byte(val[23:16], 1'b0);
            send_byte(val[31:24], (i == SAMPLES_PER_BATCH-1));
        end
    end
    endtask

    task automatic send_truncated_payload(input int samples_to_send, input [31:0] base);
        int i;
        logic [31:0] val;
    begin
        for (i = 0; i < samples_to_send; i++) begin
            val = base + i;
            send_byte(val[7:0],   1'b0);
            send_byte(val[15:8],  1'b0);
            send_byte(val[23:16], 1'b0);
            send_byte(val[31:24], (i == samples_to_send-1));
        end
    end
    endtask

    // Packet sender with explicit control of whether to insert an idle cycle after the packet.
    // This is what lets us create true back-to-back packet traffic across row boundaries.
    task automatic send_full_cal_packet_core(
        input logic [9:0]  row,
        input logic [1:0]  batch,
        input logic [31:0] base,
        input bit          add_tail_idle
    );
    begin
        send_header(8'h02, row, batch);
        send_full_payload(base);
        if (add_tail_idle) begin
            end_stream_cycle();
        end
    end
    endtask

    task automatic send_truncated_cal_packet_core(
        input logic [9:0]  row,
        input logic [1:0]  batch,
        input int          samples_to_send,
        input logic [31:0] base,
        input bit          add_tail_idle
    );
    begin
        send_header(8'h02, row, batch);
        send_truncated_payload(samples_to_send, base);
        if (add_tail_idle) begin
            end_stream_cycle();
        end
    end
    endtask

    task automatic send_full_cal_packet(
        input logic [9:0] row,
        input logic [1:0] batch,
        input logic [31:0] base
    );
    begin
        send_full_cal_packet_core(row, batch, base, 1'b1);
    end
    endtask

    task automatic send_full_cal_row(
        input logic [9:0] row,
        input logic [31:0] base0,
        input logic [31:0] base1,
        input logic [31:0] base2,
        input logic [31:0] base3
    );
    begin
        send_full_cal_packet(row, 2'd0, base0);
        idle_cycles(2);
        send_full_cal_packet(row, 2'd1, base1);
        idle_cycles(2);
        send_full_cal_packet(row, 2'd2, base2);
        idle_cycles(2);
        send_full_cal_packet(row, 2'd3, base3);
        idle_cycles(4);
    end
    endtask

    task automatic send_full_cal_row_no_gaps(
        input logic [9:0] row,
        input logic [31:0] base0,
        input logic [31:0] base1,
        input logic [31:0] base2,
        input logic [31:0] base3
    );
    begin
        send_full_cal_packet_core(row, 2'd0, base0, 1'b0);
        send_full_cal_packet_core(row, 2'd1, base1, 1'b0);
        send_full_cal_packet_core(row, 2'd2, base2, 1'b0);
        send_full_cal_packet_core(row, 2'd3, base3, 1'b1);
    end
    endtask

    // True contiguous cross-row traffic: row A batch3 ends, next cycle begins row B batch0 header.
    // No inserted idle cycle between the two rows.
    task automatic send_two_full_cal_rows_back_to_back_no_row_gap(
        input logic [9:0] row_a,
        input logic [31:0] a_base0,
        input logic [31:0] a_base1,
        input logic [31:0] a_base2,
        input logic [31:0] a_base3,

        input logic [9:0] row_b,
        input logic [31:0] b_base0,
        input logic [31:0] b_base1,
        input logic [31:0] b_base2,
        input logic [31:0] b_base3
    );
    begin
        send_full_cal_packet_core(row_a, 2'd0, a_base0, 1'b0);
        send_full_cal_packet_core(row_a, 2'd1, a_base1, 1'b0);
        send_full_cal_packet_core(row_a, 2'd2, a_base2, 1'b0);
        send_full_cal_packet_core(row_a, 2'd3, a_base3, 1'b0);

        send_full_cal_packet_core(row_b, 2'd0, b_base0, 1'b0);
        send_full_cal_packet_core(row_b, 2'd1, b_base1, 1'b0);
        send_full_cal_packet_core(row_b, 2'd2, b_base2, 1'b0);
        send_full_cal_packet_core(row_b, 2'd3, b_base3, 1'b1);
    end
    endtask

    // Valid row immediately followed by malformed row, no idle gap between rows.
    task automatic send_valid_then_truncated_row_back_to_back_no_row_gap(
        input logic [9:0] good_row,
        input logic [31:0] good_base0,
        input logic [31:0] good_base1,
        input logic [31:0] good_base2,
        input logic [31:0] good_base3,

        input logic [9:0] bad_row,
        input logic [31:0] bad_base0,
        input logic [31:0] bad_base1,
        input logic [31:0] bad_base2,
        input logic [31:0] bad_base3,
        input int          bad_final_samples
    );
    begin
        send_full_cal_packet_core(good_row, 2'd0, good_base0, 1'b0);
        send_full_cal_packet_core(good_row, 2'd1, good_base1, 1'b0);
        send_full_cal_packet_core(good_row, 2'd2, good_base2, 1'b0);
        send_full_cal_packet_core(good_row, 2'd3, good_base3, 1'b0);

        send_full_cal_packet_core     (bad_row, 2'd0, bad_base0, 1'b0);
        send_full_cal_packet_core     (bad_row, 2'd1, bad_base1, 1'b0);
        send_full_cal_packet_core     (bad_row, 2'd2, bad_base2, 1'b0);
        send_truncated_cal_packet_core(bad_row, 2'd3, bad_final_samples, bad_base3, 1'b1);
    end
    endtask

    task automatic wait_for_runtime_bit(
        input int idx,
        input int timeout_cycles,
        output bit ok
    );
        int i;
    begin
        ok = 0;
        for (i = 0; i < timeout_cycles; i++) begin
            @(posedge clk);
            if (runtime_valid[idx]) begin
                ok = 1;
                return;
            end
        end
    end
    endtask

    task automatic wait_for_cal_seen_bit(
        input int idx,
        input int timeout_cycles,
        output bit ok
    );
        int i;
    begin
        ok = 0;
        for (i = 0; i < timeout_cycles; i++) begin
            @(posedge clk);
            if (cal_seen[idx]) begin
                ok = 1;
                return;
            end
        end
    end
    endtask

    task automatic wait_for_cal_error_pulse_count(
        input int min_pulses,
        input int timeout_cycles,
        output bit ok
    );
        int i;
    begin
        ok = 0;
        for (i = 0; i < timeout_cycles; i++) begin
            @(posedge clk);
            if (cal_error_pulses >= min_pulses) begin
                ok = 1;
                return;
            end
        end
    end
    endtask

    task automatic reset_dut;
    begin
        allow_cal = 1'b1;
        dsp_busy  = 1'b0;
        clear_inputs();
        clear_pulse_counters();

        rst = 1'b1;
        repeat (5) @(posedge clk);

        rst = 1'b0;
        repeat (5) @(posedge clk);
    end
    endtask

    // =========================================================================
    // Debug monitors
    // =========================================================================
    always @(posedge clk) begin
        if (!rst) begin
            if (hdr_valid) begin
                $display("[HDR] t=%0t msg=0x%02h cal=%0b data=%0b row=%0d batch=%0d",
                         $time, pkt_msg_type, pkt_is_cal, pkt_is_data, row_id, batch_id);
            end

            if (sample_valid && (sample_last || batch_valid)) begin
                $display("[SAMP-END] t=%0t row=%0d batch=%0d sample_last=%0b batch_valid=%0b data=0x%08h",
                         $time, row_id, batch_id, sample_last, batch_valid, sample_data);
            end

            if (cal_done_pulse) begin
                cal_done_pulses <= cal_done_pulses + 1;
                $display("[CAL DONE] t=%0t runtime_valid=0x%02h cal_seen=0x%02h",
                         $time, runtime_valid, cal_seen);
            end

            if (cal_error) begin
                cal_error_pulses <= cal_error_pulses + 1;
                $display("[CAL ERROR] t=%0t runtime_valid=0x%02h cal_seen=0x%02h",
                         $time, runtime_valid, cal_seen);
            end
        end
    end

    // =========================================================================
    // Main test sequence
    // =========================================================================
    bit ok;

    initial begin
        rst = 1'b1;
        allow_cal = 1'b1;
        dsp_busy  = 1'b0;
        clear_inputs();
        clear_pulse_counters();

        reset_dut();

        // ---------------------------------------------------------------------
        // TEST 1: Golden BG calibration row, batches 0->1->2->3
        // ---------------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST1: golden BG calibration row");
        $display("--------------------------------------------------");

        send_full_cal_row(
            CAL_BG_ROWID,
            32'h00010000,
            32'h00020000,
            32'h00030000,
            32'h00040000
        );

        wait_for_cal_seen_bit(IDX_BG, 2000, ok);
        fatal_if_fail(ok, "BG cal_seen asserted");

        wait_for_runtime_bit(IDX_BG, 2000, ok);
        fatal_if_fail(ok, "BG runtime_valid asserted");

        expect_local(runtime_valid[IDX_BG] == 1'b1, "BG runtime_valid stays high");
        expect_local(cal_seen[IDX_BG] == 1'b1, "BG cal_seen high");
        expect_local(runtime_valid == 8'b00000001, "only BG runtime_valid high");

        reset_dut();

        // ---------------------------------------------------------------------
        // TEST 2: Golden DISP_A calibration row
        // ---------------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST2: golden DISP_A calibration row");
        $display("--------------------------------------------------");

        send_full_cal_row(
            CAL_DISP_A_ROWID,
            32'h00110000,
            32'h00120000,
            32'h00130000,
            32'h00140000
        );

        wait_for_cal_seen_bit(IDX_DISP_A, 2000, ok);
        fatal_if_fail(ok, "DISP_A cal_seen asserted");

        wait_for_runtime_bit(IDX_DISP_A, 2000, ok);
        fatal_if_fail(ok, "DISP_A runtime_valid asserted");

        expect_local(runtime_valid[IDX_DISP_A] == 1'b1, "DISP_A runtime_valid high");
        expect_local(cal_seen[IDX_DISP_A] == 1'b1, "DISP_A cal_seen high");

        reset_dut();

        // ---------------------------------------------------------------------
        // TEST 3: Out-of-order batch sequence should fail
        // send KLIN_A batch0 then batch2
        // ---------------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST3: out-of-order calibration batches fail");
        $display("--------------------------------------------------");

        send_full_cal_packet(CAL_KLIN_A_ROWID, 2'd0, 32'h01000000);
        idle_cycles(2);
        send_full_cal_packet(CAL_KLIN_A_ROWID, 2'd2, 32'h01010000); // wrong, expected batch1
        idle_cycles(20);

        expect_local(cal_seen[IDX_KLIN_A] == 1'b1, "KLIN_A cal_seen asserted before failure");
        expect_local(runtime_valid[IDX_KLIN_A] == 1'b0, "KLIN_A runtime_valid remains low after out-of-order batch");

        reset_dut();

        // ---------------------------------------------------------------------
        // TEST 4: Incomplete final batch should fail
        // send valid batches 0,1,2 then truncated batch3
        // ---------------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST4: incomplete final batch prevents runtime_valid");
        $display("--------------------------------------------------");

        send_full_cal_packet(CAL_KLIN_B_ROWID, 2'd0, 32'h02000000);
        idle_cycles(2);
        send_full_cal_packet(CAL_KLIN_B_ROWID, 2'd1, 32'h02010000);
        idle_cycles(2);
        send_full_cal_packet(CAL_KLIN_B_ROWID, 2'd2, 32'h02020000);
        idle_cycles(2);

        send_truncated_cal_packet_core(CAL_KLIN_B_ROWID, 2'd3, 200, 32'h02030000, 1'b1);
        idle_cycles(40);

        expect_local(cal_seen[IDX_KLIN_B] == 1'b1, "KLIN_B cal_seen asserted");
        expect_local(runtime_valid[IDX_KLIN_B] == 1'b0, "KLIN_B runtime_valid remains low after incomplete final batch");

        $display("INFO: Resetting DUT after TEST4 malformed sequence");
        reset_dut();

        // ---------------------------------------------------------------------
        // TEST 5: Golden calibration row with no inter-batch gaps
        // ---------------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST5: golden KLIN_C calibration row, no inter-batch gaps");
        $display("--------------------------------------------------");

        send_full_cal_row_no_gaps(
            CAL_KLIN_C_ROWID,
            32'h03000000,
            32'h03010000,
            32'h03020000,
            32'h03030000
        );

        expect_local(cal_seen[IDX_KLIN_C] == 1'b1,
                     "KLIN_C cal_seen high immediately after no-gap transfer");

        $display("INFO: immediate runtime_valid[IDX_KLIN_C] = %0b", runtime_valid[IDX_KLIN_C]);

        @(posedge clk);
        $display("INFO: +1 cycle runtime_valid[IDX_KLIN_C] = %0b", runtime_valid[IDX_KLIN_C]);

        @(posedge clk);
        $display("INFO: +2 cycles runtime_valid[IDX_KLIN_C] = %0b", runtime_valid[IDX_KLIN_C]);

        expect_local(runtime_valid[IDX_KLIN_C] == 1'b1,
                     "KLIN_C runtime_valid asserted by +2 cycles after no-gap transfer");

        // Important interpretation:
        // Because reset_dut() was called before TEST5, a prior sticky cal_error
        // should already be cleared. So TEST5 passing means stale old cal_error
        // is not the blocker. It does NOT prove a new cal_error pulse can never
        // occur under a tighter cross-row transition case.

        reset_dut();

        // ---------------------------------------------------------------------
        // TEST 6A: Two different valid calibration rows with no row-to-row gap
        // Goal: prove row transition itself is robust when next row starts
        // immediately after prior row batch3 finishes.
        // ---------------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST6A: valid rows back-to-back, zero gap between rows");
        $display("--------------------------------------------------");

        send_two_full_cal_rows_back_to_back_no_row_gap(
            CAL_KLIN_D_ROWID,
            32'h04000000,
            32'h04010000,
            32'h04020000,
            32'h04030000,

            CAL_KLIN_E_ROWID,
            32'h05000000,
            32'h05010000,
            32'h05020000,
            32'h05030000
        );

        wait_for_cal_seen_bit(IDX_KLIN_D, 3000, ok);
        fatal_if_fail(ok, "KLIN_D cal_seen asserted in zero-gap row-to-row case");

        wait_for_runtime_bit(IDX_KLIN_D, 3000, ok);
        fatal_if_fail(ok, "KLIN_D runtime_valid asserted in zero-gap row-to-row case");

        wait_for_cal_seen_bit(IDX_KLIN_E, 3000, ok);
        fatal_if_fail(ok, "KLIN_E cal_seen asserted in zero-gap row-to-row case");

        wait_for_runtime_bit(IDX_KLIN_E, 3000, ok);
        fatal_if_fail(ok, "KLIN_E runtime_valid asserted in zero-gap row-to-row case");

        expect_local(runtime_valid[IDX_KLIN_D] == 1'b1,
                     "KLIN_D runtime_valid remains high after immediate next-row traffic");
        expect_local(runtime_valid[IDX_KLIN_E] == 1'b1,
                     "KLIN_E runtime_valid set under zero-gap next-row traffic");
        expect_local(cal_error_pulses == 0,
                     "No cal_error pulse during valid back-to-back row transition");

        reset_dut();

        // ---------------------------------------------------------------------
        // TEST 6B: Valid row immediately followed by malformed row, zero row gap
        // Goal: prove a bad next row does not poison the already-good prior row.
        // ---------------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST6B: valid row then malformed row, zero gap between rows");
        $display("--------------------------------------------------");

        send_valid_then_truncated_row_back_to_back_no_row_gap(
            CAL_DISP_B_ROWID,
            32'h06000000,
            32'h06010000,
            32'h06020000,
            32'h06030000,

            CAL_KLIN_D_ROWID,
            32'h07000000,
            32'h07010000,
            32'h07020000,
            32'h07030000,
            200
        );

        wait_for_cal_seen_bit(IDX_DISP_B, 3000, ok);
        fatal_if_fail(ok, "DISP_B cal_seen asserted before malformed next-row traffic");

        wait_for_runtime_bit(IDX_DISP_B, 3000, ok);
        fatal_if_fail(ok, "DISP_B runtime_valid asserted before malformed next-row traffic");

        wait_for_cal_seen_bit(IDX_KLIN_D, 3000, ok);
        fatal_if_fail(ok, "KLIN_D cal_seen asserted even for malformed row");

        wait_for_cal_error_pulse_count(1, 3000, ok);
        fatal_if_fail(ok, "Malformed zero-gap next row causes at least one cal_error pulse");

        idle_cycles(40);

        expect_local(runtime_valid[IDX_DISP_B] == 1'b1,
                     "Earlier good DISP_B calibration remains valid after malformed next row");
        expect_local(runtime_valid[IDX_KLIN_D] == 1'b0,
                     "Malformed KLIN_D row does not become runtime_valid");
        expect_local(cal_error_pulses >= 1,
                     "Malformed next-row case recorded cal_error pulse(s)");

        // ---------------------------------------------------------------------
        // Final summary
        // ---------------------------------------------------------------------
        $display("=================================");
        $display("FINAL runtime_valid = 0x%02h", runtime_valid);
        $display("FINAL cal_seen      = 0x%02h", cal_seen);
        $display("FINAL cal_error_pulses = %0d", cal_error_pulses);
        $display("FINAL cal_done_pulses  = %0d", cal_done_pulses);
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");

        $finish;
    end

endmodule
