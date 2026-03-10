`timescale 1ns / 1ps
// =============================================================================
// Module: dsp_core_top
// Description: DSP processing pipeline wrapper.
//
// Accepts a continuous stream of 512 complex samples per row (no gaps).
// in_row_start pulses high on the first sample of each row.
// out_valid pulses high for each output sample; latency is not fixed.
//
// This module is a parameterisable placeholder with a configurable
// pipeline delay.  Replace the shift-register delay chain with the
// real DSP algorithm.
// =============================================================================

module dsp_core_top #(
    parameter PIPELINE_LATENCY = 8   // cycles from input to output (tunable)
) (
    input  wire        clk,
    input  wire        rst,

    // ---- Input stream ----
    input  wire        in_valid,
    input  wire        in_row_start,
    input  wire [31:0] in_re,
    input  wire [31:0] in_im,

    // ---- Output stream ----
    output wire        out_valid,
    output wire [31:0] out_re,
    output wire [31:0] out_im,

    // ---- Optional status ----
    output wire        busy,       // asserted while a row is in-flight
    output wire        row_done    // one-cycle pulse when last output sample emitted
);

    // -------------------------------------------------------------------------
    // Shift-register pipeline (placeholder for real DSP)
    // -------------------------------------------------------------------------
    reg [31:0] pipe_re    [0:PIPELINE_LATENCY-1];
    reg [31:0] pipe_im    [0:PIPELINE_LATENCY-1];
    reg        pipe_valid [0:PIPELINE_LATENCY-1];

    integer k;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (k = 0; k < PIPELINE_LATENCY; k = k + 1) begin
                pipe_re[k]    <= 32'd0;
                pipe_im[k]    <= 32'd0;
                pipe_valid[k] <= 1'b0;
            end
        end else begin
            pipe_re[0]    <= in_re;
            pipe_im[0]    <= in_im;
            pipe_valid[0] <= in_valid;
            for (k = 1; k < PIPELINE_LATENCY; k = k + 1) begin
                pipe_re[k]    <= pipe_re[k-1];
                pipe_im[k]    <= pipe_im[k-1];
                pipe_valid[k] <= pipe_valid[k-1];
            end
        end
    end

    assign out_valid = pipe_valid[PIPELINE_LATENCY-1];
    assign out_re    = pipe_re[PIPELINE_LATENCY-1];
    assign out_im    = pipe_im[PIPELINE_LATENCY-1];

    // -------------------------------------------------------------------------
    // Busy / row_done tracking
    // -------------------------------------------------------------------------
    reg [9:0] in_cnt;    // counts input samples per row
    reg [9:0] out_cnt;   // counts output samples per row
    reg       busy_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            in_cnt  <= 10'd0;
            out_cnt <= 10'd0;
            busy_r  <= 1'b0;
        end else begin
            if (in_valid) begin
                if (in_row_start) begin
                    in_cnt <= 10'd1;
                    busy_r <= 1'b1;
                end else begin
                    in_cnt <= in_cnt + 10'd1;
                end
            end

            if (out_valid) begin
                if (out_cnt == 10'd511) begin
                    out_cnt <= 10'd0;
                    busy_r  <= 1'b0;
                end else begin
                    out_cnt <= out_cnt + 10'd1;
                end
            end
        end
    end

    assign busy     = busy_r;
    assign row_done = out_valid & (out_cnt == 10'd511);

endmodule

