`timescale 1ns / 1ps
// =============================================================================
// dsp_core_top
//
// Deterministic row-buffered DSP stub.
//
// Current placeholder behavior:
// - Accept exactly 1024 real samples for one row
// - Emit exactly the first 512 samples unchanged
//
// Input contract:
// - in_row_start must be asserted together with the first valid sample of a row
// - inputs for a row may be contiguous or may contain gaps in in_valid
// - do not start a new row while this block is still busy with the previous row
//
// Output behavior:
// - out_valid asserted for each emitted sample
// - out_row_start asserted together with the first output sample of a row
// - row_done asserted together with the final output sample of a row
//
// Purpose:
// - maximally predictable integration stub
// - easy to verify row assembly, packetization, and transmission edges
// =============================================================================

module dsp_core_top #(
    parameter integer IN_SAMPLES_PER_ROW  = 1024,
    parameter integer OUT_SAMPLES_PER_ROW = 512
) (
    input  wire        clk,
    input  wire        rst,

    // ---- Input stream ----
    input  wire        in_valid,
    input  wire        in_row_start,
    input  wire [31:0] in_data,

    // ---- Output stream ----
    output reg         out_valid,
    output reg         out_row_start,
    output reg  [31:0] out_data,

    // ---- Optional status ----
    output wire        busy,
    output reg         row_done
);

    localparam [1:0]
        ST_IDLE = 2'd0,
        ST_FILL = 2'd1,
        ST_OUT  = 2'd2;

    reg [1:0] state;

    reg [31:0] row_mem [0:IN_SAMPLES_PER_ROW-1];

    reg [9:0] in_count;   // 0..1023
    reg [8:0] out_count;  // 0..511

    reg busy_r;
    assign busy = busy_r;

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= ST_IDLE;
            in_count      <= 10'd0;
            out_count     <= 9'd0;
            out_valid     <= 1'b0;
            out_row_start <= 1'b0;
            out_data      <= 32'd0;
            row_done      <= 1'b0;
            busy_r        <= 1'b0;

            for (i = 0; i < IN_SAMPLES_PER_ROW; i = i + 1)
                row_mem[i] <= 32'd0;

        end else begin
            // default pulse outputs
            out_valid     <= 1'b0;
            out_row_start <= 1'b0;
            row_done      <= 1'b0;

            case (state)

                // -------------------------------------------------------------
                // Wait for first sample of a row
                // -------------------------------------------------------------
                ST_IDLE: begin
                    in_count  <= 10'd0;
                    out_count <= 9'd0;
                    busy_r    <= 1'b0;

                    if (in_valid && in_row_start) begin
                        row_mem[0] <= in_data;
                        in_count   <= 10'd1;
                        busy_r     <= 1'b1;
                        state      <= ST_FILL;
                    end
                end

                // -------------------------------------------------------------
                // Collect full 1024-sample row
                // -------------------------------------------------------------
                ST_FILL: begin
                    busy_r <= 1'b1;

                    if (in_valid) begin
                        row_mem[in_count] <= in_data;

                        if (in_count == IN_SAMPLES_PER_ROW-1) begin
                            out_count <= 9'd0;
                            state     <= ST_OUT;
                        end else begin
                            in_count <= in_count + 10'd1;
                        end
                    end
                end

                // -------------------------------------------------------------
                // Emit first 512 samples unchanged
                // -------------------------------------------------------------
                ST_OUT: begin
                    busy_r        <= 1'b1;
                    out_valid     <= 1'b1;
                    out_row_start <= (out_count == 9'd0);
                    out_data      <= row_mem[out_count];
                    row_done      <= (out_count == OUT_SAMPLES_PER_ROW-1);

                    if (out_count == OUT_SAMPLES_PER_ROW-1) begin
                        state    <= ST_IDLE;
                        busy_r   <= 1'b0;
                        in_count <= 10'd0;
                    end else begin
                        out_count <= out_count + 9'd1;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
