`timescale 1ns/1ps

module row_pingpong_buffer (
    input  wire        clk,
    input  wire        rst,

    // RX input: 1024 real samples per row, delivered as 4 batches of 256
    input  wire        rx_batch_start,
    input  wire [9:0]  rx_batch_row_id,
    input  wire [1:0]  rx_batch_id,

    input  wire        rx_sample_valid,
    input  wire [31:0] rx_sample_data,
    input  wire        rx_sample_last,
    output wire        rx_sample_ready,

    // DSP input stream: 1024 real samples
    output reg         dsp_in_valid,
    output reg         dsp_in_row_start,
    output reg [31:0]  dsp_in_data,

    // DSP output stream: 512 real samples
    input  wire        dsp_out_valid,
    input  wire [31:0] dsp_out_data,

    // TX stream: 512 real samples
    output wire        tx_row_valid,
    input  wire        tx_row_ready,
    output wire        tx_row_start,
    output wire [9:0]  tx_row_row_id,
    output wire [31:0] tx_row_data,

    output reg         rx_overflow,
    output reg         row_tx_done
);

    localparam integer RAW_ROW_SAMPLES  = 1024;
    localparam integer PROC_ROW_SAMPLES = 512;
    localparam integer ADDR_W           = 10;
    localparam integer RAW_RD_LAT       = 2;
    localparam integer PROC_RD_LAT      = 2;

    assign rx_sample_ready = 1'b1;

    // =========================================================================
    // Slot state
    // =========================================================================
    reg        slot_valid0,      slot_valid1;
    reg [9:0]  slot_row_id0,     slot_row_id1;
    reg [3:0]  slot_batch_mask0, slot_batch_mask1;
    reg        slot_raw_ready0,  slot_raw_ready1;
    reg        slot_proc_ready0, slot_proc_ready1;
    reg        slot_busy_dsp0,   slot_busy_dsp1;
    reg        slot_busy_tx0,    slot_busy_tx1;

    // =========================================================================
    // RX state
    // =========================================================================
    reg        rx_active;
    reg        rx_drop;
    reg        rx_slot_sel;
    reg [9:0]  rx_addr;
    reg [1:0]  rx_batch_id_reg;

    reg        rx_target_found;
    reg        rx_target_slot;

    // =========================================================================
    // DSP state
    // =========================================================================
    reg        dsp_active;
    reg        dsp_slot_sel;
    reg [10:0] dsp_issue_count;     // requests issued
    reg [10:0] dsp_retire_count;    // responses consumed
    reg [9:0]  dsp_out_count;       // proc writes committed

    reg        dsp_rd_v     [0:RAW_RD_LAT];
    reg        dsp_rd_slot  [0:RAW_RD_LAT];
    reg        dsp_rd_start [0:RAW_RD_LAT];

    // =========================================================================
    // TX state
    // =========================================================================
    reg        tx_active;
    reg        tx_slot_sel;
    reg [9:0]  tx_issue_count;      // next proc address to request
    reg        tx_wait_resp;        // one outstanding read at a time

    reg [9:0]  tx_hold_addr;
    reg        tx_hold_start;
    reg        tx_hold_last;

    reg        tx_rd_v     [0:PROC_RD_LAT];
    reg        tx_rd_slot  [0:PROC_RD_LAT];
    reg        tx_rd_start [0:PROC_RD_LAT];
    reg        tx_rd_last  [0:PROC_RD_LAT];

    reg        tx_cap_valid;
    reg        tx_cap_slot;
    reg        tx_cap_start;
    reg        tx_cap_last;
    reg [31:0] tx_cap_data;

    reg        tx_valid_reg;
    reg        tx_start_reg;
    reg        tx_last_reg;
    reg [9:0]  tx_row_id_reg;
    reg [31:0] tx_data_reg;

    wire tx_accept = tx_valid_reg && tx_row_ready;

    assign tx_row_valid  = tx_valid_reg;
    assign tx_row_start  = tx_start_reg;
    assign tx_row_row_id = tx_row_id_reg;
    assign tx_row_data   = tx_data_reg;

    // =========================================================================
    // BRAM interfaces
    // =========================================================================
    // raw mem write port A (owned by RX)
    reg  [ADDR_W-1:0] raw0_addra, raw1_addra;
    reg  [31:0]       raw0_dina,  raw1_dina;
    reg               raw0_ena,   raw1_ena;
    reg  [0:0]        raw0_wea,   raw1_wea;

    // raw mem read port B (owned by DSP)
    reg  [ADDR_W-1:0] raw0_addrb, raw1_addrb;
    reg               raw0_enb,   raw1_enb;
    wire [31:0]       raw0_doutb, raw1_doutb;

    // proc mem write port A (owned by DSP)
    reg  [ADDR_W-1:0] proc0_addra, proc1_addra;
    reg  [31:0]       proc0_dina,  proc1_dina;
    reg               proc0_ena,   proc1_ena;
    reg  [0:0]        proc0_wea,   proc1_wea;

    // proc mem read port B (owned by TX)
    reg  [ADDR_W-1:0] proc0_addrb, proc1_addrb;
    reg               proc0_enb,   proc1_enb;
    wire [31:0]       proc0_doutb, proc1_doutb;

    // =========================================================================
    // BRAM instances
    // =========================================================================
    bmg u_raw_mem0 (
        .clka(clk),
        .ena(raw0_ena),
        .wea(raw0_wea),
        .addra(raw0_addra),
        .dina(raw0_dina),
        .clkb(clk),
        .enb(raw0_enb),
        .addrb(raw0_addrb),
        .doutb(raw0_doutb)
    );

    bmg u_raw_mem1 (
        .clka(clk),
        .ena(raw1_ena),
        .wea(raw1_wea),
        .addra(raw1_addra),
        .dina(raw1_dina),
        .clkb(clk),
        .enb(raw1_enb),
        .addrb(raw1_addrb),
        .doutb(raw1_doutb)
    );

    bmg u_proc_mem0 (
        .clka(clk),
        .ena(proc0_ena),
        .wea(proc0_wea),
        .addra(proc0_addra),
        .dina(proc0_dina),
        .clkb(clk),
        .enb(proc0_enb),
        .addrb(proc0_addrb),
        .doutb(proc0_doutb)
    );

    bmg u_proc_mem1 (
        .clka(clk),
        .ena(proc1_ena),
        .wea(proc1_wea),
        .addra(proc1_addra),
        .dina(proc1_dina),
        .clkb(clk),
        .enb(proc1_enb),
        .addrb(proc1_addrb),
        .doutb(proc1_doutb)
    );

    // =========================================================================
    // RX slot picker
    // =========================================================================
    always @(*) begin
        rx_target_found = 1'b0;
        rx_target_slot  = 1'b0;

        if (slot_valid0 && (slot_row_id0 == rx_batch_row_id) &&
            !slot_raw_ready0 && !slot_busy_dsp0 && !slot_busy_tx0) begin
            rx_target_found = 1'b1;
            rx_target_slot  = 1'b0;
        end
        else if (slot_valid1 && (slot_row_id1 == rx_batch_row_id) &&
                 !slot_raw_ready1 && !slot_busy_dsp1 && !slot_busy_tx1) begin
            rx_target_found = 1'b1;
            rx_target_slot  = 1'b1;
        end
        else if (!slot_valid0) begin
            rx_target_found = 1'b1;
            rx_target_slot  = 1'b0;
        end
        else if (!slot_valid1) begin
            rx_target_found = 1'b1;
            rx_target_slot  = 1'b1;
        end
    end

    // =========================================================================
    // Main sequential logic
    // =========================================================================
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            slot_valid0      <= 1'b0;
            slot_valid1      <= 1'b0;
            slot_row_id0     <= 10'd0;
            slot_row_id1     <= 10'd0;
            slot_batch_mask0 <= 4'd0;
            slot_batch_mask1 <= 4'd0;
            slot_raw_ready0  <= 1'b0;
            slot_raw_ready1  <= 1'b0;
            slot_proc_ready0 <= 1'b0;
            slot_proc_ready1 <= 1'b0;
            slot_busy_dsp0   <= 1'b0;
            slot_busy_dsp1   <= 1'b0;
            slot_busy_tx0    <= 1'b0;
            slot_busy_tx1    <= 1'b0;

            rx_active       <= 1'b0;
            rx_drop         <= 1'b0;
            rx_slot_sel     <= 1'b0;
            rx_addr         <= 10'd0;
            rx_batch_id_reg <= 2'd0;
            rx_overflow     <= 1'b0;

            dsp_active       <= 1'b0;
            dsp_slot_sel     <= 1'b0;
            dsp_issue_count  <= 11'd0;
            dsp_retire_count <= 11'd0;
            dsp_out_count    <= 10'd0;

            for (i = 0; i <= RAW_RD_LAT; i = i + 1) begin
                dsp_rd_v[i]     <= 1'b0;
                dsp_rd_slot[i]  <= 1'b0;
                dsp_rd_start[i] <= 1'b0;
            end

            tx_active      <= 1'b0;
            tx_slot_sel    <= 1'b0;
            tx_issue_count <= 10'd0;
            tx_wait_resp   <= 1'b0;
            tx_hold_addr   <= 10'd0;
            tx_hold_start  <= 1'b0;
            tx_hold_last   <= 1'b0;

            for (i = 0; i <= PROC_RD_LAT; i = i + 1) begin
                tx_rd_v[i]     <= 1'b0;
                tx_rd_slot[i]  <= 1'b0;
                tx_rd_start[i] <= 1'b0;
                tx_rd_last[i]  <= 1'b0;
            end

            tx_cap_valid  <= 1'b0;
            tx_cap_slot   <= 1'b0;
            tx_cap_start  <= 1'b0;
            tx_cap_last   <= 1'b0;
            tx_cap_data   <= 32'd0;

            tx_valid_reg  <= 1'b0;
            tx_start_reg  <= 1'b0;
            tx_last_reg   <= 1'b0;
            tx_row_id_reg <= 10'd0;
            tx_data_reg   <= 32'd0;

            dsp_in_valid     <= 1'b0;
            dsp_in_row_start <= 1'b0;
            dsp_in_data      <= 32'd0;
            row_tx_done      <= 1'b0;

            raw0_addra <= {ADDR_W{1'b0}};
            raw1_addra <= {ADDR_W{1'b0}};
            raw0_dina  <= 32'd0;
            raw1_dina  <= 32'd0;
            raw0_ena   <= 1'b0;
            raw1_ena   <= 1'b0;
            raw0_wea   <= 1'b0;
            raw1_wea   <= 1'b0;

            raw0_addrb <= {ADDR_W{1'b0}};
            raw1_addrb <= {ADDR_W{1'b0}};
            raw0_enb   <= 1'b0;
            raw1_enb   <= 1'b0;

            proc0_addra <= {ADDR_W{1'b0}};
            proc1_addra <= {ADDR_W{1'b0}};
            proc0_dina  <= 32'd0;
            proc1_dina  <= 32'd0;
            proc0_ena   <= 1'b0;
            proc1_ena   <= 1'b0;
            proc0_wea   <= 1'b0;
            proc1_wea   <= 1'b0;

            proc0_addrb <= {ADDR_W{1'b0}};
            proc1_addrb <= {ADDR_W{1'b0}};
            proc0_enb   <= 1'b0;
            proc1_enb   <= 1'b0;
        end
        else begin
            // -------------------------------------------------------------
            // defaults
            // -------------------------------------------------------------
            rx_overflow       <= 1'b0;
            dsp_in_valid      <= 1'b0;
            dsp_in_row_start  <= 1'b0;
            row_tx_done       <= 1'b0;

            raw0_ena <= 1'b0;
            raw1_ena <= 1'b0;
            raw0_wea <= 1'b0;
            raw1_wea <= 1'b0;

            raw0_enb <= 1'b0;
            raw1_enb <= 1'b0;

            proc0_ena <= 1'b0;
            proc1_ena <= 1'b0;
            proc0_wea <= 1'b0;
            proc1_wea <= 1'b0;

            proc0_enb <= 1'b0;
            proc1_enb <= 1'b0;

            // -------------------------------------------------------------
            // advance DSP read metadata pipeline
            // -------------------------------------------------------------
            for (i = RAW_RD_LAT; i > 0; i = i - 1) begin
                dsp_rd_v[i]     <= dsp_rd_v[i-1];
                dsp_rd_slot[i]  <= dsp_rd_slot[i-1];
                dsp_rd_start[i] <= dsp_rd_start[i-1];
            end
            dsp_rd_v[0]     <= 1'b0;
            dsp_rd_slot[0]  <= 1'b0;
            dsp_rd_start[0] <= 1'b0;

            // -------------------------------------------------------------
            // advance TX read metadata pipeline
            // -------------------------------------------------------------
            for (i = PROC_RD_LAT; i > 0; i = i - 1) begin
                tx_rd_v[i]     <= tx_rd_v[i-1];
                tx_rd_slot[i]  <= tx_rd_slot[i-1];
                tx_rd_start[i] <= tx_rd_start[i-1];
                tx_rd_last[i]  <= tx_rd_last[i-1];
            end
            tx_rd_v[0]     <= 1'b0;
            tx_rd_slot[0]  <= 1'b0;
            tx_rd_start[0] <= 1'b0;
            tx_rd_last[0]  <= 1'b0;

            // -------------------------------------------------------------
            // RX path
            // -------------------------------------------------------------
            if (rx_sample_valid) begin
                if (rx_batch_start) begin
                    rx_batch_id_reg <= rx_batch_id;

                    if (rx_target_found) begin
                        rx_active   <= 1'b1;
                        rx_drop     <= 1'b0;
                        rx_slot_sel <= rx_target_slot;
                        rx_addr     <= {rx_batch_id, 8'd0};

                        if (!rx_target_slot && !slot_valid0) begin
                            slot_valid0      <= 1'b1;
                            slot_row_id0     <= rx_batch_row_id;
                            slot_batch_mask0 <= 4'd0;
                            slot_raw_ready0  <= 1'b0;
                            slot_proc_ready0 <= 1'b0;
                        end
                        else if (rx_target_slot && !slot_valid1) begin
                            slot_valid1      <= 1'b1;
                            slot_row_id1     <= rx_batch_row_id;
                            slot_batch_mask1 <= 4'd0;
                            slot_raw_ready1  <= 1'b0;
                            slot_proc_ready1 <= 1'b0;
                        end

                        if (!rx_target_slot) begin
                            raw0_ena   <= 1'b1;
                            raw0_wea   <= 1'b1;
                            raw0_addra <= {rx_batch_id, 8'd0};
                            raw0_dina  <= rx_sample_data;
                        end else begin
                            raw1_ena   <= 1'b1;
                            raw1_wea   <= 1'b1;
                            raw1_addra <= {rx_batch_id, 8'd0};
                            raw1_dina  <= rx_sample_data;
                        end

                        if (rx_sample_last) begin
                            rx_active <= 1'b0;
                            if (!rx_target_slot) begin
                                slot_batch_mask0 <= slot_batch_mask0 | (4'b0001 << rx_batch_id);
                                if ((slot_batch_mask0 | (4'b0001 << rx_batch_id)) == 4'b1111)
                                    slot_raw_ready0 <= 1'b1;
                            end else begin
                                slot_batch_mask1 <= slot_batch_mask1 | (4'b0001 << rx_batch_id);
                                if ((slot_batch_mask1 | (4'b0001 << rx_batch_id)) == 4'b1111)
                                    slot_raw_ready1 <= 1'b1;
                            end
                        end
                        else begin
                            rx_addr <= {rx_batch_id, 8'd0} + 10'd1;
                        end
                    end
                    else begin
                        rx_active   <= 1'b0;
                        rx_drop     <= 1'b1;
                        rx_overflow <= 1'b1;
                    end
                end
                else if (rx_active && !rx_drop) begin
                    if (!rx_slot_sel) begin
                        raw0_ena   <= 1'b1;
                        raw0_wea   <= 1'b1;
                        raw0_addra <= rx_addr;
                        raw0_dina  <= rx_sample_data;
                    end else begin
                        raw1_ena   <= 1'b1;
                        raw1_wea   <= 1'b1;
                        raw1_addra <= rx_addr;
                        raw1_dina  <= rx_sample_data;
                    end

                    if (rx_sample_last) begin
                        rx_active <= 1'b0;
                        if (!rx_slot_sel) begin
                            slot_batch_mask0 <= slot_batch_mask0 | (4'b0001 << rx_batch_id_reg);
                            if ((slot_batch_mask0 | (4'b0001 << rx_batch_id_reg)) == 4'b1111)
                                slot_raw_ready0 <= 1'b1;
                        end else begin
                            slot_batch_mask1 <= slot_batch_mask1 | (4'b0001 << rx_batch_id_reg);
                            if ((slot_batch_mask1 | (4'b0001 << rx_batch_id_reg)) == 4'b1111)
                                slot_raw_ready1 <= 1'b1;
                        end
                    end
                    else begin
                        rx_addr <= rx_addr + 10'd1;
                    end
                end
                else if (rx_drop) begin
                    if (rx_sample_last)
                        rx_drop <= 1'b0;
                end
            end

            // -------------------------------------------------------------
            // Launch DSP
            // -------------------------------------------------------------
            if (!dsp_active) begin
                if (slot_raw_ready0 && !slot_proc_ready0 && !slot_busy_dsp0 && !slot_busy_tx0) begin
                    dsp_active       <= 1'b1;
                    dsp_slot_sel     <= 1'b0;
                    dsp_issue_count  <= 11'd0;
                    dsp_retire_count <= 11'd0;
                    dsp_out_count    <= 10'd0;

                    slot_raw_ready0 <= 1'b0;
                    slot_busy_dsp0  <= 1'b1;
                end
                else if (slot_raw_ready1 && !slot_proc_ready1 && !slot_busy_dsp1 && !slot_busy_tx1) begin
                    dsp_active       <= 1'b1;
                    dsp_slot_sel     <= 1'b1;
                    dsp_issue_count  <= 11'd0;
                    dsp_retire_count <= 11'd0;
                    dsp_out_count    <= 10'd0;

                    slot_raw_ready1 <= 1'b0;
                    slot_busy_dsp1  <= 1'b1;
                end
            end

            // -------------------------------------------------------------
            // DSP raw read request stream
            // Keep ENB high through the tail while responses are still retiring.
            // -------------------------------------------------------------
            if (dsp_active) begin
                if (dsp_issue_count < RAW_ROW_SAMPLES) begin
                    if (!dsp_slot_sel) begin
                        raw0_enb   <= 1'b1;
                        raw0_addrb <= dsp_issue_count[9:0];
                    end else begin
                        raw1_enb   <= 1'b1;
                        raw1_addrb <= dsp_issue_count[9:0];
                    end

                    dsp_rd_v[0]     <= 1'b1;
                    dsp_rd_slot[0]  <= dsp_slot_sel;
                    dsp_rd_start[0] <= (dsp_issue_count == 11'd0);

                    dsp_issue_count <= dsp_issue_count + 11'd1;
                end
                else if (dsp_retire_count < RAW_ROW_SAMPLES) begin
                    // flush final valid response through the registered Port B path
                    if (!dsp_slot_sel) begin
                        raw0_enb   <= 1'b1;
                        raw0_addrb <= RAW_ROW_SAMPLES-1;
                    end else begin
                        raw1_enb   <= 1'b1;
                        raw1_addrb <= RAW_ROW_SAMPLES-1;
                    end
                end
            end

            // -------------------------------------------------------------
            // DSP raw read response
            // -------------------------------------------------------------
            if (dsp_rd_v[RAW_RD_LAT]) begin
                dsp_in_valid     <= 1'b1;
                dsp_in_row_start <= dsp_rd_start[RAW_RD_LAT];

                if (!dsp_rd_slot[RAW_RD_LAT])
                    dsp_in_data <= raw0_doutb;
                else
                    dsp_in_data <= raw1_doutb;

                dsp_retire_count <= dsp_retire_count + 11'd1;
            end

            // -------------------------------------------------------------
            // DSP output writes to proc RAM
            // -------------------------------------------------------------
            if (dsp_active && dsp_out_valid && (dsp_out_count < PROC_ROW_SAMPLES)) begin
                if (!dsp_slot_sel) begin
                    proc0_ena   <= 1'b1;
                    proc0_wea   <= 1'b1;
                    proc0_addra <= dsp_out_count;
                    proc0_dina  <= dsp_out_data;
                end else begin
                    proc1_ena   <= 1'b1;
                    proc1_wea   <= 1'b1;
                    proc1_addra <= dsp_out_count;
                    proc1_dina  <= dsp_out_data;
                end
                dsp_out_count <= dsp_out_count + 10'd1;
            end

            // -------------------------------------------------------------
            // DSP done
            // -------------------------------------------------------------
            if (dsp_active &&
                (dsp_issue_count  == RAW_ROW_SAMPLES) &&
                (dsp_retire_count == RAW_ROW_SAMPLES) &&
                (dsp_out_count    == PROC_ROW_SAMPLES)) begin

                dsp_active <= 1'b0;

                if (!dsp_slot_sel) begin
                    slot_busy_dsp0   <= 1'b0;
                    slot_proc_ready0 <= 1'b1;
                end else begin
                    slot_busy_dsp1   <= 1'b0;
                    slot_proc_ready1 <= 1'b1;
                end
            end

            // -------------------------------------------------------------
            // Launch TX
            // -------------------------------------------------------------
            if (!tx_active && !tx_valid_reg && !tx_cap_valid) begin
                if (slot_proc_ready0 && !slot_busy_tx0 && !slot_busy_dsp0) begin
                    tx_active      <= 1'b1;
                    tx_slot_sel    <= 1'b0;
                    tx_issue_count <= 10'd0;
                    tx_wait_resp   <= 1'b0;
                    tx_hold_addr   <= 10'd0;
                    tx_hold_start  <= 1'b0;
                    tx_hold_last   <= 1'b0;

                    slot_proc_ready0 <= 1'b0;
                    slot_busy_tx0    <= 1'b1;
                end
                else if (slot_proc_ready1 && !slot_busy_tx1 && !slot_busy_dsp1) begin
                    tx_active      <= 1'b1;
                    tx_slot_sel    <= 1'b1;
                    tx_issue_count <= 10'd0;
                    tx_wait_resp   <= 1'b0;
                    tx_hold_addr   <= 10'd0;
                    tx_hold_start  <= 1'b0;
                    tx_hold_last   <= 1'b0;

                    slot_proc_ready1 <= 1'b0;
                    slot_busy_tx1    <= 1'b1;
                end
            end

            // -------------------------------------------------------------
            // TX proc read control
            // One outstanding read at a time.
            // Keep ENB high while waiting for that response.
            // -------------------------------------------------------------
            if (tx_active && !tx_valid_reg && !tx_cap_valid) begin
                if (!tx_wait_resp && (tx_issue_count < PROC_ROW_SAMPLES)) begin
                    tx_hold_addr  <= tx_issue_count;
                    tx_hold_start <= (tx_issue_count == 10'd0);
                    tx_hold_last  <= (tx_issue_count == (PROC_ROW_SAMPLES-1));

                    if (!tx_slot_sel) begin
                        proc0_enb   <= 1'b1;
                        proc0_addrb <= tx_issue_count;
                    end else begin
                        proc1_enb   <= 1'b1;
                        proc1_addrb <= tx_issue_count;
                    end

                    tx_rd_v[0]     <= 1'b1;
                    tx_rd_slot[0]  <= tx_slot_sel;
                    tx_rd_start[0] <= (tx_issue_count == 10'd0);
                    tx_rd_last[0]  <= (tx_issue_count == (PROC_ROW_SAMPLES-1));

                    tx_issue_count <= tx_issue_count + 10'd1;
                    tx_wait_resp   <= 1'b1;
                end
                else if (tx_wait_resp) begin
                    if (!tx_slot_sel) begin
                        proc0_enb   <= 1'b1;
                        proc0_addrb <= tx_hold_addr;
                    end else begin
                        proc1_enb   <= 1'b1;
                        proc1_addrb <= tx_hold_addr;
                    end
                end
            end

            // -------------------------------------------------------------
            // TX proc read response
            // -------------------------------------------------------------
            if (!tx_valid_reg && !tx_cap_valid && tx_rd_v[PROC_RD_LAT]) begin
                tx_cap_valid <= 1'b1;
                tx_cap_slot  <= tx_rd_slot[PROC_RD_LAT];
                tx_cap_start <= tx_rd_start[PROC_RD_LAT];
                tx_cap_last  <= tx_rd_last[PROC_RD_LAT];

                if (!tx_rd_slot[PROC_RD_LAT])
                    tx_cap_data <= proc0_doutb;
                else
                    tx_cap_data <= proc1_doutb;

                tx_wait_resp <= 1'b0;
            end

            // -------------------------------------------------------------
            // move captured sample to TX output reg
            // -------------------------------------------------------------
            if (!tx_valid_reg && tx_cap_valid) begin
                tx_valid_reg <= 1'b1;
                tx_start_reg <= tx_cap_start;
                tx_last_reg  <= tx_cap_last;
                tx_data_reg  <= tx_cap_data;
                tx_cap_valid <= 1'b0;

                if (!tx_cap_slot)
                    tx_row_id_reg <= slot_row_id0;
                else
                    tx_row_id_reg <= slot_row_id1;
            end

            // -------------------------------------------------------------
            // TX handshake / slot release
            // -------------------------------------------------------------
            if (tx_accept) begin
                tx_valid_reg <= 1'b0;
                tx_start_reg <= 1'b0;

                if (tx_last_reg) begin
                    tx_active   <= 1'b0;
                    tx_last_reg <= 1'b0;
                    row_tx_done <= 1'b1;

                    if (!tx_slot_sel) begin
                        slot_valid0      <= 1'b0;
                        slot_row_id0     <= 10'd0;
                        slot_batch_mask0 <= 4'd0;
                        slot_raw_ready0  <= 1'b0;
                        slot_proc_ready0 <= 1'b0;
                        slot_busy_dsp0   <= 1'b0;
                        slot_busy_tx0    <= 1'b0;
                    end else begin
                        slot_valid1      <= 1'b0;
                        slot_row_id1     <= 10'd0;
                        slot_batch_mask1 <= 4'd0;
                        slot_raw_ready1  <= 1'b0;
                        slot_proc_ready1 <= 1'b0;
                        slot_busy_dsp1   <= 1'b0;
                        slot_busy_tx1    <= 1'b0;
                    end
                end
            end
        end
    end

endmodule

