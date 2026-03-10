`timescale 1ns / 1ps
// =============================================================================
// Module: row_pingpong_buffer
// Description:
//   Two-slot ping-pong row buffer for UDP batch reassembly, DSP streaming,
//   DSP output capture, and TX row streaming.
//
// Assumptions:
//   - One incoming batch at a time
//   - rx_batch_start asserted with first sample of batch
//   - 128 complex samples per batch
//   - 4 batches per row
//   - 512 complex samples per row
//   - DSP input has no backpressure
//   - DSP output is valid-only
//   - TX row output uses valid/ready
//
// Responsibilities:
//   1. Receive parsed batches from app_packet_rx
//   2. Reassemble them into full rows
//   3. Auto-start DSP when a row is complete
//   4. Capture 512 processed samples from DSP output
//   5. Stream processed row to app_packet_tx
// =============================================================================

module row_pingpong_buffer (
    input  wire        clk,
    input  wire        rst,

    // -------------------------------------------------------------------------
    // RX batch/sample input (from app_packet_rx or controller)
    // -------------------------------------------------------------------------
    input  wire        rx_batch_start,      // pulse on first sample of batch
    input  wire [9:0]  rx_batch_row_id,
    input  wire [1:0]  rx_batch_id,

    input  wire        rx_sample_valid,
    input  wire [31:0] rx_sample_re,
    input  wire [31:0] rx_sample_im,
    input  wire        rx_sample_last,
    output wire        rx_sample_ready,

    // -------------------------------------------------------------------------
    // DSP stream output (to dsp_core_top)
    // -------------------------------------------------------------------------
    output wire        dsp_in_valid,
    output wire        dsp_in_row_start,
    output wire [31:0] dsp_in_re,
    output wire [31:0] dsp_in_im,

    // -------------------------------------------------------------------------
    // DSP processed stream input (from dsp_core_top)
    // -------------------------------------------------------------------------
    input  wire        dsp_out_valid,
    input  wire [31:0] dsp_out_re,
    input  wire [31:0] dsp_out_im,

    // -------------------------------------------------------------------------
    // Processed row output stream (to app_packet_tx)
    // -------------------------------------------------------------------------
    output wire        tx_row_valid,
    input  wire        tx_row_ready,
    output wire        tx_row_start,
    output wire [9:0]  tx_row_row_id,
    output wire [31:0] tx_row_re,
    output wire [31:0] tx_row_im,

    // -------------------------------------------------------------------------
    // Status / debug
    // -------------------------------------------------------------------------
    output reg         rx_overflow,     // pulse when no slot available
    output reg         row_tx_done      // pulse on final TX sample handshake
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam ROW_SAMPLES   = 512;
    localparam BATCH_SAMPLES = 128;

    // =========================================================================
    // Memories
    // =========================================================================
    reg [63:0] raw_mem0  [0:ROW_SAMPLES-1];
    reg [63:0] raw_mem1  [0:ROW_SAMPLES-1];
    reg [63:0] proc_mem0 [0:ROW_SAMPLES-1];
    reg [63:0] proc_mem1 [0:ROW_SAMPLES-1];

    // =========================================================================
    // Slot metadata/state
    // =========================================================================
    reg        slot0_alloc;
    reg        slot1_alloc;

    reg [9:0]  slot0_row_id;
    reg [9:0]  slot1_row_id;

    reg [3:0]  slot0_batch_mask;
    reg [3:0]  slot1_batch_mask;

    reg        slot0_raw_ready;
    reg        slot1_raw_ready;

    reg        slot0_proc_ready;
    reg        slot1_proc_ready;

    // =========================================================================
    // RX current batch tracking
    // =========================================================================
    reg        rx_batch_active;
    reg        rx_drop_active;
    reg        rx_slot;                  // 0 or 1
    reg [9:0]  rx_sample_idx;            // 0..127
    reg [9:0]  rx_batch_base;            // 0,128,256,384
    reg [1:0]  rx_batch_id_reg;

    // =========================================================================
    // DSP engine state
    // =========================================================================
    reg        dsp_active;
    reg        dsp_slot;                 // slot being processed
    reg [9:0]  dsp_in_idx;               // 0..511
    reg [9:0]  dsp_out_idx;              // 0..511

    // =========================================================================
    // TX stream state
    // =========================================================================
    reg        tx_active;
    reg        tx_slot;                  // slot being transmitted
    reg [9:0]  tx_idx;                   // 0..511

    // =========================================================================
    // Always ready in this first version
    // =========================================================================
    assign rx_sample_ready = 1'b1;

    // =========================================================================
    // Slot select for new batch
    // Preference:
    //   1. existing matching slot (same row_id, not yet raw_ready)
    //   2. free slot 0
    //   3. free slot 1
    // =========================================================================
    reg rx_target_valid;
    reg rx_target_slot;

    always @(*) begin
        rx_target_valid = 1'b0;
        rx_target_slot  = 1'b0;

        if (slot0_alloc && (slot0_row_id == rx_batch_row_id) && !slot0_raw_ready) begin
            rx_target_valid = 1'b1;
            rx_target_slot  = 1'b0;
        end else if (slot1_alloc && (slot1_row_id == rx_batch_row_id) && !slot1_raw_ready) begin
            rx_target_valid = 1'b1;
            rx_target_slot  = 1'b1;
        end else if (!slot0_alloc) begin
            rx_target_valid = 1'b1;
            rx_target_slot  = 1'b0;
        end else if (!slot1_alloc) begin
            rx_target_valid = 1'b1;
            rx_target_slot  = 1'b1;
        end
    end

    // =========================================================================
    // DSP output stream (combinational from active slot)
    // =========================================================================
    wire [63:0] dsp_word =
        (!dsp_slot) ? raw_mem0[dsp_in_idx] : raw_mem1[dsp_in_idx];

    assign dsp_in_valid     = dsp_active && (dsp_in_idx < ROW_SAMPLES);
    assign dsp_in_row_start = dsp_active && (dsp_in_idx == 10'd0);
    assign dsp_in_re        = dsp_word[63:32];
    assign dsp_in_im        = dsp_word[31:0];

    // =========================================================================
    // TX row stream output (combinational from active slot)
    // =========================================================================
    wire [63:0] tx_word =
        (!tx_slot) ? proc_mem0[tx_idx] : proc_mem1[tx_idx];

    assign tx_row_valid  = tx_active;
    assign tx_row_start  = tx_active && (tx_idx == 10'd0);
    assign tx_row_row_id = (!tx_slot) ? slot0_row_id : slot1_row_id;
    assign tx_row_re     = tx_word[63:32];
    assign tx_row_im     = tx_word[31:0];

    // =========================================================================
    // Main control
    // =========================================================================
    reg [3:0] new_mask;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            slot0_alloc      <= 1'b0;
            slot1_alloc      <= 1'b0;
            slot0_row_id     <= 10'd0;
            slot1_row_id     <= 10'd0;
            slot0_batch_mask <= 4'd0;
            slot1_batch_mask <= 4'd0;
            slot0_raw_ready  <= 1'b0;
            slot1_raw_ready  <= 1'b0;
            slot0_proc_ready <= 1'b0;
            slot1_proc_ready <= 1'b0;

            rx_batch_active  <= 1'b0;
            rx_drop_active   <= 1'b0;
            rx_slot          <= 1'b0;
            rx_sample_idx    <= 10'd0;
            rx_batch_base    <= 10'd0;
            rx_batch_id_reg  <= 2'd0;

            dsp_active       <= 1'b0;
            dsp_slot         <= 1'b0;
            dsp_in_idx       <= 10'd0;
            dsp_out_idx      <= 10'd0;

            tx_active        <= 1'b0;
            tx_slot          <= 1'b0;
            tx_idx           <= 10'd0;

            rx_overflow      <= 1'b0;
            row_tx_done      <= 1'b0;
        end else begin
            rx_overflow <= 1'b0;
            row_tx_done <= 1'b0;

            // -----------------------------------------------------------------
            // RX batch/sample handling
            // -----------------------------------------------------------------
            if (rx_sample_valid) begin
                // New batch starts on this cycle
                if (rx_batch_start) begin
                    if (rx_target_valid) begin
                        rx_drop_active  <= 1'b0;
                        rx_batch_active <= 1'b1;
                        rx_slot         <= rx_target_slot;
                        rx_sample_idx   <= 10'd0;
                        rx_batch_base   <= {rx_batch_id, 7'd0};  // batch * 128
                        rx_batch_id_reg <= rx_batch_id;

                        // allocate slot if needed
                        if (!rx_target_slot) begin
                            if (!slot0_alloc) begin
                                slot0_alloc      <= 1'b1;
                                slot0_row_id     <= rx_batch_row_id;
                                slot0_batch_mask <= 4'd0;
                                slot0_raw_ready  <= 1'b0;
                                slot0_proc_ready <= 1'b0;
                            end
                            raw_mem0[{rx_batch_id, 7'd0}] <= {rx_sample_re, rx_sample_im};
                        end else begin
                            if (!slot1_alloc) begin
                                slot1_alloc      <= 1'b1;
                                slot1_row_id     <= rx_batch_row_id;
                                slot1_batch_mask <= 4'd0;
                                slot1_raw_ready  <= 1'b0;
                                slot1_proc_ready <= 1'b0;
                            end
                            raw_mem1[{rx_batch_id, 7'd0}] <= {rx_sample_re, rx_sample_im};
                        end

                        // Immediate end-of-batch
                        if (rx_sample_last) begin
                            rx_batch_active <= 1'b0;

                            if (!rx_target_slot) begin
                                new_mask = slot0_batch_mask | (4'b0001 << rx_batch_id);
                                slot0_batch_mask <= new_mask;
                                if (new_mask == 4'b1111)
                                    slot0_raw_ready <= 1'b1;
                            end else begin
                                new_mask = slot1_batch_mask | (4'b0001 << rx_batch_id);
                                slot1_batch_mask <= new_mask;
                                if (new_mask == 4'b1111)
                                    slot1_raw_ready <= 1'b1;
                            end
                        end else begin
                            rx_sample_idx <= 10'd1;
                        end
                    end else begin
                        // No slot available
                        rx_overflow     <= 1'b1;
                        rx_drop_active  <= 1'b1;
                        rx_batch_active <= 1'b0;

                        if (rx_sample_last)
                            rx_drop_active <= 1'b0;
                    end
                end
                // Continuing current batch
                else if (rx_batch_active) begin
                    if (!rx_drop_active) begin
                        if (!rx_slot)
                            raw_mem0[rx_batch_base + rx_sample_idx] <= {rx_sample_re, rx_sample_im};
                        else
                            raw_mem1[rx_batch_base + rx_sample_idx] <= {rx_sample_re, rx_sample_im};
                    end

                    if (rx_sample_last) begin
                        rx_batch_active <= 1'b0;

                        if (!rx_drop_active) begin
                            if (!rx_slot) begin
                                new_mask = slot0_batch_mask | (4'b0001 << rx_batch_id_reg);
                                slot0_batch_mask <= new_mask;
                                if (new_mask == 4'b1111)
                                    slot0_raw_ready <= 1'b1;
                            end else begin
                                new_mask = slot1_batch_mask | (4'b0001 << rx_batch_id_reg);
                                slot1_batch_mask <= new_mask;
                                if (new_mask == 4'b1111)
                                    slot1_raw_ready <= 1'b1;
                            end
                        end

                        rx_drop_active <= 1'b0;
                    end else begin
                        rx_sample_idx <= rx_sample_idx + 10'd1;
                    end
                end
            end

            // -----------------------------------------------------------------
            // Auto-start DSP on first available completed row
            // -----------------------------------------------------------------
            if (!dsp_active) begin
                if (slot0_raw_ready && !slot0_proc_ready) begin
                    dsp_active  <= 1'b1;
                    dsp_slot    <= 1'b0;
                    dsp_in_idx  <= 10'd0;
                    dsp_out_idx <= 10'd0;
                    slot0_raw_ready <= 1'b0;  // row consumed by DSP
                end else if (slot1_raw_ready && !slot1_proc_ready) begin
                    dsp_active  <= 1'b1;
                    dsp_slot    <= 1'b1;
                    dsp_in_idx  <= 10'd0;
                    dsp_out_idx <= 10'd0;
                    slot1_raw_ready <= 1'b0;
                end
            end else begin
                // Stream 512 input samples to DSP, one per cycle
                if (dsp_in_idx < ROW_SAMPLES)
                    dsp_in_idx <= dsp_in_idx + 10'd1;

                // Capture DSP outputs whenever valid
                if (dsp_out_valid) begin
                    if (!dsp_slot)
                        proc_mem0[dsp_out_idx] <= {dsp_out_re, dsp_out_im};
                    else
                        proc_mem1[dsp_out_idx] <= {dsp_out_re, dsp_out_im};

                    if (dsp_out_idx == ROW_SAMPLES-1) begin
                        dsp_active <= 1'b0;
                        if (!dsp_slot)
                            slot0_proc_ready <= 1'b1;
                        else
                            slot1_proc_ready <= 1'b1;
                    end else begin
                        dsp_out_idx <= dsp_out_idx + 10'd1;
                    end
                end
            end

            // -----------------------------------------------------------------
            // Auto-start TX on first available processed row
            // -----------------------------------------------------------------
            if (!tx_active) begin
                if (slot0_proc_ready) begin
                    tx_active <= 1'b1;
                    tx_slot   <= 1'b0;
                    tx_idx    <= 10'd0;
                end else if (slot1_proc_ready) begin
                    tx_active <= 1'b1;
                    tx_slot   <= 1'b1;
                    tx_idx    <= 10'd0;
                end
            end else begin
                if (tx_row_ready) begin
                    if (tx_idx == ROW_SAMPLES-1) begin
                        tx_active <= 1'b0;
                        tx_idx    <= 10'd0;
                        row_tx_done <= 1'b1;

                        if (!tx_slot) begin
                            slot0_alloc      <= 1'b0;
                            slot0_batch_mask <= 4'd0;
                            slot0_proc_ready <= 1'b0;
                            slot0_raw_ready  <= 1'b0;
                        end else begin
                            slot1_alloc      <= 1'b0;
                            slot1_batch_mask <= 4'd0;
                            slot1_proc_ready <= 1'b0;
                            slot1_raw_ready  <= 1'b0;
                        end
                    end else begin
                        tx_idx <= tx_idx + 10'd1;
                    end
                end
            end
        end
    end

endmodule

