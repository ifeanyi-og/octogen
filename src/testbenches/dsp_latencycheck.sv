`timescale 1ns / 1ps

module tb_dsp_core_cal_compare;

    localparam int IN_SAMPLES_PER_ROW  = 1024;
    localparam int OUT_SAMPLES_PER_ROW = 512;

    // -------------------------------------------------------------------------
    // Clock / Reset
    // -------------------------------------------------------------------------
    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = ~clk;   // 100 MHz

    // -------------------------------------------------------------------------
    // DUT inputs
    // -------------------------------------------------------------------------
    reg         in_valid;
    reg         in_row_start;
    reg [31:0]  in_data;

    reg [7:0]   runtime_valid;

    reg         bg_wr_en;
    reg [0:0]   bg_wr_we;
    reg [9:0]   bg_wr_addr;
    reg [31:0]  bg_wr_data;

    reg         disp_a_wr_en;
    reg [0:0]   disp_a_wr_we;
    reg [9:0]   disp_a_wr_addr;
    reg [31:0]  disp_a_wr_data;

    reg         disp_b_wr_en;
    reg [0:0]   disp_b_wr_we;
    reg [9:0]   disp_b_wr_addr;
    reg [31:0]  disp_b_wr_data;

    reg         klin_a_wr_en;
    reg [0:0]   klin_a_wr_we;
    reg [9:0]   klin_a_wr_addr;
    reg [31:0]  klin_a_wr_data;

    reg         klin_b_wr_en;
    reg [0:0]   klin_b_wr_we;
    reg [9:0]   klin_b_wr_addr;
    reg [31:0]  klin_b_wr_data;

    reg         klin_c_wr_en;
    reg [0:0]   klin_c_wr_we;
    reg [9:0]   klin_c_wr_addr;
    reg [31:0]  klin_c_wr_data;

    reg         klin_d_wr_en;
    reg [0:0]   klin_d_wr_we;
    reg [9:0]   klin_d_wr_addr;
    reg [31:0]  klin_d_wr_data;

    reg         klin_e_wr_en;
    reg [0:0]   klin_e_wr_we;
    reg [9:0]   klin_e_wr_addr;
    reg [31:0]  klin_e_wr_data;

    // -------------------------------------------------------------------------
    // DUT outputs
    // -------------------------------------------------------------------------
    wire        out_valid;
    wire        out_row_start;
    wire [31:0] out_data;
    wire        busy;
    wire        row_done;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    dsp_core_top #(
        .IN_SAMPLES_PER_ROW (IN_SAMPLES_PER_ROW),
        .OUT_SAMPLES_PER_ROW(OUT_SAMPLES_PER_ROW)
    ) dut (
        .clk           (clk),
        .rst           (rst),

        .in_valid      (in_valid),
        .in_row_start  (in_row_start),
        .in_data       (in_data),

        .runtime_valid (runtime_valid),

        .bg_wr_en      (bg_wr_en),
        .bg_wr_we      (bg_wr_we),
        .bg_wr_addr    (bg_wr_addr),
        .bg_wr_data    (bg_wr_data),

        .disp_a_wr_en  (disp_a_wr_en),
        .disp_a_wr_we  (disp_a_wr_we),
        .disp_a_wr_addr(disp_a_wr_addr),
        .disp_a_wr_data(disp_a_wr_data),

        .disp_b_wr_en  (disp_b_wr_en),
        .disp_b_wr_we  (disp_b_wr_we),
        .disp_b_wr_addr(disp_b_wr_addr),
        .disp_b_wr_data(disp_b_wr_data),

        .klin_a_wr_en  (klin_a_wr_en),
        .klin_a_wr_we  (klin_a_wr_we),
        .klin_a_wr_addr(klin_a_wr_addr),
        .klin_a_wr_data(klin_a_wr_data),

        .klin_b_wr_en  (klin_b_wr_en),
        .klin_b_wr_we  (klin_b_wr_we),
        .klin_b_wr_addr(klin_b_wr_addr),
        .klin_b_wr_data(klin_b_wr_data),

        .klin_c_wr_en  (klin_c_wr_en),
        .klin_c_wr_we  (klin_c_wr_we),
        .klin_c_wr_addr(klin_c_wr_addr),
        .klin_c_wr_data(klin_c_wr_data),

        .klin_d_wr_en  (klin_d_wr_en),
        .klin_d_wr_we  (klin_d_wr_we),
        .klin_d_wr_addr(klin_d_wr_addr),
        .klin_d_wr_data(klin_d_wr_data),

        .klin_e_wr_en  (klin_e_wr_en),
        .klin_e_wr_we  (klin_e_wr_we),
        .klin_e_wr_addr(klin_e_wr_addr),
        .klin_e_wr_data(klin_e_wr_data),

        .out_valid     (out_valid),
        .out_row_start (out_row_start),
        .out_data      (out_data),
        .busy          (busy),
        .row_done      (row_done)
    );

    // -------------------------------------------------------------------------
    // Memory images
    // -------------------------------------------------------------------------
    reg [31:0] bg_mem        [0:1023];
    reg [31:0] disp_cos_mem  [0:1023];
    reg [31:0] disp_sin_mem  [0:1023];
    reg [31:0] klin_base_mem [0:1023];
    reg [31:0] klin_c0_mem   [0:1023];
    reg [31:0] klin_c1_mem   [0:1023];
    reg [31:0] klin_c2_mem   [0:1023];
    reg [31:0] klin_c3_mem   [0:1023];
    reg [31:0] input_sig_mem [0:1023];

    integer i;

    // -------------------------------------------------------------------------
    // Run selector
    // 0 = idle
    // 1 = pre-cal row
    // 2 = post-cal row
    // -------------------------------------------------------------------------
    integer active_run;

    // -------------------------------------------------------------------------
    // File handles: pre-cal
    // -------------------------------------------------------------------------
    integer f_pre_in;
    integer f_pre_bg;
    integer f_pre_klin;
    integer f_pre_disp;
    integer f_pre_fft;
    integer f_pre_topsel;
    integer f_pre_mag;
    integer f_pre_final;

    // -------------------------------------------------------------------------
    // File handles: post-cal
    // -------------------------------------------------------------------------
    integer f_post_in;
    integer f_post_bg;
    integer f_post_klin;
    integer f_post_disp;
    integer f_post_fft;
    integer f_post_topsel;
    integer f_post_mag;
    integer f_post_final;

    // -------------------------------------------------------------------------
    // Counters: pre-cal
    // -------------------------------------------------------------------------
    integer pre_in_count;
    integer pre_bg_count;
    integer pre_klin_count;
    integer pre_disp_count;
    integer pre_fft_count;
    integer pre_topsel_count;
    integer pre_mag_count;
    integer pre_final_count;
    integer pre_rowdone_count;

    // -------------------------------------------------------------------------
    // Counters: post-cal
    // -------------------------------------------------------------------------
    integer post_in_count;
    integer post_bg_count;
    integer post_klin_count;
    integer post_disp_count;
    integer post_fft_count;
    integer post_topsel_count;
    integer post_mag_count;
    integer post_final_count;
    integer post_rowdone_count;

    // -------------------------------------------------------------------------
    // Global cycle counter
    // -------------------------------------------------------------------------
    integer sim_cycle;

    always @(posedge clk) begin
        if (rst)
            sim_cycle <= 0;
        else
            sim_cycle <= sim_cycle + 1;
    end

    // -------------------------------------------------------------------------
    // Stage valid aliases
    // -------------------------------------------------------------------------
    wire stg_in_valid      = in_valid;
    wire stg_bg_valid      = dut.bgsub_out_valid;
    wire stg_klin_valid    = dut.klin_out_valid;
    wire stg_disp_valid    = dut.disp_out_valid;
    wire stg_fft_valid     = dut.fft_out_valid;
    wire stg_topsel_valid  = dut.topsel_out_valid;
    wire stg_mag_valid     = dut.mag_out_valid;
    wire stg_final_valid   = out_valid;

    // -------------------------------------------------------------------------
    // First-valid cycle capture per run
    // -------------------------------------------------------------------------
    integer run1_in_first_cycle,     run2_in_first_cycle;
    integer run1_bg_first_cycle,     run2_bg_first_cycle;
    integer run1_klin_first_cycle,   run2_klin_first_cycle;
    integer run1_disp_first_cycle,   run2_disp_first_cycle;
    integer run1_fft_first_cycle,    run2_fft_first_cycle;
    integer run1_topsel_first_cycle, run2_topsel_first_cycle;
    integer run1_mag_first_cycle,    run2_mag_first_cycle;
    integer run1_final_first_cycle,  run2_final_first_cycle;

    reg run1_in_seen,     run2_in_seen;
    reg run1_bg_seen,     run2_bg_seen;
    reg run1_klin_seen,   run2_klin_seen;
    reg run1_disp_seen,   run2_disp_seen;
    reg run1_fft_seen,    run2_fft_seen;
    reg run1_topsel_seen, run2_topsel_seen;
    reg run1_mag_seen,    run2_mag_seen;
    reg run1_final_seen,  run2_final_seen;

    // -------------------------------------------------------------------------
    // Per-stage last-valid cycle and gap violations
    // -------------------------------------------------------------------------
    integer run1_in_last_cycle,     run2_in_last_cycle;
    integer run1_bg_last_cycle,     run2_bg_last_cycle;
    integer run1_klin_last_cycle,   run2_klin_last_cycle;
    integer run1_disp_last_cycle,   run2_disp_last_cycle;
    integer run1_fft_last_cycle,    run2_fft_last_cycle;
    integer run1_topsel_last_cycle, run2_topsel_last_cycle;
    integer run1_mag_last_cycle,    run2_mag_last_cycle;
    integer run1_final_last_cycle,  run2_final_last_cycle;

    integer run1_in_gap_viol,     run2_in_gap_viol;
    integer run1_bg_gap_viol,     run2_bg_gap_viol;
    integer run1_klin_gap_viol,   run2_klin_gap_viol;
    integer run1_disp_gap_viol,   run2_disp_gap_viol;
    integer run1_fft_gap_viol,    run2_fft_gap_viol;
    integer run1_topsel_gap_viol, run2_topsel_gap_viol;
    integer run1_mag_gap_viol,    run2_mag_gap_viol;
    integer run1_final_gap_viol,  run2_final_gap_viol;

    // -------------------------------------------------------------------------
    // Utility tasks
    // -------------------------------------------------------------------------
    task automatic clear_inputs;
    begin
        in_valid       = 1'b0;
        in_row_start   = 1'b0;
        in_data        = 32'd0;

        runtime_valid  = 8'h00;

        bg_wr_en       = 1'b0;  bg_wr_we       = 1'b0;  bg_wr_addr       = 10'd0; bg_wr_data       = 32'd0;
        disp_a_wr_en   = 1'b0;  disp_a_wr_we   = 1'b0;  disp_a_wr_addr   = 10'd0; disp_a_wr_data   = 32'd0;
        disp_b_wr_en   = 1'b0;  disp_b_wr_we   = 1'b0;  disp_b_wr_addr   = 10'd0; disp_b_wr_data   = 32'd0;
        klin_a_wr_en   = 1'b0;  klin_a_wr_we   = 1'b0;  klin_a_wr_addr   = 10'd0; klin_a_wr_data   = 32'd0;
        klin_b_wr_en   = 1'b0;  klin_b_wr_we   = 1'b0;  klin_b_wr_addr   = 10'd0; klin_b_wr_data   = 32'd0;
        klin_c_wr_en   = 1'b0;  klin_c_wr_we   = 1'b0;  klin_c_wr_addr   = 10'd0; klin_c_wr_data   = 32'd0;
        klin_d_wr_en   = 1'b0;  klin_d_wr_we   = 1'b0;  klin_d_wr_addr   = 10'd0; klin_d_wr_data   = 32'd0;
        klin_e_wr_en   = 1'b0;  klin_e_wr_we   = 1'b0;  klin_e_wr_addr   = 10'd0; klin_e_wr_data   = 32'd0;
    end
    endtask

    task automatic wait_clk(input integer n);
        integer k;
    begin
        for (k = 0; k < n; k = k + 1)
            @(posedge clk);
    end
    endtask

    task automatic pulse_reset;
    begin
        rst = 1'b1;
        clear_inputs();
        active_run = 0;
        wait_clk(8);
        rst = 1'b0;
        wait_clk(8);
    end
    endtask

    task automatic open_dump_files;
    begin
        f_pre_in     = $fopen("pre_input.txt",      "w");
        f_pre_bg     = $fopen("pre_bg_out.txt",     "w");
        f_pre_klin   = $fopen("pre_klin_out.txt",   "w");
        f_pre_disp   = $fopen("pre_disp_out.txt",   "w");
        f_pre_fft    = $fopen("pre_fft_out.txt",    "w");
        f_pre_topsel = $fopen("pre_topsel_out.txt", "w");
        f_pre_mag    = $fopen("pre_mag_out.txt",    "w");
        f_pre_final  = $fopen("pre_final_out.txt",  "w");

        f_post_in     = $fopen("post_input.txt",      "w");
        f_post_bg     = $fopen("post_bg_out.txt",     "w");
        f_post_klin   = $fopen("post_klin_out.txt",   "w");
        f_post_disp   = $fopen("post_disp_out.txt",   "w");
        f_post_fft    = $fopen("post_fft_out.txt",    "w");
        f_post_topsel = $fopen("post_topsel_out.txt", "w");
        f_post_mag    = $fopen("post_mag_out.txt",    "w");
        f_post_final  = $fopen("post_final_out.txt",  "w");
    end
    endtask

    task automatic close_dump_files;
    begin
        $display("---- CURRENT WORKING DIRECTORY ----");
        $system("cd");
        $display("-----------------------------------");

        $fclose(f_pre_in);
        $fclose(f_pre_bg);
        $fclose(f_pre_klin);
        $fclose(f_pre_disp);
        $fclose(f_pre_fft);
        $fclose(f_pre_topsel);
        $fclose(f_pre_mag);
        $fclose(f_pre_final);

        $fclose(f_post_in);
        $fclose(f_post_bg);
        $fclose(f_post_klin);
        $fclose(f_post_disp);
        $fclose(f_post_fft);
        $fclose(f_post_topsel);
        $fclose(f_post_mag);
        $fclose(f_post_final);
    end
    endtask

    task automatic reset_counters;
    begin
        pre_in_count      = 0;
        pre_bg_count      = 0;
        pre_klin_count    = 0;
        pre_disp_count    = 0;
        pre_fft_count     = 0;
        pre_topsel_count  = 0;
        pre_mag_count     = 0;
        pre_final_count   = 0;
        pre_rowdone_count = 0;

        post_in_count      = 0;
        post_bg_count      = 0;
        post_klin_count    = 0;
        post_disp_count    = 0;
        post_fft_count     = 0;
        post_topsel_count  = 0;
        post_mag_count     = 0;
        post_final_count   = 0;
        post_rowdone_count = 0;
    end
    endtask

    task automatic reset_stream_checks;
    begin
        run1_in_first_cycle     = -1; run2_in_first_cycle     = -1;
        run1_bg_first_cycle     = -1; run2_bg_first_cycle     = -1;
        run1_klin_first_cycle   = -1; run2_klin_first_cycle   = -1;
        run1_disp_first_cycle   = -1; run2_disp_first_cycle   = -1;
        run1_fft_first_cycle    = -1; run2_fft_first_cycle    = -1;
        run1_topsel_first_cycle = -1; run2_topsel_first_cycle = -1;
        run1_mag_first_cycle    = -1; run2_mag_first_cycle    = -1;
        run1_final_first_cycle  = -1; run2_final_first_cycle  = -1;

        run1_in_seen     = 1'b0; run2_in_seen     = 1'b0;
        run1_bg_seen     = 1'b0; run2_bg_seen     = 1'b0;
        run1_klin_seen   = 1'b0; run2_klin_seen   = 1'b0;
        run1_disp_seen   = 1'b0; run2_disp_seen   = 1'b0;
        run1_fft_seen    = 1'b0; run2_fft_seen    = 1'b0;
        run1_topsel_seen = 1'b0; run2_topsel_seen = 1'b0;
        run1_mag_seen    = 1'b0; run2_mag_seen    = 1'b0;
        run1_final_seen  = 1'b0; run2_final_seen  = 1'b0;

        run1_in_last_cycle     = -1; run2_in_last_cycle     = -1;
        run1_bg_last_cycle     = -1; run2_bg_last_cycle     = -1;
        run1_klin_last_cycle   = -1; run2_klin_last_cycle   = -1;
        run1_disp_last_cycle   = -1; run2_disp_last_cycle   = -1;
        run1_fft_last_cycle    = -1; run2_fft_last_cycle    = -1;
        run1_topsel_last_cycle = -1; run2_topsel_last_cycle = -1;
        run1_mag_last_cycle    = -1; run2_mag_last_cycle    = -1;
        run1_final_last_cycle  = -1; run2_final_last_cycle  = -1;

        run1_in_gap_viol     = 0; run2_in_gap_viol     = 0;
        run1_bg_gap_viol     = 0; run2_bg_gap_viol     = 0;
        run1_klin_gap_viol   = 0; run2_klin_gap_viol   = 0;
        run1_disp_gap_viol   = 0; run2_disp_gap_viol   = 0;
        run1_fft_gap_viol    = 0; run2_fft_gap_viol    = 0;
        run1_topsel_gap_viol = 0; run2_topsel_gap_viol = 0;
        run1_mag_gap_viol    = 0; run2_mag_gap_viol    = 0;
        run1_final_gap_viol  = 0; run2_final_gap_viol  = 0;
    end
    endtask

    task automatic report_run_latency(input integer run_id);
        integer in0, bg0, klin0, disp0, fft0, topsel0, mag0, final0;
    begin
        if (run_id == 1) begin
            in0     = run1_in_first_cycle;
            bg0     = run1_bg_first_cycle;
            klin0   = run1_klin_first_cycle;
            disp0   = run1_disp_first_cycle;
            fft0    = run1_fft_first_cycle;
            topsel0 = run1_topsel_first_cycle;
            mag0    = run1_mag_first_cycle;
            final0  = run1_final_first_cycle;
        end else begin
            in0     = run2_in_first_cycle;
            bg0     = run2_bg_first_cycle;
            klin0   = run2_klin_first_cycle;
            disp0   = run2_disp_first_cycle;
            fft0    = run2_fft_first_cycle;
            topsel0 = run2_topsel_first_cycle;
            mag0    = run2_mag_first_cycle;
            final0  = run2_final_first_cycle;
        end

        $display("--------------------------------------------------");
        $display("LATENCY REPORT: RUN %0d", run_id);
        $display("All values are in clock cycles.");
        $display("Cumulative from first input valid:");
        $display("  bg_sub     = %0d", bg0     - in0);
        $display("  k_lin      = %0d", klin0   - in0);
        $display("  disp_comp  = %0d", disp0   - in0);
        $display("  fft        = %0d", fft0    - in0);
        $display("  top_select = %0d", topsel0 - in0);
        $display("  mag_calc   = %0d", mag0    - in0);
        $display("  log & gs   = %0d", final0  - in0);

        $display("Block-only first-sample latency:");
        $display("  bg_sub     = %0d", bg0     - in0);
        $display("  k_lin      = %0d", klin0   - bg0);
        $display("  disp_comp  = %0d", disp0   - klin0);
        $display("  fft        = %0d", fft0    - disp0);
        $display("  top_select = %0d", topsel0 - fft0);
        $display("  mag_calc   = %0d", mag0    - topsel0);
        $display("  log & gs   = %0d", final0  - mag0);
    end
    endtask

    task automatic report_run_streaming(input integer run_id);
        integer total_viol;
    begin
        total_viol = 0;

        $display("--------------------------------------------------");
        $display("STREAMING GAP REPORT: RUN %0d", run_id);
        $display("A violation means successive output valids were more than 1 clock apart.");

        if (run_id == 1) begin
            $display("  input      gap violations = %0d", run1_in_gap_viol);     total_viol = total_viol + run1_in_gap_viol;
            $display("  bg_sub     gap violations = %0d", run1_bg_gap_viol);     total_viol = total_viol + run1_bg_gap_viol;
            $display("  k_lin      gap violations = %0d", run1_klin_gap_viol);   total_viol = total_viol + run1_klin_gap_viol;
            $display("  disp_comp  gap violations = %0d", run1_disp_gap_viol);   total_viol = total_viol + run1_disp_gap_viol;
            $display("  fft        gap violations = %0d", run1_fft_gap_viol);    total_viol = total_viol + run1_fft_gap_viol;
            $display("  top_select gap violations = %0d", run1_topsel_gap_viol); total_viol = total_viol + run1_topsel_gap_viol;
            $display("  mag_calc   gap violations = %0d", run1_mag_gap_viol);    total_viol = total_viol + run1_mag_gap_viol;
            $display("  final      gap violations = %0d", run1_final_gap_viol);  total_viol = total_viol + run1_final_gap_viol;

            if (run1_in_gap_viol     > 0) $display("    VIOLATION BLOCK: input");
            if (run1_bg_gap_viol     > 0) $display("    VIOLATION BLOCK: bg_sub");
            if (run1_klin_gap_viol   > 0) $display("    VIOLATION BLOCK: k_lin");
            if (run1_disp_gap_viol   > 0) $display("    VIOLATION BLOCK: disp_comp");
            if (run1_fft_gap_viol    > 0) $display("    VIOLATION BLOCK: fft");
            if (run1_topsel_gap_viol > 0) $display("    VIOLATION BLOCK: top_select");
            if (run1_mag_gap_viol    > 0) $display("    VIOLATION BLOCK: mag_calc");
            if (run1_final_gap_viol  > 0) $display("    VIOLATION BLOCK: final");
        end else begin
            $display("  input      gap violations = %0d", run2_in_gap_viol);     total_viol = total_viol + run2_in_gap_viol;
            $display("  bg_sub     gap violations = %0d", run2_bg_gap_viol);     total_viol = total_viol + run2_bg_gap_viol;
            $display("  k_lin      gap violations = %0d", run2_klin_gap_viol);   total_viol = total_viol + run2_klin_gap_viol;
            $display("  disp_comp  gap violations = %0d", run2_disp_gap_viol);   total_viol = total_viol + run2_disp_gap_viol;
            $display("  fft        gap violations = %0d", run2_fft_gap_viol);    total_viol = total_viol + run2_fft_gap_viol;
            $display("  top_select gap violations = %0d", run2_topsel_gap_viol); total_viol = total_viol + run2_topsel_gap_viol;
            $display("  mag_calc   gap violations = %0d", run2_mag_gap_viol);    total_viol = total_viol + run2_mag_gap_viol;
            $display("  final      gap violations = %0d", run2_final_gap_viol);  total_viol = total_viol + run2_final_gap_viol;

            if (run2_in_gap_viol     > 0) $display("    VIOLATION BLOCK: input");
            if (run2_bg_gap_viol     > 0) $display("    VIOLATION BLOCK: bg_sub");
            if (run2_klin_gap_viol   > 0) $display("    VIOLATION BLOCK: k_lin");
            if (run2_disp_gap_viol   > 0) $display("    VIOLATION BLOCK: disp_comp");
            if (run2_fft_gap_viol    > 0) $display("    VIOLATION BLOCK: fft");
            if (run2_topsel_gap_viol > 0) $display("    VIOLATION BLOCK: top_select");
            if (run2_mag_gap_viol    > 0) $display("    VIOLATION BLOCK: mag_calc");
            if (run2_final_gap_viol  > 0) $display("    VIOLATION BLOCK: final");
        end

        if (total_viol == 0)
            $display("  RESULT: no streaming gap violations in run %0d", run_id);
        else
            $display("  RESULT: %0d total streaming gap violations in run %0d", total_viol, run_id);
    end
    endtask

    // -------------------------------------------------------------------------
    // Calibration loaders
    // -------------------------------------------------------------------------
    task automatic load_bg;
    begin
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            bg_wr_en   <= 1'b1;
            bg_wr_we   <= 1'b1;
            bg_wr_addr <= i[9:0];
            bg_wr_data <= bg_mem[i];
        end
        @(posedge clk);
        bg_wr_en   <= 1'b0;
        bg_wr_we   <= 1'b0;
        bg_wr_addr <= 10'd0;
        bg_wr_data <= 32'd0;
    end
    endtask

    task automatic load_disp_cos;
    begin
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            disp_a_wr_en   <= 1'b1;
            disp_a_wr_we   <= 1'b1;
            disp_a_wr_addr <= i[9:0];
            disp_a_wr_data <= disp_cos_mem[i];
        end
        @(posedge clk);
        disp_a_wr_en   <= 1'b0;
        disp_a_wr_we   <= 1'b0;
        disp_a_wr_addr <= 10'd0;
        disp_a_wr_data <= 32'd0;
    end
    endtask

    task automatic load_disp_sin;
    begin
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            disp_b_wr_en   <= 1'b1;
            disp_b_wr_we   <= 1'b1;
            disp_b_wr_addr <= i[9:0];
            disp_b_wr_data <= disp_sin_mem[i];
        end
        @(posedge clk);
        disp_b_wr_en   <= 1'b0;
        disp_b_wr_we   <= 1'b0;
        disp_b_wr_addr <= 10'd0;
        disp_b_wr_data <= 32'd0;
    end
    endtask

    task automatic load_klin_all;
    begin
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            klin_a_wr_en   <= 1'b1;
            klin_a_wr_we   <= 1'b1;
            klin_a_wr_addr <= i[9:0];
            klin_a_wr_data <= klin_base_mem[i];

            klin_b_wr_en   <= 1'b1;
            klin_b_wr_we   <= 1'b1;
            klin_b_wr_addr <= i[9:0];
            klin_b_wr_data <= klin_c0_mem[i];

            klin_c_wr_en   <= 1'b1;
            klin_c_wr_we   <= 1'b1;
            klin_c_wr_addr <= i[9:0];
            klin_c_wr_data <= klin_c1_mem[i];

            klin_d_wr_en   <= 1'b1;
            klin_d_wr_we   <= 1'b1;
            klin_d_wr_addr <= i[9:0];
            klin_d_wr_data <= klin_c2_mem[i];

            klin_e_wr_en   <= 1'b1;
            klin_e_wr_we   <= 1'b1;
            klin_e_wr_addr <= i[9:0];
            klin_e_wr_data <= klin_c3_mem[i];
        end

        @(posedge clk);
        klin_a_wr_en <= 1'b0; klin_a_wr_we <= 1'b0; klin_a_wr_addr <= 10'd0; klin_a_wr_data <= 32'd0;
        klin_b_wr_en <= 1'b0; klin_b_wr_we <= 1'b0; klin_b_wr_addr <= 10'd0; klin_b_wr_data <= 32'd0;
        klin_c_wr_en <= 1'b0; klin_c_wr_we <= 1'b0; klin_c_wr_addr <= 10'd0; klin_c_wr_data <= 32'd0;
        klin_d_wr_en <= 1'b0; klin_d_wr_we <= 1'b0; klin_d_wr_addr <= 10'd0; klin_d_wr_data <= 32'd0;
        klin_e_wr_en <= 1'b0; klin_e_wr_we <= 1'b0; klin_e_wr_addr <= 10'd0; klin_e_wr_data <= 32'd0;
    end
    endtask

    task automatic load_all_calibration;
    begin
        $display("[%0t] Loading BG calibration...", $time);
        load_bg();

        $display("[%0t] Loading dispersion cosine LUT...", $time);
        load_disp_cos();

        $display("[%0t] Loading dispersion sine LUT...", $time);
        load_disp_sin();

        $display("[%0t] Loading k-linearization LUTs...", $time);
        load_klin_all();

        @(posedge clk);
        runtime_valid <= 8'hFF;

        $display("[%0t] Calibration load complete. runtime_valid = 0x%02h", $time, 8'hFF);
    end
    endtask

    // -------------------------------------------------------------------------
    // Row sender
    // -------------------------------------------------------------------------
    task automatic send_one_row_same_input(input integer run_id);
    begin
        active_run = run_id;
        $display("[%0t] Sending row for run_id=%0d", $time, run_id);

        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            in_valid     <= 1'b1;
            in_row_start <= (i == 0);
            in_data      <= input_sig_mem[i];
        end

        @(posedge clk);
        in_valid     <= 1'b0;
        in_row_start <= 1'b0;
        in_data      <= 32'd0;
    end
    endtask

    task automatic wait_for_row_done_or_timeout(input integer max_cycles);
        integer cyc;
    begin
        for (cyc = 0; cyc < max_cycles; cyc = cyc + 1) begin
            @(posedge clk);
            if (row_done)
                return;
        end

        $fatal(1, "Timed out waiting for row_done");
    end
    endtask

    // -------------------------------------------------------------------------
    // Dump monitors + first-valid capture + gap checks
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            // nothing
        end else begin

            // -------------------------------------------------------------
            // RUN 1: first-valid capture
            // -------------------------------------------------------------
            if (active_run == 1) begin
                if (stg_in_valid     && !run1_in_seen)     begin run1_in_seen     <= 1'b1; run1_in_first_cycle     <= sim_cycle; end
                if (stg_bg_valid     && !run1_bg_seen)     begin run1_bg_seen     <= 1'b1; run1_bg_first_cycle     <= sim_cycle; end
                if (stg_klin_valid   && !run1_klin_seen)   begin run1_klin_seen   <= 1'b1; run1_klin_first_cycle   <= sim_cycle; end
                if (stg_disp_valid   && !run1_disp_seen)   begin run1_disp_seen   <= 1'b1; run1_disp_first_cycle   <= sim_cycle; end
                if (stg_fft_valid    && !run1_fft_seen)    begin run1_fft_seen    <= 1'b1; run1_fft_first_cycle    <= sim_cycle; end
                if (stg_topsel_valid && !run1_topsel_seen) begin run1_topsel_seen <= 1'b1; run1_topsel_first_cycle <= sim_cycle; end
                if (stg_mag_valid    && !run1_mag_seen)    begin run1_mag_seen    <= 1'b1; run1_mag_first_cycle    <= sim_cycle; end
                if (stg_final_valid  && !run1_final_seen)  begin run1_final_seen  <= 1'b1; run1_final_first_cycle  <= sim_cycle; end
            end

            // -------------------------------------------------------------
            // RUN 2: first-valid capture
            // -------------------------------------------------------------
            if (active_run == 2) begin
                if (stg_in_valid     && !run2_in_seen)     begin run2_in_seen     <= 1'b1; run2_in_first_cycle     <= sim_cycle; end
                if (stg_bg_valid     && !run2_bg_seen)     begin run2_bg_seen     <= 1'b1; run2_bg_first_cycle     <= sim_cycle; end
                if (stg_klin_valid   && !run2_klin_seen)   begin run2_klin_seen   <= 1'b1; run2_klin_first_cycle   <= sim_cycle; end
                if (stg_disp_valid   && !run2_disp_seen)   begin run2_disp_seen   <= 1'b1; run2_disp_first_cycle   <= sim_cycle; end
                if (stg_fft_valid    && !run2_fft_seen)    begin run2_fft_seen    <= 1'b1; run2_fft_first_cycle    <= sim_cycle; end
                if (stg_topsel_valid && !run2_topsel_seen) begin run2_topsel_seen <= 1'b1; run2_topsel_first_cycle <= sim_cycle; end
                if (stg_mag_valid    && !run2_mag_seen)    begin run2_mag_seen    <= 1'b1; run2_mag_first_cycle    <= sim_cycle; end
                if (stg_final_valid  && !run2_final_seen)  begin run2_final_seen  <= 1'b1; run2_final_first_cycle  <= sim_cycle; end
            end

            // -------------------------------------------------------------
            // RUN 1: gap checks
            // -------------------------------------------------------------
            if (active_run == 1) begin
                if (stg_in_valid) begin
                    if (run1_in_last_cycle >= 0 && (sim_cycle - run1_in_last_cycle) > 1) begin
                        run1_in_gap_viol <= run1_in_gap_viol + 1;
                        $display("[RUN1][STREAM GAP] input gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run1_in_last_cycle, sim_cycle);
                    end
                    run1_in_last_cycle <= sim_cycle;
                end

                if (stg_bg_valid) begin
                    if (run1_bg_last_cycle >= 0 && (sim_cycle - run1_bg_last_cycle) > 1) begin
                        run1_bg_gap_viol <= run1_bg_gap_viol + 1;
                        $display("[RUN1][STREAM GAP] bg_sub gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run1_bg_last_cycle, sim_cycle);
                    end
                    run1_bg_last_cycle <= sim_cycle;
                end

                if (stg_klin_valid) begin
                    if (run1_klin_last_cycle >= 0 && (sim_cycle - run1_klin_last_cycle) > 1) begin
                        run1_klin_gap_viol <= run1_klin_gap_viol + 1;
                        $display("[RUN1][STREAM GAP] k_lin gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run1_klin_last_cycle, sim_cycle);
                    end
                    run1_klin_last_cycle <= sim_cycle;
                end

                if (stg_disp_valid) begin
                    if (run1_disp_last_cycle >= 0 && (sim_cycle - run1_disp_last_cycle) > 1) begin
                        run1_disp_gap_viol <= run1_disp_gap_viol + 1;
                        $display("[RUN1][STREAM GAP] disp_comp gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run1_disp_last_cycle, sim_cycle);
                    end
                    run1_disp_last_cycle <= sim_cycle;
                end

                if (stg_fft_valid) begin
                    if (run1_fft_last_cycle >= 0 && (sim_cycle - run1_fft_last_cycle) > 1) begin
                        run1_fft_gap_viol <= run1_fft_gap_viol + 1;
                        $display("[RUN1][STREAM GAP] fft gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run1_fft_last_cycle, sim_cycle);
                    end
                    run1_fft_last_cycle <= sim_cycle;
                end

                if (stg_topsel_valid) begin
                    if (run1_topsel_last_cycle >= 0 && (sim_cycle - run1_topsel_last_cycle) > 1) begin
                        run1_topsel_gap_viol <= run1_topsel_gap_viol + 1;
                        $display("[RUN1][STREAM GAP] top_select gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run1_topsel_last_cycle, sim_cycle);
                    end
                    run1_topsel_last_cycle <= sim_cycle;
                end

                if (stg_mag_valid) begin
                    if (run1_mag_last_cycle >= 0 && (sim_cycle - run1_mag_last_cycle) > 1) begin
                        run1_mag_gap_viol <= run1_mag_gap_viol + 1;
                        $display("[RUN1][STREAM GAP] mag_calc gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run1_mag_last_cycle, sim_cycle);
                    end
                    run1_mag_last_cycle <= sim_cycle;
                end

                if (stg_final_valid) begin
                    if (run1_final_last_cycle >= 0 && (sim_cycle - run1_final_last_cycle) > 1) begin
                        run1_final_gap_viol <= run1_final_gap_viol + 1;
                        $display("[RUN1][STREAM GAP] final gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run1_final_last_cycle, sim_cycle);
                    end
                    run1_final_last_cycle <= sim_cycle;
                end
            end

            // -------------------------------------------------------------
            // RUN 2: gap checks
            // -------------------------------------------------------------
            if (active_run == 2) begin
                if (stg_in_valid) begin
                    if (run2_in_last_cycle >= 0 && (sim_cycle - run2_in_last_cycle) > 1) begin
                        run2_in_gap_viol <= run2_in_gap_viol + 1;
                        $display("[RUN2][STREAM GAP] input gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run2_in_last_cycle, sim_cycle);
                    end
                    run2_in_last_cycle <= sim_cycle;
                end

                if (stg_bg_valid) begin
                    if (run2_bg_last_cycle >= 0 && (sim_cycle - run2_bg_last_cycle) > 1) begin
                        run2_bg_gap_viol <= run2_bg_gap_viol + 1;
                        $display("[RUN2][STREAM GAP] bg_sub gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run2_bg_last_cycle, sim_cycle);
                    end
                    run2_bg_last_cycle <= sim_cycle;
                end

                if (stg_klin_valid) begin
                    if (run2_klin_last_cycle >= 0 && (sim_cycle - run2_klin_last_cycle) > 1) begin
                        run2_klin_gap_viol <= run2_klin_gap_viol + 1;
                        $display("[RUN2][STREAM GAP] k_lin gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run2_klin_last_cycle, sim_cycle);
                    end
                    run2_klin_last_cycle <= sim_cycle;
                end

                if (stg_disp_valid) begin
                    if (run2_disp_last_cycle >= 0 && (sim_cycle - run2_disp_last_cycle) > 1) begin
                        run2_disp_gap_viol <= run2_disp_gap_viol + 1;
                        $display("[RUN2][STREAM GAP] disp_comp gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run2_disp_last_cycle, sim_cycle);
                    end
                    run2_disp_last_cycle <= sim_cycle;
                end

                if (stg_fft_valid) begin
                    if (run2_fft_last_cycle >= 0 && (sim_cycle - run2_fft_last_cycle) > 1) begin
                        run2_fft_gap_viol <= run2_fft_gap_viol + 1;
                        $display("[RUN2][STREAM GAP] fft gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run2_fft_last_cycle, sim_cycle);
                    end
                    run2_fft_last_cycle <= sim_cycle;
                end

                if (stg_topsel_valid) begin
                    if (run2_topsel_last_cycle >= 0 && (sim_cycle - run2_topsel_last_cycle) > 1) begin
                        run2_topsel_gap_viol <= run2_topsel_gap_viol + 1;
                        $display("[RUN2][STREAM GAP] top_select gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run2_topsel_last_cycle, sim_cycle);
                    end
                    run2_topsel_last_cycle <= sim_cycle;
                end

                if (stg_mag_valid) begin
                    if (run2_mag_last_cycle >= 0 && (sim_cycle - run2_mag_last_cycle) > 1) begin
                        run2_mag_gap_viol <= run2_mag_gap_viol + 1;
                        $display("[RUN2][STREAM GAP] mag_calc gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run2_mag_last_cycle, sim_cycle);
                    end
                    run2_mag_last_cycle <= sim_cycle;
                end

                if (stg_final_valid) begin
                    if (run2_final_last_cycle >= 0 && (sim_cycle - run2_final_last_cycle) > 1) begin
                        run2_final_gap_viol <= run2_final_gap_viol + 1;
                        $display("[RUN2][STREAM GAP] final gap=%0d cycles at sim_cycle=%0d",
                                 sim_cycle - run2_final_last_cycle, sim_cycle);
                    end
                    run2_final_last_cycle <= sim_cycle;
                end
            end

            // -------------------------------------------------------------
            // Original dump monitors
            // -------------------------------------------------------------
            if (in_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_in, "%08X\n", in_data);
                    pre_in_count <= pre_in_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_in, "%08X\n", in_data);
                    post_in_count <= post_in_count + 1;
                end
            end

            if (dut.bgsub_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_bg, "%08X\n", dut.bgsub_out_str);
                    pre_bg_count <= pre_bg_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_bg, "%08X\n", dut.bgsub_out_str);
                    post_bg_count <= post_bg_count + 1;
                end
            end

            if (dut.klin_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_klin, "%08X\n", dut.klin_out_str);
                    pre_klin_count <= pre_klin_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_klin, "%08X\n", dut.klin_out_str);
                    post_klin_count <= post_klin_count + 1;
                end
            end

            if (dut.disp_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_disp, "%08X %08X\n", dut.disp_out_re, dut.disp_out_im);
                    pre_disp_count <= pre_disp_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_disp, "%08X %08X\n", dut.disp_out_re, dut.disp_out_im);
                    post_disp_count <= post_disp_count + 1;
                end
            end

            if (dut.fft_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_fft, "%08X %08X\n", dut.fft_out_real, dut.fft_out_imag);
                    pre_fft_count <= pre_fft_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_fft, "%08X %08X\n", dut.fft_out_real, dut.fft_out_imag);
                    post_fft_count <= post_fft_count + 1;
                end
            end

            if (dut.topsel_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_topsel, "%08X %08X\n", dut.topsel_out_real, dut.topsel_out_imag);
                    pre_topsel_count <= pre_topsel_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_topsel, "%08X %08X\n", dut.topsel_out_real, dut.topsel_out_imag);
                    post_topsel_count <= post_topsel_count + 1;
                end
            end

            if (dut.mag_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_mag, "%017X\n", dut.mag_out);
                    pre_mag_count <= pre_mag_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_mag, "%017X\n", dut.mag_out);
                    post_mag_count <= post_mag_count + 1;
                end
            end

            if (out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_final, "%08X\n", out_data);
                    pre_final_count <= pre_final_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_final, "%08X\n", out_data);
                    post_final_count <= post_final_count + 1;
                end
            end

            if (row_done) begin
                if (active_run == 1)
                    pre_rowdone_count <= pre_rowdone_count + 1;
                else if (active_run == 2)
                    post_rowdone_count <= post_rowdone_count + 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Main sequence
    // -------------------------------------------------------------------------
    initial begin
        clear_inputs();
        reset_counters();
        reset_stream_checks();
        open_dump_files();

        $readmemh("C:/Users/ifean/fpga_dev/octogen/scripts/ignore/bg.mem",        bg_mem);
        $readmemh("C:/Users/ifean/fpga_dev/octogen/scripts/ignore/disp_cos.mem",  disp_cos_mem);
        $readmemh("C:/Users/ifean/fpga_dev/octogen/scripts/ignore/disp_sin.mem",  disp_sin_mem);
        $readmemh("C:/Users/ifean/fpga_dev/octogen/scripts/ignore/klin_base.mem", klin_base_mem);
        $readmemh("C:/Users/ifean/fpga_dev/octogen/scripts/ignore/klin_c0.mem",   klin_c0_mem);
        $readmemh("C:/Users/ifean/fpga_dev/octogen/scripts/ignore/klin_c1.mem",   klin_c1_mem);
        $readmemh("C:/Users/ifean/fpga_dev/octogen/scripts/ignore/klin_c2.mem",   klin_c2_mem);
        $readmemh("C:/Users/ifean/fpga_dev/octogen/scripts/ignore/klin_c3.mem",   klin_c3_mem);
        $readmemh("C:/Users/ifean/fpga_dev/octogen/scripts/ignore/input_sig.mem", input_sig_mem);

        $display("bg_mem[0]        = %08X", bg_mem[0]);
        $display("disp_cos_mem[0]  = %08X", disp_cos_mem[0]);
        $display("disp_sin_mem[0]  = %08X", disp_sin_mem[0]);
        $display("klin_base_mem[0] = %08X", klin_base_mem[0]);
        $display("input_sig_mem[0] = %08X", input_sig_mem[0]);

        $display("==================================================");
        $display("TB: dsp_core calibration compare + streaming checks");
        $display("==================================================");

        pulse_reset();

        // -------------------------------------------------------------
        // RUN 1
        // -------------------------------------------------------------
        runtime_valid <= 8'h00;
        wait_clk(4);

        $display("--------------------------------------------------");
        $display("RUN 1: pre-calibration row");
        $display("--------------------------------------------------");

        send_one_row_same_input(1);
        wait_for_row_done_or_timeout(500000);
        wait_clk(20);

        active_run = 0;
        wait_clk(10);

        report_run_latency(1);
        report_run_streaming(1);

        // -------------------------------------------------------------
        // CALIBRATION LOAD
        // -------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("CALIBRATION LOAD");
        $display("--------------------------------------------------");

        load_all_calibration();
        wait_clk(20);

        // -------------------------------------------------------------
        // RUN 2
        // -------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("RUN 2: post-calibration row");
        $display("--------------------------------------------------");

        send_one_row_same_input(2);
        wait_for_row_done_or_timeout(500000);
        wait_clk(20);

        active_run = 0;
        wait_clk(10);

        report_run_latency(2);
        report_run_streaming(2);

        // -------------------------------------------------------------
        // Summary
        // -------------------------------------------------------------
        $display("==================================================");
        $display("SUMMARY");
        $display("==================================================");

        $display("PRE-CAL COUNTS:");
        $display("  input   = %0d", pre_in_count);
        $display("  bg      = %0d", pre_bg_count);
        $display("  klin    = %0d", pre_klin_count);
        $display("  disp    = %0d", pre_disp_count);
        $display("  fft     = %0d", pre_fft_count);
        $display("  topsel  = %0d", pre_topsel_count);
        $display("  mag     = %0d", pre_mag_count);
        $display("  final   = %0d", pre_final_count);
        $display("  rowdone = %0d", pre_rowdone_count);

        $display("POST-CAL COUNTS:");
        $display("  input   = %0d", post_in_count);
        $display("  bg      = %0d", post_bg_count);
        $display("  klin    = %0d", post_klin_count);
        $display("  disp    = %0d", post_disp_count);
        $display("  fft     = %0d", post_fft_count);
        $display("  topsel  = %0d", post_topsel_count);
        $display("  mag     = %0d", post_mag_count);
        $display("  final   = %0d", post_final_count);
        $display("  rowdone = %0d", post_rowdone_count);

        $display("Files generated:");
        $display("  pre_input.txt      post_input.txt");
        $display("  pre_bg_out.txt     post_bg_out.txt");
        $display("  pre_klin_out.txt   post_klin_out.txt");
        $display("  pre_disp_out.txt   post_disp_out.txt");
        $display("  pre_fft_out.txt    post_fft_out.txt");
        $display("  pre_topsel_out.txt post_topsel_out.txt");
        $display("  pre_mag_out.txt    post_mag_out.txt");
        $display("  pre_final_out.txt  post_final_out.txt");

        close_dump_files();

        $display("TB COMPLETE");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout
    // -------------------------------------------------------------------------
    initial begin
        #100000000;
        $fatal(1, "TB TIMEOUT");
    end

endmodule

