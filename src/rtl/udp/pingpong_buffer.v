

module ppbuf_ram_sdp_2cyc #(
    parameter ADDR_W = 9,
    parameter DATA_W = 64,
    parameter DEPTH  = 512
) (
    input  wire                 clk,

    // Port A: write
    input  wire                 ena,
    input  wire                 wea,
    input  wire [ADDR_W-1:0]    addra,
    input  wire [DATA_W-1:0]    dina,

    // Port B: read
    input  wire                 enb,
    input  wire [ADDR_W-1:0]    addrb,
    output reg  [DATA_W-1:0]    doutb
);
    reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [DATA_W-1:0] rd_s1;

    always @(posedge clk) begin
        if (ena && wea)
            mem[addra] <= dina;

        if (enb)
            rd_s1 <= mem[addrb];

        doutb <= rd_s1;
    end
endmodule

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

    localparam integer ROW_SAMPLES  = 512;
    localparam integer ADDR_W       = 9;
    localparam integer RAW_RD_LAT   = 2; // BMG/common BRAM read latency
    localparam integer PROC_RD_LAT  = 2; // BMG/common BRAM read latency

    assign rx_sample_ready = 1'b1;

    // -------------------------------------------------------------------------
    // Slot metadata
    // -------------------------------------------------------------------------
    reg        slot_valid0,      slot_valid1;
    reg [9:0]  slot_row_id0,     slot_row_id1;
    reg [3:0]  slot_batch_mask0, slot_batch_mask1;
    reg        slot_raw_ready0,  slot_raw_ready1;
    reg        slot_proc_ready0, slot_proc_ready1;
    reg        slot_busy_dsp0,   slot_busy_dsp1;
    reg        slot_busy_tx0,    slot_busy_tx1;

    // -------------------------------------------------------------------------
    // RX state
    // -------------------------------------------------------------------------
    reg        rx_active;
    reg        rx_drop;
    reg        rx_slot_sel;
    reg [8:0]  rx_addr;
    reg [1:0]  rx_batch_id_reg;

    // -------------------------------------------------------------------------
    // DSP state
    // -------------------------------------------------------------------------
    reg        dsp_active;
    reg        dsp_slot_sel;
    reg [9:0]  dsp_issue_idx;
    reg [9:0]  dsp_write_idx;

    // raw-memory read request metadata pipeline
    reg                    dsp_rd_v [0:RAW_RD_LAT];
    reg                    dsp_rd_slot [0:RAW_RD_LAT];
    reg                    dsp_rd_start [0:RAW_RD_LAT];

    // -------------------------------------------------------------------------
    // TX state
    // -------------------------------------------------------------------------
    reg        tx_active;
    reg        tx_slot_sel;
    reg [9:0]  tx_issue_idx;

    // processed-memory read request metadata pipeline
    reg                    tx_rd_v [0:PROC_RD_LAT];
    reg                    tx_rd_slot [0:PROC_RD_LAT];
    reg                    tx_rd_start [0:PROC_RD_LAT];
    reg                    tx_rd_last [0:PROC_RD_LAT];

    // one extra capture stage for real BRAM/BMG alignment
    reg                    tx_cap_valid;
    reg                    tx_cap_slot;
    reg                    tx_cap_start;
    reg                    tx_cap_last;
    reg [63:0]             tx_cap_data;

    // held TX beat
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

    // -------------------------------------------------------------------------
    // RX slot selection helper
    // -------------------------------------------------------------------------
    reg rx_target_found;
    reg rx_target_slot;

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

    // -------------------------------------------------------------------------
    // BRAM control signals
    // -------------------------------------------------------------------------
    reg  [8:0]  raw0_addra, raw1_addra, proc0_addra, proc1_addra;
    reg  [63:0] raw0_dina,  raw1_dina,  proc0_dina,  proc1_dina;
    reg         raw0_ena,   raw1_ena,   proc0_ena,   proc1_ena;
    reg         raw0_wea,   raw1_wea,   proc0_wea,   proc1_wea;

    reg  [8:0]  raw0_addrb, raw1_addrb, proc0_addrb, proc1_addrb;
    reg         raw0_enb,   raw1_enb,   proc0_enb,   proc1_enb;
    wire [63:0] raw0_doutb, raw1_doutb, proc0_doutb, proc1_doutb;

    // -------------------------------------------------------------------------
    // Replace these four with your real BMG instances if desired.
    // The port names match the simple dual-port style used earlier.
    // -------------------------------------------------------------------------
    ppbuf_ram_sdp_2cyc u_raw_mem0 (
        .clk(clk),
        .ena(raw0_ena), .wea(raw0_wea), .addra(raw0_addra), .dina(raw0_dina),
        .enb(raw0_enb), .addrb(raw0_addrb), .doutb(raw0_doutb)
    );

    ppbuf_ram_sdp_2cyc u_raw_mem1 (
        .clk(clk),
        .ena(raw1_ena), .wea(raw1_wea), .addra(raw1_addra), .dina(raw1_dina),
        .enb(raw1_enb), .addrb(raw1_addrb), .doutb(raw1_doutb)
    );

    ppbuf_ram_sdp_2cyc u_proc_mem0 (
        .clk(clk),
        .ena(proc0_ena), .wea(proc0_wea), .addra(proc0_addra), .dina(proc0_dina),
        .enb(proc0_enb), .addrb(proc0_addrb), .doutb(proc0_doutb)
    );

    ppbuf_ram_sdp_2cyc u_proc_mem1 (
        .clk(clk),
        .ena(proc1_ena), .wea(proc1_wea), .addra(proc1_addra), .dina(proc1_dina),
        .enb(proc1_enb), .addrb(proc1_addrb), .doutb(proc1_doutb)
    );

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

            rx_active        <= 1'b0;
            rx_drop          <= 1'b0;
            rx_slot_sel      <= 1'b0;
            rx_addr          <= 9'd0;
            rx_batch_id_reg  <= 2'd0;

            dsp_active       <= 1'b0;
            dsp_slot_sel     <= 1'b0;
            dsp_issue_idx    <= 10'd0;
            dsp_write_idx    <= 10'd0;

            tx_active        <= 1'b0;
            tx_slot_sel      <= 1'b0;
            tx_issue_idx     <= 10'd0;

            for (i = 0; i <= RAW_RD_LAT; i = i + 1) begin
                dsp_rd_v[i]     <= 1'b0;
                dsp_rd_slot[i]  <= 1'b0;
                dsp_rd_start[i] <= 1'b0;
            end

            for (i = 0; i <= PROC_RD_LAT; i = i + 1) begin
                tx_rd_v[i]     <= 1'b0;
                tx_rd_slot[i]  <= 1'b0;
                tx_rd_start[i] <= 1'b0;
                tx_rd_last[i]  <= 1'b0;
            end

            tx_cap_valid      <= 1'b0;
            tx_cap_slot       <= 1'b0;
            tx_cap_start      <= 1'b0;
            tx_cap_last       <= 1'b0;
            tx_cap_data       <= 64'd0;

            dsp_in_valid      <= 1'b0;
            dsp_in_row_start  <= 1'b0;
            dsp_in_re         <= 32'd0;
            dsp_in_im         <= 32'd0;

            tx_valid_reg      <= 1'b0;
            tx_start_reg      <= 1'b0;
            tx_last_reg       <= 1'b0;
            tx_row_id_reg     <= 10'd0;
            tx_re_reg         <= 32'd0;
            tx_im_reg         <= 32'd0;

            rx_overflow       <= 1'b0;
            row_tx_done       <= 1'b0;

            raw0_addra        <= 9'd0;
            raw1_addra        <= 9'd0;
            proc0_addra       <= 9'd0;
            proc1_addra       <= 9'd0;
            raw0_dina         <= 64'd0;
            raw1_dina         <= 64'd0;
            proc0_dina        <= 64'd0;
            proc1_dina        <= 64'd0;
            raw0_ena          <= 1'b0;
            raw1_ena          <= 1'b0;
            proc0_ena         <= 1'b0;
            proc1_ena         <= 1'b0;
            raw0_wea          <= 1'b0;
            raw1_wea          <= 1'b0;
            proc0_wea         <= 1'b0;
            proc1_wea         <= 1'b0;
            raw0_addrb        <= 9'd0;
            raw1_addrb        <= 9'd0;
            proc0_addrb       <= 9'd0;
            proc1_addrb       <= 9'd0;
            raw0_enb          <= 1'b0;
            raw1_enb          <= 1'b0;
            proc0_enb         <= 1'b0;
            proc1_enb         <= 1'b0;
        end
        else begin
            // defaults
            dsp_in_valid     <= 1'b0;
            dsp_in_row_start <= 1'b0;
            rx_overflow      <= 1'b0;
            row_tx_done      <= 1'b0;

            raw0_ena         <= 1'b0;
            raw1_ena         <= 1'b0;
            proc0_ena        <= 1'b0;
            proc1_ena        <= 1'b0;
            raw0_wea         <= 1'b0;
            raw1_wea         <= 1'b0;
            proc0_wea        <= 1'b0;
            proc1_wea        <= 1'b0;
            raw0_enb         <= 1'b0;
            raw1_enb         <= 1'b0;
            proc0_enb        <= 1'b0;
            proc1_enb        <= 1'b0;

            // -----------------------------------------------------------------
            // advance DSP read metadata pipeline
            // -----------------------------------------------------------------
            for (i = RAW_RD_LAT; i > 0; i = i - 1) begin
                dsp_rd_v[i]     <= dsp_rd_v[i-1];
                dsp_rd_slot[i]  <= dsp_rd_slot[i-1];
                dsp_rd_start[i] <= dsp_rd_start[i-1];
            end
            dsp_rd_v[0]     <= 1'b0;
            dsp_rd_slot[0]  <= 1'b0;
            dsp_rd_start[0] <= 1'b0;

            // -----------------------------------------------------------------
            // advance TX read metadata pipeline only if output holder is free
            // -----------------------------------------------------------------
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

            // -----------------------------------------------------------------
            // RX batch assembly
            // -----------------------------------------------------------------
            if (rx_sample_valid) begin
                if (rx_batch_start) begin
                    rx_batch_id_reg <= rx_batch_id;

                    if (rx_target_found) begin
                        rx_active   <= 1'b1;
                        rx_drop     <= 1'b0;
                        rx_slot_sel <= rx_target_slot;
                        rx_addr     <= {rx_batch_id, 7'd0};

                        if (!rx_target_slot) begin
                            if (!slot_valid0) begin
                                slot_valid0      <= 1'b1;
                                slot_row_id0     <= rx_batch_row_id;
                                slot_batch_mask0 <= 4'd0;
                                slot_raw_ready0  <= 1'b0;
                                slot_proc_ready0 <= 1'b0;
                            end

                            raw0_ena   <= 1'b1;
                            raw0_wea   <= 1'b1;
                            raw0_addra <= {rx_batch_id, 7'd0};
                            raw0_dina  <= {rx_sample_re, rx_sample_im};

                            if (rx_sample_last) begin
                                rx_active        <= 1'b0;
                                slot_batch_mask0 <= slot_batch_mask0 | (4'b0001 << rx_batch_id);
                                if ((slot_batch_mask0 | (4'b0001 << rx_batch_id)) == 4'b1111)
                                    slot_raw_ready0 <= 1'b1;
                            end else begin
                                rx_addr <= {rx_batch_id, 7'd0} + 9'd1;
                            end
                        end
                        else begin
                            if (!slot_valid1) begin
                                slot_valid1      <= 1'b1;
                                slot_row_id1     <= rx_batch_row_id;
                                slot_batch_mask1 <= 4'd0;
                                slot_raw_ready1  <= 1'b0;
                                slot_proc_ready1 <= 1'b0;
                            end

                            raw1_ena   <= 1'b1;
                            raw1_wea   <= 1'b1;
                            raw1_addra <= {rx_batch_id, 7'd0};
                            raw1_dina  <= {rx_sample_re, rx_sample_im};

                            if (rx_sample_last) begin
                                rx_active        <= 1'b0;
                                slot_batch_mask1 <= slot_batch_mask1 | (4'b0001 << rx_batch_id);
                                if ((slot_batch_mask1 | (4'b0001 << rx_batch_id)) == 4'b1111)
                                    slot_raw_ready1 <= 1'b1;
                            end else begin
                                rx_addr <= {rx_batch_id, 7'd0} + 9'd1;
                            end
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
                    end else begin
                        raw1_ena   <= 1'b1;
                        raw1_wea   <= 1'b1;
                        raw1_addra <= rx_addr;
                        raw1_dina  <= {rx_sample_re, rx_sample_im};
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
                    end else begin
                        rx_addr <= rx_addr + 9'd1;
                    end
                end
                else if (rx_drop) begin
                    if (rx_sample_last)
                        rx_drop <= 1'b0;
                end
            end

            // -----------------------------------------------------------------
            // DSP launch
            // -----------------------------------------------------------------
            if (!dsp_active) begin
                if (slot_raw_ready0 && !slot_proc_ready0 && !slot_busy_dsp0 && !slot_busy_tx0) begin
                    dsp_active      <= 1'b1;
                    dsp_slot_sel    <= 1'b0;
                    dsp_issue_idx   <= 10'd0;
                    dsp_write_idx   <= 10'd0;
                    slot_raw_ready0 <= 1'b0;
                    slot_busy_dsp0  <= 1'b1;
                end
                else if (slot_raw_ready1 && !slot_proc_ready1 && !slot_busy_dsp1 && !slot_busy_tx1) begin
                    dsp_active      <= 1'b1;
                    dsp_slot_sel    <= 1'b1;
                    dsp_issue_idx   <= 10'd0;
                    dsp_write_idx   <= 10'd0;
                    slot_raw_ready1 <= 1'b0;
                    slot_busy_dsp1  <= 1'b1;
                end
            end

            // -----------------------------------------------------------------
            // issue raw-memory reads
            // -----------------------------------------------------------------
            if (dsp_active && (dsp_issue_idx < ROW_SAMPLES)) begin
                if (!dsp_slot_sel) begin
                    raw0_enb   <= 1'b1;
                    raw0_addrb <= dsp_issue_idx[8:0];
                end else begin
                    raw1_enb   <= 1'b1;
                    raw1_addrb <= dsp_issue_idx[8:0];
                end

                dsp_rd_v[0]     <= 1'b1;
                dsp_rd_slot[0]  <= dsp_slot_sel;
                dsp_rd_start[0] <= (dsp_issue_idx == 10'd0);

                dsp_issue_idx   <= dsp_issue_idx + 10'd1;
            end

            // -----------------------------------------------------------------
            // emit DSP input after configured raw read latency
            // -----------------------------------------------------------------
            if (dsp_rd_v[RAW_RD_LAT]) begin
                dsp_in_valid     <= 1'b1;
                dsp_in_row_start <= dsp_rd_start[RAW_RD_LAT];
                if (!dsp_rd_slot[RAW_RD_LAT]) begin
                    dsp_in_re <= raw0_doutb[63:32];
                    dsp_in_im <= raw0_doutb[31:0];
                end else begin
                    dsp_in_re <= raw1_doutb[63:32];
                    dsp_in_im <= raw1_doutb[31:0];
                end
            end

            // -----------------------------------------------------------------
            // write DSP outputs into processed memory
            // -----------------------------------------------------------------
            if (dsp_active && dsp_out_valid) begin
                if (!dsp_slot_sel) begin
                    proc0_ena   <= 1'b1;
                    proc0_wea   <= 1'b1;
                    proc0_addra <= dsp_write_idx[8:0];
                    proc0_dina  <= {dsp_out_re, dsp_out_im};
                end else begin
                    proc1_ena   <= 1'b1;
                    proc1_wea   <= 1'b1;
                    proc1_addra <= dsp_write_idx[8:0];
                    proc1_dina  <= {dsp_out_re, dsp_out_im};
                end

                if (dsp_write_idx == ROW_SAMPLES-1) begin
                    dsp_active <= 1'b0;
                    if (!dsp_slot_sel) begin
                        slot_proc_ready0 <= 1'b1;
                        slot_busy_dsp0   <= 1'b0;
                    end else begin
                        slot_proc_ready1 <= 1'b1;
                        slot_busy_dsp1   <= 1'b0;
                    end
                end

                dsp_write_idx <= dsp_write_idx + 10'd1;
            end

            // -----------------------------------------------------------------
            // TX launch
            // -----------------------------------------------------------------
            if (!tx_active && !tx_valid_reg && !tx_cap_valid) begin
                if (slot_proc_ready0 && !slot_busy_tx0 && !slot_busy_dsp0) begin
                    tx_active      <= 1'b1;
                    tx_slot_sel    <= 1'b0;
                    tx_issue_idx   <= 10'd1;
                    slot_busy_tx0  <= 1'b1;

                    proc0_enb      <= 1'b1;
                    proc0_addrb    <= 9'd0;

                    tx_rd_v[0]     <= 1'b1;
                    tx_rd_slot[0]  <= 1'b0;
                    tx_rd_start[0] <= 1'b1;
                    tx_rd_last[0]  <= (ROW_SAMPLES == 1);
                end
                else if (slot_proc_ready1 && !slot_busy_tx1 && !slot_busy_dsp1) begin
                    tx_active      <= 1'b1;
                    tx_slot_sel    <= 1'b1;
                    tx_issue_idx   <= 10'd1;
                    slot_busy_tx1  <= 1'b1;

                    proc1_enb      <= 1'b1;
                    proc1_addrb    <= 9'd0;

                    tx_rd_v[0]     <= 1'b1;
                    tx_rd_slot[0]  <= 1'b1;
                    tx_rd_start[0] <= 1'b1;
                    tx_rd_last[0]  <= (ROW_SAMPLES == 1);
                end
            end

            // -----------------------------------------------------------------
            // capture BRAM output one cycle after metadata reaches latency point
            // this is the important real-BMG fix
            // -----------------------------------------------------------------
            if (!tx_valid_reg && !tx_cap_valid && tx_rd_v[PROC_RD_LAT]) begin
                tx_cap_valid <= 1'b1;
                tx_cap_slot  <= tx_rd_slot[PROC_RD_LAT];
                tx_cap_start <= tx_rd_start[PROC_RD_LAT];
                tx_cap_last  <= tx_rd_last[PROC_RD_LAT];
                if (!tx_rd_slot[PROC_RD_LAT])
                    tx_cap_data <= proc0_doutb;
                else
                    tx_cap_data <= proc1_doutb;
            end

            // move captured beat into output holding register
            if (!tx_valid_reg && tx_cap_valid) begin
                tx_valid_reg <= 1'b1;
                tx_start_reg <= tx_cap_start;
                tx_last_reg  <= tx_cap_last;
                tx_row_id_reg<= tx_cap_slot ? slot_row_id1 : slot_row_id0;
                tx_re_reg    <= tx_cap_data[63:32];
                tx_im_reg    <= tx_cap_data[31:0];
                tx_cap_valid <= 1'b0;
            end

            // -----------------------------------------------------------------
            // TX handshake / next read issue
            // -----------------------------------------------------------------
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
                        slot_busy_tx0    <= 1'b0;
                    end else begin
                        slot_valid1      <= 1'b0;
                        slot_row_id1     <= 10'd0;
                        slot_batch_mask1 <= 4'd0;
                        slot_raw_ready1  <= 1'b0;
                        slot_proc_ready1 <= 1'b0;
                        slot_busy_tx1    <= 1'b0;
                    end
                end
                else begin
                    if (!tx_slot_sel) begin
                        proc0_enb   <= 1'b1;
                        proc0_addrb <= tx_issue_idx[8:0];
                    end else begin
                        proc1_enb   <= 1'b1;
                        proc1_addrb <= tx_issue_idx[8:0];
                    end

                    tx_rd_v[0]     <= 1'b1;
                    tx_rd_slot[0]  <= tx_slot_sel;
                    tx_rd_start[0] <= 1'b0;
                    tx_rd_last[0]  <= (tx_issue_idx == ROW_SAMPLES-1);

                    tx_issue_idx   <= tx_issue_idx + 10'd1;
                end
            end
        end
    end

endmodule