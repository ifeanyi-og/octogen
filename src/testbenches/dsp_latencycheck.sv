`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/06/2026 11:54:51 PM
// Design Name: 
// Module Name: dsp_latencycheck
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
    // 0 = no dump yet
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
    // Dump monitors
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            // input stream
            if (in_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_in, "%08X\n", in_data);
                    pre_in_count <= pre_in_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_in, "%08X\n", in_data);
                    post_in_count <= post_in_count + 1;
                end
            end

            // bg_sub
            if (dut.bgsub_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_bg, "%08X\n", dut.bgsub_out_str);
                    pre_bg_count <= pre_bg_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_bg, "%08X\n", dut.bgsub_out_str);
                    post_bg_count <= post_bg_count + 1;
                end
            end

            // k_lin
            if (dut.klin_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_klin, "%08X\n", dut.klin_out_str);
                    pre_klin_count <= pre_klin_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_klin, "%08X\n", dut.klin_out_str);
                    post_klin_count <= post_klin_count + 1;
                end
            end

            // disp_comp
            if (dut.disp_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_disp, "%08X %08X\n", dut.disp_out_re, dut.disp_out_im);
                    pre_disp_count <= pre_disp_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_disp, "%08X %08X\n", dut.disp_out_re, dut.disp_out_im);
                    post_disp_count <= post_disp_count + 1;
                end
            end

            // fft
            if (dut.fft_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_fft, "%08X %08X\n", dut.fft_out_real, dut.fft_out_imag);
                    pre_fft_count <= pre_fft_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_fft, "%08X %08X\n", dut.fft_out_real, dut.fft_out_imag);
                    post_fft_count <= post_fft_count + 1;
                end
            end

            // top_select
            if (dut.topsel_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_topsel, "%08X %08X\n", dut.topsel_out_real, dut.topsel_out_imag);
                    pre_topsel_count <= pre_topsel_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_topsel, "%08X %08X\n", dut.topsel_out_real, dut.topsel_out_imag);
                    post_topsel_count <= post_topsel_count + 1;
                end
            end

            // mag
            if (dut.mag_out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_mag, "%017X\n", dut.mag_out);
                    pre_mag_count <= pre_mag_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_mag, "%017X\n", dut.mag_out);
                    post_mag_count <= post_mag_count + 1;
                end
            end

            // final
            if (out_valid) begin
                if (active_run == 1) begin
                    $fwrite(f_pre_final, "%08X\n", out_data);
                    pre_final_count <= pre_final_count + 1;
                end else if (active_run == 2) begin
                    $fwrite(f_post_final, "%08X\n", out_data);
                    post_final_count <= post_final_count + 1;
                end
            end

            // row done count
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
        open_dump_files();

        // mem files
        // Adjust these if your simulation working directory differs.
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
        $display("TB: dsp_core calibration compare");
        $display("==================================================");

        pulse_reset();

        // -------------------------------------------------------------
        // RUN 1: before calibration
        // -------------------------------------------------------------
        runtime_valid <= 8'h00;
        wait_clk(4);

        $display("--------------------------------------------------");
        $display("RUN 1: pre-calibration row");
        $display("--------------------------------------------------");

        send_one_row_same_input(1);
        wait_for_row_done_or_timeout(500000);
        wait_clk(20);

        // idle before calibration load
        active_run = 0;
        wait_clk(10);

        // -------------------------------------------------------------
        // CALIBRATION LOAD
        // -------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("CALIBRATION LOAD");
        $display("--------------------------------------------------");

        load_all_calibration();
        wait_clk(20);

        // -------------------------------------------------------------
        // RUN 2: after calibration
        // -------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("RUN 2: post-calibration row");
        $display("--------------------------------------------------");

        send_one_row_same_input(2);
        wait_for_row_done_or_timeout(500000);
        wait_clk(20);

        active_run = 0;
        wait_clk(10);

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

        $display("Expected rough structure:");
        $display("  input/bg/klin/disp/fft  ~= 1024 samples");
        $display("  topsel/mag/final        ~= 512 samples");
        $display("  rowdone                 = 1 per run");

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
