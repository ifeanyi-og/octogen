`timescale 1ns / 1ps
// =============================================================================
// dsp_core_top
//
// Placeholder real-only DSP chain.
//
// Behavior:
// - Accepts 1024 real samples per row
// - Emits 512 real samples per row
// - Current placeholder "DSP" = decimate-by-2 (keep even-indexed samples)
// - A latency pipe is kept after decimation so more DSP blocks can be inserted
//   in front of / behind the decimator cleanly later
// =============================================================================

module dsp_core_top #(
    parameter integer PIPELINE_LATENCY = 8
) (
    input  wire        clk,
    input  wire        rst,

    // ---- Input stream ----
    input  wire        in_valid,
    input  wire        in_row_start,
    input  wire [31:0] in_data,

    // ---- Output stream ----
    output wire        out_valid,
    output wire [31:0] out_data,

    // ---- Optional status ----
    output wire        busy,
    output wire        row_done
);

    localparam integer IN_SAMPLES_PER_ROW  = 1024;
    localparam integer OUT_SAMPLES_PER_ROW = 512;

    // -------------------------------------------------------------------------
    // Front-end sample index / row tracking
    // -------------------------------------------------------------------------
    reg [9:0] in_sample_idx;
    reg [8:0] out_sample_idx;
    reg       busy_r;

    wire take_input = in_valid;
    wire keep_sample = take_input && (in_sample_idx[0] == 1'b0); // even samples only

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            in_sample_idx  <= 10'd0;
            out_sample_idx <= 9'd0;
            busy_r         <= 1'b0;
        end else begin
            if (take_input) begin
                if (in_row_start) begin
                    in_sample_idx  <= 10'd1;
                    out_sample_idx <= 9'd0;
                    busy_r         <= 1'b1;
                end else begin
                    if (in_sample_idx == IN_SAMPLES_PER_ROW-1)
                        in_sample_idx <= 10'd0;
                    else
                        in_sample_idx <= in_sample_idx + 10'd1;
                end
            end

            if (out_valid) begin
                if (out_sample_idx == OUT_SAMPLES_PER_ROW-1) begin
                    out_sample_idx <= 9'd0;
                    busy_r         <= 1'b0;
                end else begin
                    out_sample_idx <= out_sample_idx + 9'd1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Decimator output into latency pipeline
    // -------------------------------------------------------------------------
    reg [31:0] pipe_data  [0:PIPELINE_LATENCY-1];
    reg        pipe_valid [0:PIPELINE_LATENCY-1];

    integer k;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (k = 0; k < PIPELINE_LATENCY; k = k + 1) begin
                pipe_data[k]  <= 32'd0;
                pipe_valid[k] <= 1'b0;
            end
        end else begin
            pipe_data[0]  <= in_data;
            pipe_valid[0] <= keep_sample;

            for (k = 1; k < PIPELINE_LATENCY; k = k + 1) begin
                pipe_data[k]  <= pipe_data[k-1];
                pipe_valid[k] <= pipe_valid[k-1];
            end
        end
    end

    assign out_valid = pipe_valid[PIPELINE_LATENCY-1];
    assign out_data  = pipe_data[PIPELINE_LATENCY-1];

    assign busy     = busy_r;
    assign row_done = out_valid && (out_sample_idx == OUT_SAMPLES_PER_ROW-1);

endmodule

