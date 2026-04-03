`timescale 1ns / 1ps
// =============================================================================
// dsp_core_top
//
// Deterministic row-buffered DSP stub with calibration-memory integration shell.
//
// Current placeholder DSP behavior:
// - Accept exactly 1024 real samples for one row
// - Emit exactly the first 512 samples unchanged
//
// Calibration integration behavior:
// - Receives runtime_valid and BRAM write buses from udp_processing_top
// - Writes BG + k-lin memories through their Port A interfaces
// - Disp-comp write buses are accepted for interface completeness but ignored
//   for now, per current development phase
//
// Purpose:
// - stable integration shell before real DSP stage wiring
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
    // Calibration status / validity from udp_processing_top
    // -------------------------------------------------------------------------
    input  wire [7:0]  runtime_valid,

    // -------------------------------------------------------------------------
    // Calibration BRAM write buses from udp_processing_top / cal_loader
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

    // -------------------------------------------------------------------------
    // Internal read-side tie-offs for calibration memories
    // Real DSP stages will later consume Port B.
    // -------------------------------------------------------------------------
    wire        bg_rd_en_i      = 1'b0;
    wire [9:0]  bg_rd_addr_i    = 10'd0;
    wire [31:0] bg_rd_data_i;

    wire        klin_a_rd_en_i  = 1'b0;
    wire [9:0]  klin_a_rd_addr_i= 10'd0;
    wire [9:0]  klin_a_rd_data_i;

    wire        klin_b_rd_en_i  = 1'b0;
    wire [9:0]  klin_b_rd_addr_i= 10'd0;
    wire [17:0] klin_b_rd_data_i;

    wire        klin_c_rd_en_i  = 1'b0;
    wire [9:0]  klin_c_rd_addr_i= 10'd0;
    wire [17:0] klin_c_rd_data_i;

    wire        klin_d_rd_en_i  = 1'b0;
    wire [9:0]  klin_d_rd_addr_i= 10'd0;
    wire [17:0] klin_d_rd_data_i;

    wire        klin_e_rd_en_i  = 1'b0;
    wire [9:0]  klin_e_rd_addr_i= 10'd0;
    wire [17:0] klin_e_rd_data_i;

    // -------------------------------------------------------------------------
    // Calibration memories
    // -------------------------------------------------------------------------
    bgsub_blk_mem_gen u_bg (
        .clka  (clk),
        .ena   (bg_wr_en),
        .wea   (bg_wr_we),
        .addra (bg_wr_addr),
        .dina  (bg_wr_data),
        .clkb  (clk),
        .enb   (bg_rd_en_i),
        .addrb (bg_rd_addr_i),
        .doutb (bg_rd_data_i)
    );

    klin_base_rom u_klin_a (
        .clka  (clk),
        .ena   (klin_a_wr_en),
        .wea   (klin_a_wr_we),
        .addra (klin_a_wr_addr),
        .dina  (klin_a_wr_data[9:0]),
        .clkb  (clk),
        .enb   (klin_a_rd_en_i),
        .addrb (klin_a_rd_addr_i),
        .doutb (klin_a_rd_data_i)
    );

    klin_c0_rom u_klin_b (
        .clka  (clk),
        .ena   (klin_b_wr_en),
        .wea   (klin_b_wr_we),
        .addra (klin_b_wr_addr),
        .dina  (klin_b_wr_data[17:0]),
        .clkb  (clk),
        .enb   (klin_b_rd_en_i),
        .addrb (klin_b_rd_addr_i),
        .doutb (klin_b_rd_data_i)
    );

    klin_c1_rom u_klin_c (
        .clka  (clk),
        .ena   (klin_c_wr_en),
        .wea   (klin_c_wr_we),
        .addra (klin_c_wr_addr),
        .dina  (klin_c_wr_data[17:0]),
        .clkb  (clk),
        .enb   (klin_c_rd_en_i),
        .addrb (klin_c_rd_addr_i),
        .doutb (klin_c_rd_data_i)
    );

    klin_c2_rom u_klin_d (
        .clka  (clk),
        .ena   (klin_d_wr_en),
        .wea   (klin_d_wr_we),
        .addra (klin_d_wr_addr),
        .dina  (klin_d_wr_data[17:0]),
        .clkb  (clk),
        .enb   (klin_d_rd_en_i),
        .addrb (klin_d_rd_addr_i),
        .doutb (klin_d_rd_data_i)
    );

    klin_c3_rom u_klin_e (
        .clka  (clk),
        .ena   (klin_e_wr_en),
        .wea   (klin_e_wr_we),
        .addra (klin_e_wr_addr),
        .dina  (klin_e_wr_data[17:0]),
        .clkb  (clk),
        .enb   (klin_e_rd_en_i),
        .addrb (klin_e_rd_addr_i),
        .doutb (klin_e_rd_data_i)
    );

`ifndef SYNTHESIS
    // -------------------------------------------------------------------------
    // Simulation-only shadow memories for easy TB checking of calibration writes
    // -------------------------------------------------------------------------
    reg [31:0] bg_shadow     [0:1023];
    reg [9:0]  klin_a_shadow [0:1023];
    reg [17:0] klin_b_shadow [0:1023];
    reg [17:0] klin_c_shadow [0:1023];
    reg [17:0] klin_d_shadow [0:1023];
    reg [17:0] klin_e_shadow [0:1023];

    integer si;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (si = 0; si < 1024; si = si + 1) begin
                bg_shadow[si]     <= 32'd0;
                klin_a_shadow[si] <= 10'd0;
                klin_b_shadow[si] <= 18'd0;
                klin_c_shadow[si] <= 18'd0;
                klin_d_shadow[si] <= 18'd0;
                klin_e_shadow[si] <= 18'd0;
            end
        end else begin
            if (bg_wr_en     && bg_wr_we[0])     bg_shadow[bg_wr_addr]         <= bg_wr_data;
            if (klin_a_wr_en && klin_a_wr_we[0]) klin_a_shadow[klin_a_wr_addr] <= klin_a_wr_data[9:0];
            if (klin_b_wr_en && klin_b_wr_we[0]) klin_b_shadow[klin_b_wr_addr] <= klin_b_wr_data[17:0];
            if (klin_c_wr_en && klin_c_wr_we[0]) klin_c_shadow[klin_c_wr_addr] <= klin_c_wr_data[17:0];
            if (klin_d_wr_en && klin_d_wr_we[0]) klin_d_shadow[klin_d_wr_addr] <= klin_d_wr_data[17:0];
            if (klin_e_wr_en && klin_e_wr_we[0]) klin_e_shadow[klin_e_wr_addr] <= klin_e_wr_data[17:0];
        end
    end
`endif

    // -------------------------------------------------------------------------
    // Current DSP shell
    // runtime_valid is intentionally not used yet; later stages will consult it.
    // -------------------------------------------------------------------------
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
            out_valid     <= 1'b0;
            out_row_start <= 1'b0;
            row_done      <= 1'b0;

            case (state)
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