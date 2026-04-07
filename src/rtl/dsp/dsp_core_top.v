
`timescale 1ns / 1ps
// =============================================================================
// dsp_core
//
// Streaming DSP chain:
//   in -> bg_sub -> k_lin -> disp_comp -> fft_wrapper
//      -> top_select(first 512 complex bins) -> mag_calc -> log_compress_map
//
// External ports intentionally preserved.
//
// Notes:
// - bg_sub:        real 32-bit in  -> real 32-bit out
// - k_lin:         real 32-bit in  -> real 32-bit out
// - disp_comp:     real 32-bit in  -> complex 32-bit out
// - fft_wrapper:   complex 32-bit in -> complex 32-bit out
// - top_select:    complex 32-bit in -> complex 32-bit out
// - mag_calc:      complex 32-bit in -> unsigned 65-bit out
// - log_map:       65-bit in -> 8-bit pixel out
//
// Final output mapping:
// - out_data[7:0] = pixel intensity
// - out_data[31:8] = 0
// =============================================================================

module dsp_core_top #(
    parameter integer IN_SAMPLES_PER_ROW  = 1024,
    parameter integer OUT_SAMPLES_PER_ROW = 512
) (
    input  wire        clk,
    input  wire        rst,

    // -------------------------------------------------------------------------
    // DSP input stream
    // -------------------------------------------------------------------------
    input  wire        in_valid,
    input  wire        in_row_start,
    input  wire [31:0] in_data,

    // -------------------------------------------------------------------------
    // Calibration status / validity
    // -------------------------------------------------------------------------
    input  wire [7:0]  runtime_valid,

    // -------------------------------------------------------------------------
    // Calibration BRAM write buses
    // -------------------------------------------------------------------------
    input  wire        bg_wr_en,
    input  wire [0:0]  bg_wr_we,
    input  wire [9:0]  bg_wr_addr,
    input  wire [31:0] bg_wr_data,

    input  wire        disp_a_wr_en,
    input  wire [0:0]  disp_a_wr_we,
    input  wire [9:0]  disp_a_wr_addr,
    input  wire [31:0] disp_a_wr_data,

    input  wire        disp_b_wr_en,
    input  wire [0:0]  disp_b_wr_we,
    input  wire [9:0]  disp_b_wr_addr,
    input  wire [31:0] disp_b_wr_data,

    input  wire        klin_a_wr_en,
    input  wire [0:0]  klin_a_wr_we,
    input  wire [9:0]  klin_a_wr_addr,
    input  wire [31:0] klin_a_wr_data,

    input  wire        klin_b_wr_en,
    input  wire [0:0]  klin_b_wr_we,
    input  wire [9:0]  klin_b_wr_addr,
    input  wire [31:0] klin_b_wr_data,

    input  wire        klin_c_wr_en,
    input  wire [0:0]  klin_c_wr_we,
    input  wire [9:0]  klin_c_wr_addr,
    input  wire [31:0] klin_c_wr_data,

    input  wire        klin_d_wr_en,
    input  wire [0:0]  klin_d_wr_we,
    input  wire [9:0]  klin_d_wr_addr,
    input  wire [31:0] klin_d_wr_data,

    input  wire        klin_e_wr_en,
    input  wire [0:0]  klin_e_wr_we,
    input  wire [9:0]  klin_e_wr_addr,
    input  wire [31:0] klin_e_wr_data,

    // -------------------------------------------------------------------------
    // DSP output stream
    // -------------------------------------------------------------------------
    output reg         out_valid,
    output reg         out_row_start,
    output reg  [31:0] out_data,

    // -------------------------------------------------------------------------
    // Status
    // -------------------------------------------------------------------------
    output wire        busy,
    output reg         row_done
);

    // =========================================================================
    // Stage 1: bg_sub
    // =========================================================================
    wire [31:0] bgsub_out_str;
    wire        bgsub_out_valid;
    wire        bgsub_out_start;

    bg_sub #(
        .ASCAN_LEN(IN_SAMPLES_PER_ROW),
        .ADDR_W   (10)
    ) u_bg_sub (
        .clk                (clk),
        .rst                (rst),

        .str_in             (in_data),
        .str_in_valid       (in_valid),
        .start_of_ascan     (in_row_start),

        .bg_wr_en           (bg_wr_en),
        .bg_wr_we           (bg_wr_we),
        .bg_wr_addr         (bg_wr_addr),
        .bg_wr_data         (bg_wr_data),

        .str_out            (bgsub_out_str),
        .str_out_valid      (bgsub_out_valid),
        .start_of_ascan_out (bgsub_out_start)
    );

    // =========================================================================
    // Stage 2: k_lin
    // =========================================================================
    wire [31:0] klin_out_str;
    wire        klin_out_valid;
    wire        klin_out_start;
    wire        klin_overflow;

    k_lin #(
        .ASCAN_LEN (IN_SAMPLES_PER_ROW),
        .ADDR_W    (10),
        .COEF_W    (18),
        .FRAC_BITS (16),
        .COEF_LAT  (2),
        .SAMP_LAT  (2)
    ) u_k_lin (
        .clk                 (clk),
        .rst                 (rst),

        .str_in              (bgsub_out_str),
        .str_in_valid        (bgsub_out_valid),
        .start_of_ascan      (bgsub_out_start),

        .str_out             (klin_out_str),
        .str_out_valid       (klin_out_valid),
        .start_of_ascan_out  (klin_out_start),

        // Assumption: runtime_valid[1] corresponds to k-lin calibration readiness
        .cal_ready           (1'b1),
        .cal_write_addr      (klin_a_wr_addr),

        .cal_base_write_en   (klin_a_wr_en & klin_a_wr_we[0]),
        .cal_base_write_data (klin_a_wr_data[9:0]),

        .cal_c0_write_en     (klin_b_wr_en & klin_b_wr_we[0]),
        .cal_c0_write_data   (klin_b_wr_data[17:0]),

        .cal_c1_write_en     (klin_c_wr_en & klin_c_wr_we[0]),
        .cal_c1_write_data   (klin_c_wr_data[17:0]),

        .cal_c2_write_en     (klin_d_wr_en & klin_d_wr_we[0]),
        .cal_c2_write_data   (klin_d_wr_data[17:0]),

        .cal_c3_write_en     (klin_e_wr_en & klin_e_wr_we[0]),
        .cal_c3_write_data   (klin_e_wr_data[17:0]),

        .overflow            (klin_overflow)
    );

    // =========================================================================
    // Stage 3: disp_comp
    // =========================================================================
    wire [31:0] disp_out_re;
    wire [31:0] disp_out_im;
    wire        disp_out_valid;
    wire        disp_out_start;
    wire        disp_out_end;

    disp_comp #(
        .ASCAN_LEN (IN_SAMPLES_PER_ROW),
        .ADDR_W    (10),
        .IN_W      (32),
        .X_W       (24),
        .LUT_W     (18),
        .LUT_FRAC  (17),
        .SHIFT_IN  (8),
        .RAM_LAT   (1)
    ) u_disp_comp (
        .clk                (clk),
        .rst                (rst),

        .in_x               (klin_out_str),
        .in_valid           (klin_out_valid),
        .start_of_ascan     (klin_out_start),

        .lut_cos_wr_en   (disp_a_wr_en & disp_a_wr_we[0]),
        .lut_cos_wr_addr (disp_a_wr_addr),
        .lut_cos_din     (disp_a_wr_data[17:0]),
        
        .lut_sin_wr_en   (disp_b_wr_en & disp_b_wr_we[0]),
        .lut_sin_wr_addr (disp_b_wr_addr),
        .lut_sin_din     (disp_b_wr_data[17:0]),

        .out_re             (disp_out_re),
        .out_im             (disp_out_im),
        .out_valid          (disp_out_valid),
        .start_of_ascan_out (disp_out_start),
        .end_of_ascan_out   (disp_out_end)
    );

    // =========================================================================
    // Stage 4: fft_wrapper
    // =========================================================================
    wire signed [31:0] fft_out_real;
    wire signed [31:0] fft_out_imag;
    wire               fft_out_valid;
    wire               fft_out_start;

    wire dbg_event_frame_started;
    wire dbg_event_tlast_unexpected;
    wire dbg_event_tlast_missing;
    wire dbg_event_status_channel_halt;
    wire dbg_event_data_in_channel_halt;
    wire dbg_event_data_out_channel_halt;
    wire dbg_cfg_done;
    wire dbg_input_backpressure_violation;

    fft_dummy u_fft_wrapper (
        .clk                             (clk),
        .rst                             (rst),

        .in_real                         ($signed(disp_out_re)),
        .in_imag                         ($signed(disp_out_im)),
        .in_valid                        (disp_out_valid),
        .start_of_ascan                  (disp_out_start),
        .end_of_ascan                    (disp_out_end),

        .out_real                        (fft_out_real),
        .out_imag                        (fft_out_imag),
        .out_valid                       (fft_out_valid),
        .start_of_ascan_out              (fft_out_start),

        .dbg_event_frame_started         (dbg_event_frame_started),
        .dbg_event_tlast_unexpected      (dbg_event_tlast_unexpected),
        .dbg_event_tlast_missing         (dbg_event_tlast_missing),
        .dbg_event_status_channel_halt   (dbg_event_status_channel_halt),
        .dbg_event_data_in_channel_halt  (dbg_event_data_in_channel_halt),
        .dbg_event_data_out_channel_halt (dbg_event_data_out_channel_halt),
        .dbg_cfg_done                    (dbg_cfg_done),
        .dbg_input_backpressure_violation(dbg_input_backpressure_violation)
    );

    // =========================================================================
    // Stage 5: top_select
    // =========================================================================
    wire signed [31:0] topsel_out_real;
    wire signed [31:0] topsel_out_imag;
    wire               topsel_out_valid;
    wire               topsel_out_start;

    top_select #(
        .DATA_W    (32),
        .ASCAN_LEN (IN_SAMPLES_PER_ROW),
        .KEEP_LEN  (OUT_SAMPLES_PER_ROW),
        .COUNT_W   (10)
    ) u_top_select (
        .clk                (clk),
        .rst                (rst),

        .re_in              (fft_out_real),
        .im_in              (fft_out_imag),
        .in_valid           (fft_out_valid),
        .start_of_ascan     (fft_out_start),

        .re_out             (topsel_out_real),
        .im_out             (topsel_out_imag),
        .out_valid          (topsel_out_valid),
        .start_of_ascan_out (topsel_out_start)
    );

    // =========================================================================
    // Stage 6: mag_calc
    // =========================================================================
    wire [64:0] mag_out;
    wire        mag_out_valid;
    wire        mag_out_start;

    mag_calc u_mag_calc (
        .clk                (clk),
        .rst                (rst),

        .re_in              (topsel_out_real),
        .im_in              (topsel_out_imag),
        .in_valid           (topsel_out_valid),
        .start_of_ascan     (topsel_out_start),

        .mag_sq_out         (mag_out),
        .out_valid          (mag_out_valid),
        .start_of_ascan_out (mag_out_start)
    );

    // =========================================================================
    // Stage 7: log_compress_map
    // =========================================================================
    wire       log_pix_valid;
    wire       log_pix_start;
    wire [7:0] log_pix_out;

    log_compress_map #(
        .IN_W          (65),
        .SEG_BITS      (6),
        .FRAC_BITS     (6),
        .LUT_W         (18),
        .MAP_FLOOR_Q   (131072),
        .MAP_GAIN_Q    (1024),
        .MAP_GAIN_FRAC (8),
        .GAIN_W        (16)
    ) u_log_compress_map (
        .clk                (clk),
        .rst                (rst),

        .in_valid           (mag_out_valid),
        .start_of_ascan     (mag_out_start),
        .mag2_in            (mag_out),

        .pix_valid          (log_pix_valid),
        .start_of_ascan_out (log_pix_start),
        .pix_out            (log_pix_out)
    );

    // =========================================================================
    // Final output mapping
    // =========================================================================
    always @(*) begin
        out_valid     = log_pix_valid;
        out_row_start = log_pix_start;
        out_data      = {24'd0, log_pix_out};
    end

    // =========================================================================
    // busy: asserted from row ingress until final output row completion
    // =========================================================================
    reg row_active_in;
    reg [9:0] in_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            row_active_in <= 1'b0;
            in_count      <= 10'd0;
        end else begin
            if (!row_active_in) begin
                if (in_valid && in_row_start) begin
                    row_active_in <= 1'b1;
                    in_count      <= 10'd1;
                end
            end else if (in_valid) begin
                if (in_count == IN_SAMPLES_PER_ROW-1)
                    in_count <= 10'd0;
                else
                    in_count <= in_count + 10'd1;
            end

            if (row_done)
                row_active_in <= 1'b0;
        end
    end

    assign busy = row_active_in;

    // =========================================================================
    // row_done: pulse on final emitted output pixel of the kept 512-bin stream
    // =========================================================================
    reg [8:0] out_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_count <= 9'd0;
            row_done  <= 1'b0;
        end else begin
            row_done <= 1'b0;

            if (log_pix_valid) begin
                if (log_pix_start) begin
                    if (OUT_SAMPLES_PER_ROW == 1) begin
                        out_count <= 9'd0;
                        row_done  <= 1'b1;
                    end else begin
                        out_count <= 9'd1;
                    end
                end else begin
                    if (out_count == OUT_SAMPLES_PER_ROW-1) begin
                        out_count <= 9'd0;
                        row_done  <= 1'b1;
                    end else begin
                        out_count <= out_count + 9'd1;
                    end
                end
            end
        end
    end

endmodule

