
module row_pingpong_buffer (
    input  wire        clk,
    input  wire        rst,

    // RX input
    input  wire        rx_batch_start,
    input  wire [9:0]  rx_batch_row_id,
    input  wire [1:0]  rx_batch_id,

    input  wire        rx_sample_valid,
    input  wire [31:0] rx_sample_re,
    input  wire [31:0] rx_sample_im,
    input  wire        rx_sample_last,
    output wire        rx_sample_ready,

    // DSP input stream
    output reg         dsp_in_valid,
    output reg         dsp_in_row_start,
    output reg [31:0]  dsp_in_re,
    output reg [31:0]  dsp_in_im,

    // DSP output stream
    input  wire        dsp_out_valid,
    input  wire [31:0] dsp_out_re,
    input  wire [31:0] dsp_out_im,

    // TX stream
    output wire        tx_row_valid,
    input  wire        tx_row_ready,
    output wire        tx_row_start,
    output wire [9:0]  tx_row_row_id,
    output wire [31:0] tx_row_re,
    output wire [31:0] tx_row_im,

    output reg         rx_overflow,
    output reg         row_tx_done
);

    localparam integer ROW_SAMPLES = 512;
    localparam integer ADDR_W      = 9;
    localparam integer RAW_RD_LAT  = 2;
    localparam integer PROC_RD_LAT = 2;

    assign rx_sample_ready = 1'b1;

    // =========================================================================
    // SLOT STATE
    // =========================================================================
    reg        slot_valid0,      slot_valid1;
    reg [9:0]  slot_row_id0,     slot_row_id1;
    reg [3:0]  slot_batch_mask0, slot_batch_mask1;
    reg        slot_raw_ready0,  slot_raw_ready1;
    reg        slot_proc_ready0, slot_proc_ready1;
    reg        slot_busy_dsp0,   slot_busy_dsp1;
    reg        slot_busy_tx0,    slot_busy_tx1;

    reg        cmd_alloc_v;
    reg        cmd_alloc_slot;
    reg [9:0]  cmd_alloc_row_id;

    reg        cmd_batchdone_v;
    reg        cmd_batchdone_slot;
    reg [1:0]  cmd_batchdone_batchid;

    reg        cmd_dsp_launch_v;
    reg        cmd_dsp_launch_slot;

    reg        cmd_dsp_done_v;
    reg        cmd_dsp_done_slot;

    reg        cmd_tx_launch_v;
    reg        cmd_tx_launch_slot;

    reg        cmd_tx_done_v;
    reg        cmd_tx_done_slot;

    // =========================================================================
    // RX BLOCK STATE
    // =========================================================================
    reg        rx_active;
    reg        rx_drop;
    reg        rx_slot_sel;
    reg [8:0]  rx_addr;
    reg [1:0]  rx_batch_id_reg;

    reg        rx_target_found;
    reg        rx_target_slot;

    // raw BRAM write port (RX owns port A)
    reg  [ADDR_W-1:0] raw0_addra, raw1_addra;
    reg  [63:0]       raw0_dina,  raw1_dina;
    reg               raw0_ena,   raw1_ena;
    reg               raw0_wea,   raw1_wea;

    // =========================================================================
    // DSP BLOCK STATE
    // =========================================================================
    reg        dsp_active;
    reg        dsp_slot_sel;
    reg [9:0]  dsp_issue_idx;
    reg [9:0]  dsp_write_idx;

    reg        dsp_req_pending;
    reg        dsp_req_slot;
    reg [8:0]  dsp_req_addr;
    reg        dsp_req_start;

    reg        dsp_rd_v     [0:RAW_RD_LAT];
    reg        dsp_rd_slot  [0:RAW_RD_LAT];
    reg        dsp_rd_start [0:RAW_RD_LAT];

    reg        dsp_data_v;
    reg        dsp_data_slot;
    reg        dsp_data_start;

    reg        proc_wr_pending;
    reg        proc_wr_slot;
    reg [8:0]  proc_wr_addr;
    reg [63:0] proc_wr_data;
    reg        proc_wr_last;

    reg        proc_wr_done_pending;
    reg        proc_wr_done_slot;

    // raw BRAM read port (DSP owns port B)
    reg  [ADDR_W-1:0] raw0_addrb, raw1_addrb;
    reg               raw0_enb,   raw1_enb;
    wire [63:0]       raw0_doutb, raw1_doutb;

    // proc BRAM write port (DSP owns port A)
    reg  [ADDR_W-1:0] proc0_addra, proc1_addra;
    reg  [63:0]       proc0_dina,  proc1_dina;
    reg               proc0_ena,   proc1_ena;
    reg               proc0_wea,   proc1_wea;

    // =========================================================================
    // TX BLOCK STATE
    // =========================================================================
    reg        tx_active;
    reg        tx_slot_sel;
    reg [9:0]  tx_issue_idx;

    reg        tx_req_pending;
    reg        tx_req_slot;
    reg [8:0]  tx_req_addr;
    reg        tx_req_start;
    reg        tx_req_last;

    reg        tx_rd_v     [0:PROC_RD_LAT];
    reg        tx_rd_slot  [0:PROC_RD_LAT];
    reg        tx_rd_start [0:PROC_RD_LAT];
    reg        tx_rd_last  [0:PROC_RD_LAT];

    reg        tx_data_v;
    reg        tx_data_slot;
    reg        tx_data_start;
    reg        tx_data_last;

    reg        tx_cap_valid;
    reg        tx_cap_slot;
    reg        tx_cap_start;
    reg        tx_cap_last;
    reg [63:0] tx_cap_data;

    reg        tx_valid_reg;
    reg        tx_start_reg;
    reg        tx_last_reg;
    reg [9:0]  tx_row_id_reg;
    reg [31:0] tx_re_reg;
    reg [31:0] tx_im_reg;

    wire tx_accept = tx_valid_reg && tx_row_ready;

    assign tx_row_valid  = tx_valid_reg;
    assign tx_row_start  = tx_start_reg;
    assign tx_row_row_id = tx_row_id_reg;
    assign tx_row_re     = tx_re_reg;
    assign tx_row_im     = tx_im_reg;

    // proc BRAM read port (TX owns port B)
    reg  [ADDR_W-1:0] proc0_addrb, proc1_addrb;
    reg               proc0_enb,   proc1_enb;
    wire [63:0]       proc0_doutb, proc1_doutb;

    // =========================================================================
    // BRAM INSTANCES
    // =========================================================================
    bmg u_raw_mem0 (
        .clka(clk), .clkb(clk),
        .ena(raw0_ena), .wea(raw0_wea), .addra(raw0_addra), .dina(raw0_dina),
        .enb(raw0_enb), .addrb(raw0_addrb), .doutb(raw0_doutb)
    );

    bmg u_raw_mem1 (
        .clka(clk), .clkb(clk),
        .ena(raw1_ena), .wea(raw1_wea), .addra(raw1_addra), .dina(raw1_dina),
        .enb(raw1_enb), .addrb(raw1_addrb), .doutb(raw1_doutb)
    );

    bmg u_proc_mem0 (
        .clka(clk), .clkb(clk),
        .ena(proc0_ena), .wea(proc0_wea), .addra(proc0_addra), .dina(proc0_dina),
        .enb(proc0_enb), .addrb(proc0_addrb), .doutb(proc0_doutb)
    );

    bmg u_proc_mem1 (
        .clka(clk), .clkb(clk),
        .ena(proc1_ena), .wea(proc1_wea), .addra(proc1_addra), .dina(proc1_dina),
        .enb(proc1_enb), .addrb(proc1_addrb), .doutb(proc1_doutb)
    );

    // =========================================================================
    // COMBINATIONAL RX SLOT PICKER
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
    // 1) SLOT-STATE BLOCK
    // =========================================================================
    always @(posedge clk or posedge rst) begin : slot_state_block
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
        end
        else begin
            if (cmd_alloc_v) begin
                if (!cmd_alloc_slot) begin
                    if (!slot_valid0) begin
                        slot_valid0      <= 1'b1;
                        slot_row_id0     <= cmd_alloc_row_id;
                        slot_batch_mask0 <= 4'd0;
                        slot_raw_ready0  <= 1'b0;
                        slot_proc_ready0 <= 1'b0;
                    end
                end
                else begin
                    if (!slot_valid1) begin
                        slot_valid1      <= 1'b1;
                        slot_row_id1     <= cmd_alloc_row_id;
                        slot_batch_mask1 <= 4'd0;
                        slot_raw_ready1  <= 1'b0;
                        slot_proc_ready1 <= 1'b0;
                    end
                end
            end

            if (cmd_batchdone_v) begin
                if (!cmd_batchdone_slot) begin
                    slot_batch_mask0 <= slot_batch_mask0 | (4'b0001 << cmd_batchdone_batchid);
                    if ((slot_batch_mask0 | (4'b0001 << cmd_batchdone_batchid)) == 4'b1111)
                        slot_raw_ready0 <= 1'b1;
                end
                else begin
                    slot_batch_mask1 <= slot_batch_mask1 | (4'b0001 << cmd_batchdone_batchid);
                    if ((slot_batch_mask1 | (4'b0001 << cmd_batchdone_batchid)) == 4'b1111)
                        slot_raw_ready1 <= 1'b1;
                end
            end

            if (cmd_dsp_launch_v) begin
                if (!cmd_dsp_launch_slot) begin
                    slot_raw_ready0 <= 1'b0;
                    slot_busy_dsp0  <= 1'b1;
                end
                else begin
                    slot_raw_ready1 <= 1'b0;
                    slot_busy_dsp1  <= 1'b1;
                end
            end

            if (cmd_dsp_done_v) begin
                if (!cmd_dsp_done_slot) begin
                    slot_proc_ready0 <= 1'b1;
                    slot_busy_dsp0   <= 1'b0;
                end
                else begin
                    slot_proc_ready1 <= 1'b1;
                    slot_busy_dsp1   <= 1'b0;
                end
            end

            if (cmd_tx_launch_v) begin
                if (!cmd_tx_launch_slot)
                    slot_busy_tx0 <= 1'b1;
                else
                    slot_busy_tx1 <= 1'b1;
            end

            if (cmd_tx_done_v) begin
                if (!cmd_tx_done_slot) begin
                    slot_valid0      <= 1'b0;
                    slot_row_id0     <= 10'd0;
                    slot_batch_mask0 <= 4'd0;
                    slot_raw_ready0  <= 1'b0;
                    slot_proc_ready0 <= 1'b0;
                    slot_busy_tx0    <= 1'b0;
                end
                else begin
                    slot_valid1      <= 1'b0;
                    slot_row_id1     <= 10'd0;
                    slot_batch_mask1 <= 4'd0;
                    slot_raw_ready1  <= 1'b0;
                    slot_proc_ready1 <= 1'b0;
                    slot_busy_tx1    <= 1'b0;
                end
            end
        end
    end

    // =========================================================================
    // 2) RX BLOCK
    // =========================================================================
    always @(posedge clk or posedge rst) begin : rx_block
        if (rst) begin
            rx_active        <= 1'b0;
            rx_drop          <= 1'b0;
            rx_slot_sel      <= 1'b0;
            rx_addr          <= 9'd0;
            rx_batch_id_reg  <= 2'd0;
            rx_overflow      <= 1'b0;

            raw0_addra       <= {ADDR_W{1'b0}};
            raw1_addra       <= {ADDR_W{1'b0}};
            raw0_dina        <= 64'd0;
            raw1_dina        <= 64'd0;
            raw0_ena         <= 1'b0;
            raw1_ena         <= 1'b0;
            raw0_wea         <= 1'b0;
            raw1_wea         <= 1'b0;

            cmd_alloc_v           <= 1'b0;
            cmd_alloc_slot        <= 1'b0;
            cmd_alloc_row_id      <= 10'd0;
            cmd_batchdone_v       <= 1'b0;
            cmd_batchdone_slot    <= 1'b0;
            cmd_batchdone_batchid <= 2'd0;
        end
        else begin
            raw0_ena    <= 1'b0;
            raw1_ena    <= 1'b0;
            raw0_wea    <= 1'b0;
            raw1_wea    <= 1'b0;
            rx_overflow <= 1'b0;

            cmd_alloc_v      <= 1'b0;
            cmd_batchdone_v  <= 1'b0;

            if (rx_sample_valid) begin
                if (rx_batch_start) begin
                    rx_batch_id_reg <= rx_batch_id;

                    if (rx_target_found) begin
                        rx_active   <= 1'b1;
                        rx_drop     <= 1'b0;
                        rx_slot_sel <= rx_target_slot;
                        rx_addr     <= {rx_batch_id, 7'd0};

                        if ((!rx_target_slot && !slot_valid0) ||
                            ( rx_target_slot && !slot_valid1)) begin
                            cmd_alloc_v      <= 1'b1;
                            cmd_alloc_slot   <= rx_target_slot;
                            cmd_alloc_row_id <= rx_batch_row_id;
                        end

                        if (!rx_target_slot) begin
                            raw0_ena   <= 1'b1;
                            raw0_wea   <= 1'b1;
                            raw0_addra <= {rx_batch_id, 7'd0};
                            raw0_dina  <= {rx_sample_re, rx_sample_im};
                        end
                        else begin
                            raw1_ena   <= 1'b1;
                            raw1_wea   <= 1'b1;
                            raw1_addra <= {rx_batch_id, 7'd0};
                            raw1_dina  <= {rx_sample_re, rx_sample_im};
                        end

                        if (rx_sample_last) begin
                            rx_active             <= 1'b0;
                            cmd_batchdone_v       <= 1'b1;
                            cmd_batchdone_slot    <= rx_target_slot;
                            cmd_batchdone_batchid <= rx_batch_id;
                        end
                        else begin
                            rx_addr <= {rx_batch_id, 7'd0} + 9'd1;
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
                        raw0_dina  <= {rx_sample_re, rx_sample_im};
                    end
                    else begin
                        raw1_ena   <= 1'b1;
                        raw1_wea   <= 1'b1;
                        raw1_addra <= rx_addr;
                        raw1_dina  <= {rx_sample_re, rx_sample_im};
                    end

                    if (rx_sample_last) begin
                        rx_active             <= 1'b0;
                        cmd_batchdone_v       <= 1'b1;
                        cmd_batchdone_slot    <= rx_slot_sel;
                        cmd_batchdone_batchid <= rx_batch_id_reg;
                    end
                    else begin
                        rx_addr <= rx_addr + 9'd1;
                    end
                end
                else if (rx_drop) begin
                    if (rx_sample_last)
                        rx_drop <= 1'b0;
                end
            end
        end
    end

    // =========================================================================
    // 3) DSP BLOCK
    // =========================================================================
    integer i;
    always @(posedge clk or posedge rst) begin : dsp_block
        if (rst) begin
            dsp_active       <= 1'b0;
            dsp_slot_sel     <= 1'b0;
            dsp_issue_idx    <= 10'd0;
            dsp_write_idx    <= 10'd0;

            dsp_req_pending  <= 1'b0;
            dsp_req_slot     <= 1'b0;
            dsp_req_addr     <= 9'd0;
            dsp_req_start    <= 1'b0;

            for (i = 0; i <= RAW_RD_LAT; i = i + 1) begin
                dsp_rd_v[i]     <= 1'b0;
                dsp_rd_slot[i]  <= 1'b0;
                dsp_rd_start[i] <= 1'b0;
            end

            dsp_data_v       <= 1'b0;
            dsp_data_slot    <= 1'b0;
            dsp_data_start   <= 1'b0;

            proc_wr_pending      <= 1'b0;
            proc_wr_slot         <= 1'b0;
            proc_wr_addr         <= 9'd0;
            proc_wr_data         <= 64'd0;
            proc_wr_last         <= 1'b0;
            proc_wr_done_pending <= 1'b0;
            proc_wr_done_slot    <= 1'b0;

            raw0_addrb       <= {ADDR_W{1'b0}};
            raw1_addrb       <= {ADDR_W{1'b0}};
            raw0_enb         <= 1'b0;
            raw1_enb         <= 1'b0;

            proc0_addra      <= {ADDR_W{1'b0}};
            proc1_addra      <= {ADDR_W{1'b0}};
            proc0_dina       <= 64'd0;
            proc1_dina       <= 64'd0;
            proc0_ena        <= 1'b0;
            proc1_ena        <= 1'b0;
            proc0_wea        <= 1'b0;
            proc1_wea        <= 1'b0;

            dsp_in_valid     <= 1'b0;
            dsp_in_row_start <= 1'b0;
            dsp_in_re        <= 32'd0;
            dsp_in_im        <= 32'd0;

            cmd_dsp_launch_v    <= 1'b0;
            cmd_dsp_launch_slot <= 1'b0;
            cmd_dsp_done_v      <= 1'b0;
            cmd_dsp_done_slot   <= 1'b0;
        end
        else begin
            // keep raw BRAM read enable alive while DSP is active or a read is pending
            raw0_enb <= ((dsp_active || dsp_req_pending) && !dsp_slot_sel) ||
                        (dsp_req_pending && !dsp_req_slot);
            raw1_enb <= ((dsp_active || dsp_req_pending) &&  dsp_slot_sel) ||
                        (dsp_req_pending &&  dsp_req_slot);

            proc0_ena        <= 1'b0;
            proc1_ena        <= 1'b0;
            proc0_wea        <= 1'b0;
            proc1_wea        <= 1'b0;
            dsp_in_valid     <= 1'b0;
            dsp_in_row_start <= 1'b0;

            cmd_dsp_launch_v <= 1'b0;
            cmd_dsp_done_v   <= 1'b0;

            for (i = RAW_RD_LAT; i > 0; i = i - 1) begin
                dsp_rd_v[i]     <= dsp_rd_v[i-1];
                dsp_rd_slot[i]  <= dsp_rd_slot[i-1];
                dsp_rd_start[i] <= dsp_rd_start[i-1];
            end
            dsp_rd_v[0]     <= 1'b0;
            dsp_rd_slot[0]  <= 1'b0;
            dsp_rd_start[0] <= 1'b0;

            dsp_data_v <= 1'b0;
            if (dsp_rd_v[RAW_RD_LAT]) begin
                dsp_data_v     <= 1'b1;
                dsp_data_slot  <= dsp_rd_slot[RAW_RD_LAT];
                dsp_data_start <= dsp_rd_start[RAW_RD_LAT];
            end

            if (dsp_data_v) begin
                dsp_in_valid     <= 1'b1;
                dsp_in_row_start <= dsp_data_start;
                if (!dsp_data_slot) begin
                    dsp_in_re <= raw0_doutb[63:32];
                    dsp_in_im <= raw0_doutb[31:0];
                end
                else begin
                    dsp_in_re <= raw1_doutb[63:32];
                    dsp_in_im <= raw1_doutb[31:0];
                end
            end

            if (!dsp_active) begin
                if (slot_raw_ready0 && !slot_proc_ready0 && !slot_busy_dsp0 && !slot_busy_tx0) begin
                    dsp_active            <= 1'b1;
                    dsp_slot_sel          <= 1'b0;
                    dsp_issue_idx         <= 10'd0;
                    dsp_write_idx         <= 10'd0;
                    dsp_req_pending       <= 1'b0;
                    proc_wr_pending       <= 1'b0;
                    proc_wr_done_pending  <= 1'b0;
                    raw0_addrb            <= 9'd0;

                    cmd_dsp_launch_v      <= 1'b1;
                    cmd_dsp_launch_slot   <= 1'b0;
                end
                else if (slot_raw_ready1 && !slot_proc_ready1 && !slot_busy_dsp1 && !slot_busy_tx1) begin
                    dsp_active            <= 1'b1;
                    dsp_slot_sel          <= 1'b1;
                    dsp_issue_idx         <= 10'd0;
                    dsp_write_idx         <= 10'd0;
                    dsp_req_pending       <= 1'b0;
                    proc_wr_pending       <= 1'b0;
                    proc_wr_done_pending  <= 1'b0;
                    raw1_addrb            <= 9'd0;

                    cmd_dsp_launch_v      <= 1'b1;
                    cmd_dsp_launch_slot   <= 1'b1;
                end
            end

            if (dsp_active && !dsp_req_pending && (dsp_issue_idx < ROW_SAMPLES)) begin
                dsp_req_pending <= 1'b1;
                dsp_req_slot    <= dsp_slot_sel;
                dsp_req_addr    <= dsp_issue_idx[ADDR_W-1:0];
                dsp_req_start   <= (dsp_issue_idx == 10'd0);
                dsp_issue_idx   <= dsp_issue_idx + 10'd1;
            end

            if (dsp_req_pending) begin
                if (!dsp_req_slot)
                    raw0_addrb <= dsp_req_addr;
                else
                    raw1_addrb <= dsp_req_addr;

                dsp_rd_v[0]     <= 1'b1;
                dsp_rd_slot[0]  <= dsp_req_slot;
                dsp_rd_start[0] <= dsp_req_start;

                dsp_req_pending <= 1'b0;
            end

            if (proc_wr_pending) begin
                if (!proc_wr_slot) begin
                    proc0_ena   <= 1'b1;
                    proc0_wea   <= 1'b1;
                    proc0_addra <= proc_wr_addr;
                    proc0_dina  <= proc_wr_data;
                end
                else begin
                    proc1_ena   <= 1'b1;
                    proc1_wea   <= 1'b1;
                    proc1_addra <= proc_wr_addr;
                    proc1_dina  <= proc_wr_data;
                end

                if (proc_wr_last) begin
                    proc_wr_done_pending <= 1'b1;
                    proc_wr_done_slot    <= proc_wr_slot;
                    dsp_active           <= 1'b0;
                end

                proc_wr_pending <= 1'b0;
            end

            if (proc_wr_done_pending) begin
                cmd_dsp_done_v       <= 1'b1;
                cmd_dsp_done_slot    <= proc_wr_done_slot;
                proc_wr_done_pending <= 1'b0;
            end

            if (dsp_out_valid) begin
                proc_wr_pending <= 1'b1;
                proc_wr_slot    <= dsp_slot_sel;
                proc_wr_addr    <= dsp_write_idx[ADDR_W-1:0];
                proc_wr_data    <= {dsp_out_re, dsp_out_im};
                proc_wr_last    <= (dsp_write_idx == ROW_SAMPLES-1);

                dsp_write_idx   <= dsp_write_idx + 10'd1;
            end
        end
    end

    // =========================================================================
    // 4) TX BLOCK
    // =========================================================================
    always @(posedge clk or posedge rst) begin : tx_block
        if (rst) begin
            tx_active        <= 1'b0;
            tx_slot_sel      <= 1'b0;
            tx_issue_idx     <= 10'd0;

            tx_req_pending   <= 1'b0;
            tx_req_slot      <= 1'b0;
            tx_req_addr      <= 9'd0;
            tx_req_start     <= 1'b0;
            tx_req_last      <= 1'b0;

            for (i = 0; i <= PROC_RD_LAT; i = i + 1) begin
                tx_rd_v[i]     <= 1'b0;
                tx_rd_slot[i]  <= 1'b0;
                tx_rd_start[i] <= 1'b0;
                tx_rd_last[i]  <= 1'b0;
            end

            tx_data_v        <= 1'b0;
            tx_data_slot     <= 1'b0;
            tx_data_start    <= 1'b0;
            tx_data_last     <= 1'b0;

            tx_cap_valid     <= 1'b0;
            tx_cap_slot      <= 1'b0;
            tx_cap_start     <= 1'b0;
            tx_cap_last      <= 1'b0;
            tx_cap_data      <= 64'd0;

            tx_valid_reg     <= 1'b0;
            tx_start_reg     <= 1'b0;
            tx_last_reg      <= 1'b0;
            tx_row_id_reg    <= 10'd0;
            tx_re_reg        <= 32'd0;
            tx_im_reg        <= 32'd0;

            proc0_addrb      <= {ADDR_W{1'b0}};
            proc1_addrb      <= {ADDR_W{1'b0}};
            proc0_enb        <= 1'b0;
            proc1_enb        <= 1'b0;

            row_tx_done      <= 1'b0;

            cmd_tx_launch_v    <= 1'b0;
            cmd_tx_launch_slot <= 1'b0;
            cmd_tx_done_v      <= 1'b0;
            cmd_tx_done_slot   <= 1'b0;
        end
        else begin
            row_tx_done     <= 1'b0;
            cmd_tx_launch_v <= 1'b0;
            cmd_tx_done_v   <= 1'b0;

            // keep proc BRAM read enable alive while TX is active or a read is pending
            proc0_enb <= ((tx_active || tx_req_pending) && !tx_slot_sel) ||
                         (tx_req_pending && !tx_req_slot);
            proc1_enb <= ((tx_active || tx_req_pending) &&  tx_slot_sel) ||
                         (tx_req_pending &&  tx_req_slot);

            if (!tx_valid_reg && !tx_cap_valid) begin
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
            end

            tx_data_v <= 1'b0;
            if (!tx_valid_reg && !tx_cap_valid && tx_rd_v[PROC_RD_LAT]) begin
                tx_data_v     <= 1'b1;
                tx_data_slot  <= tx_rd_slot[PROC_RD_LAT];
                tx_data_start <= tx_rd_start[PROC_RD_LAT];
                tx_data_last  <= tx_rd_last[PROC_RD_LAT];
            end

            if (!tx_active && !tx_valid_reg && !tx_cap_valid && !tx_req_pending) begin
                if (slot_proc_ready0 && !slot_busy_tx0 && !slot_busy_dsp0) begin
                    tx_active          <= 1'b1;
                    tx_slot_sel        <= 1'b0;
                    tx_issue_idx       <= 10'd1;

                    tx_req_pending     <= 1'b1;
                    tx_req_slot        <= 1'b0;
                    tx_req_addr        <= 9'd0;
                    tx_req_start       <= 1'b1;
                    tx_req_last        <= (ROW_SAMPLES == 1);

                    proc0_addrb        <= 9'd0;

                    cmd_tx_launch_v    <= 1'b1;
                    cmd_tx_launch_slot <= 1'b0;
                end
                else if (slot_proc_ready1 && !slot_busy_tx1 && !slot_busy_dsp1) begin
                    tx_active          <= 1'b1;
                    tx_slot_sel        <= 1'b1;
                    tx_issue_idx       <= 10'd1;

                    tx_req_pending     <= 1'b1;
                    tx_req_slot        <= 1'b1;
                    tx_req_addr        <= 9'd0;
                    tx_req_start       <= 1'b1;
                    tx_req_last        <= (ROW_SAMPLES == 1);

                    proc1_addrb        <= 9'd0;

                    cmd_tx_launch_v    <= 1'b1;
                    cmd_tx_launch_slot <= 1'b1;
                end
            end

            if (tx_req_pending && !tx_valid_reg && !tx_cap_valid) begin
                if (!tx_req_slot)
                    proc0_addrb <= tx_req_addr;
                else
                    proc1_addrb <= tx_req_addr;

                tx_rd_v[0]     <= 1'b1;
                tx_rd_slot[0]  <= tx_req_slot;
                tx_rd_start[0] <= tx_req_start;
                tx_rd_last[0]  <= tx_req_last;

                tx_req_pending <= 1'b0;
            end

            if (!tx_valid_reg && !tx_cap_valid && tx_data_v) begin
                tx_cap_valid <= 1'b1;
                tx_cap_slot  <= tx_data_slot;
                tx_cap_start <= tx_data_start;
                tx_cap_last  <= tx_data_last;

                if (!tx_data_slot)
                    tx_cap_data <= proc0_doutb;
                else
                    tx_cap_data <= proc1_doutb;
            end

            if (!tx_valid_reg && tx_cap_valid) begin
                tx_valid_reg  <= 1'b1;
                tx_start_reg  <= tx_cap_start;
                tx_last_reg   <= tx_cap_last;
                tx_row_id_reg <= tx_cap_slot ? slot_row_id1 : slot_row_id0;
                tx_re_reg     <= tx_cap_data[63:32];
                tx_im_reg     <= tx_cap_data[31:0];
                tx_cap_valid  <= 1'b0;
            end

            if (tx_accept) begin
                tx_valid_reg <= 1'b0;
                tx_start_reg <= 1'b0;

                if (tx_last_reg) begin
                    tx_active        <= 1'b0;
                    tx_last_reg      <= 1'b0;
                    row_tx_done      <= 1'b1;

                    proc0_enb        <= 1'b0;
                    proc1_enb        <= 1'b0;

                    cmd_tx_done_v    <= 1'b1;
                    cmd_tx_done_slot <= tx_slot_sel;
                end
                else begin
                    tx_req_pending <= 1'b1;
                    tx_req_slot    <= tx_slot_sel;
                    tx_req_addr    <= tx_issue_idx[ADDR_W-1:0];
                    tx_req_start   <= 1'b0;
                    tx_req_last    <= (tx_issue_idx == ROW_SAMPLES-1);

                    tx_issue_idx   <= tx_issue_idx + 10'd1;
                end
            end
        end
    end

endmodule
