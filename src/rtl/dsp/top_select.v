
`timescale 1ns / 1ps
// =============================================================================
// top_select
//
// Complex streaming selector:
// - For each A-scan, forwards only bins [0 .. KEEP_LEN-1]
// - Suppresses bins [KEEP_LEN .. ASCAN_LEN-1]
// - Intended placement: after fft_wrapper, before mag_calc
//
// Assumptions:
// - start_of_ascan is aligned with the first valid complex sample of the A-scan
// - input stream contains ASCAN_LEN valid complex samples per A-scan
// =============================================================================

module top_select #(
    parameter integer DATA_W    = 32,
    parameter integer ASCAN_LEN = 1024,
    parameter integer KEEP_LEN  = 512,
    parameter integer COUNT_W   = 10
) (
    input  wire                      clk,
    input  wire                      rst,

    input  wire signed [DATA_W-1:0]  re_in,
    input  wire signed [DATA_W-1:0]  im_in,
    input  wire                      in_valid,
    input  wire                      start_of_ascan,

    output reg  signed [DATA_W-1:0]  re_out,
    output reg  signed [DATA_W-1:0]  im_out,
    output reg                       out_valid,
    output reg                       start_of_ascan_out
);

    reg [COUNT_W-1:0] sample_idx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_idx         <= {COUNT_W{1'b0}};
            re_out             <= {DATA_W{1'b0}};
            im_out             <= {DATA_W{1'b0}};
            out_valid          <= 1'b0;
            start_of_ascan_out <= 1'b0;
        end else begin
            out_valid          <= 1'b0;
            start_of_ascan_out <= 1'b0;

            if (in_valid) begin
                // Reset index on first valid sample of each A-scan
                if (start_of_ascan) begin
                    sample_idx <= {COUNT_W{1'b0}};
                end

                // Forward only the first KEEP_LEN samples
                if ((start_of_ascan && (KEEP_LEN > 0)) ||
                    (!start_of_ascan && (sample_idx < KEEP_LEN))) begin
                    re_out             <= re_in;
                    im_out             <= im_in;
                    out_valid          <= 1'b1;
                    start_of_ascan_out <= start_of_ascan;
                end

                // Advance / wrap across the full ASCAN_LEN input stream
                if (start_of_ascan) begin
                    if (ASCAN_LEN == 1)
                        sample_idx <= {COUNT_W{1'b0}};
                    else
                        sample_idx <= {{(COUNT_W-1){1'b0}}, 1'b1};
                end else begin
                    if (sample_idx == ASCAN_LEN-1)
                        sample_idx <= {COUNT_W{1'b0}};
                    else
                        sample_idx <= sample_idx + {{(COUNT_W-1){1'b0}}, 1'b1};
                end
            end
        end
    end

endmodule

