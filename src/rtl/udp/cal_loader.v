
`timescale 1ns / 1ps

module calibration_loader #(
    parameter integer WATCHDOG_CYCLES = 1029
)(
    input  wire        clk,
    input  wire        rst,

    // From rx handler / top-level routing
    input  wire        hdr_valid,
    input  wire        pkt_is_cal,
    input  wire [7:0]  pkt_msg_type,
    input  wire [1:0]  batch_id,
    input  wire [9:0]  row_id,

    input  wire        sample_valid,
    input  wire [31:0] sample_data,
    input  wire        sample_last,
    input  wire        batch_valid,

    // Policy control
    input  wire        allow_cal,
    input  wire        dsp_busy,   // preserved for interface compatibility; not used to reject loads

    // Status
    output reg         cal_loading,
    output reg         cal_done_pulse,
    output reg         cal_error,
    output reg         cal_rejected_busy,
    output reg         cal_rejected_mode,
    output reg  [7:0]  runtime_valid,

    // background BRAM write interface (Port A)
    output reg         bg_wr_en,
    output reg  [0:0]  bg_wr_we,
    output reg  [9:0]  bg_wr_addr,
    output reg  [31:0] bg_wr_data,

    // disp A BRAM write interface (Port A)
    output reg         disp_a_wr_en,
    output reg  [0:0]  disp_a_wr_we,
    output reg  [9:0]  disp_a_wr_addr,
    output reg  [31:0] disp_a_wr_data,

    // disp B BRAM write interface (Port A)
    output reg         disp_b_wr_en,
    output reg  [0:0]  disp_b_wr_we,
    output reg  [9:0]  disp_b_wr_addr,
    output reg  [31:0] disp_b_wr_data,

    // k-lin A BRAM write interface (Port A)
    output reg         klin_a_wr_en,
    output reg  [0:0]  klin_a_wr_we,
    output reg  [9:0]  klin_a_wr_addr,
    output reg  [31:0] klin_a_wr_data,

    // k-lin B BRAM write interface (Port A)
    output reg         klin_b_wr_en,
    output reg  [0:0]  klin_b_wr_we,
    output reg  [9:0]  klin_b_wr_addr,
    output reg  [31:0] klin_b_wr_data,

    // k-lin C BRAM write interface (Port A)
    output reg         klin_c_wr_en,
    output reg  [0:0]  klin_c_wr_we,
    output reg  [9:0]  klin_c_wr_addr,
    output reg  [31:0] klin_c_wr_data,

    // k-lin D BRAM write interface (Port A)
    output reg         klin_d_wr_en,
    output reg  [0:0]  klin_d_wr_we,
    output reg  [9:0]  klin_d_wr_addr,
    output reg  [31:0] klin_d_wr_data,

    // k-lin E BRAM write interface (Port A)
    output reg         klin_e_wr_en,
    output reg  [0:0]  klin_e_wr_we,
    output reg  [9:0]  klin_e_wr_addr,
    output reg  [31:0] klin_e_wr_data
);

    `define CAL_BG_SUB  10'd0
    `define CAL_DISP_A  10'd20
    `define CAL_DISP_B  10'd21
    `define CAL_KLIN_A  10'd24
    `define CAL_KLIN_B  10'd25
    `define CAL_KLIN_C  10'd26
    `define CAL_KLIN_D  10'd27
    `define CAL_KLIN_E  10'd28

    localparam IDX_BG_SUB = 3'd0;
    localparam IDX_DISP_A = 3'd1;
    localparam IDX_DISP_B = 3'd2;
    localparam IDX_KLIN_A = 3'd3;
    localparam IDX_KLIN_B = 3'd4;
    localparam IDX_KLIN_C = 3'd5;
    localparam IDX_KLIN_D = 3'd6;
    localparam IDX_KLIN_E = 3'd7;

    localparam ST_IDLE    = 2'd0;
    localparam ST_LOADING = 2'd1;
    localparam ST_WAITHDR = 2'd2;

    localparam integer WD_W = (WATCHDOG_CYCLES <= 2) ? 1 : $clog2(WATCHDOG_CYCLES);

    reg [1:0] state;
    reg [2:0] cur_target_idx;
    reg [9:0] cur_target_row_id;
    reg [1:0] cur_batch_id;
    reg [7:0] sample_count;
    reg [9:0] wr_addr;
    reg [WD_W-1:0] watchdog_ctr;

    function is_valid_cal_row;
        input [9:0] rid;
        begin
            case (rid)
                `CAL_BG_SUB,
                `CAL_DISP_A,
                `CAL_DISP_B,
                `CAL_KLIN_A,
                `CAL_KLIN_B,
                `CAL_KLIN_C,
                `CAL_KLIN_D,
                `CAL_KLIN_E: is_valid_cal_row = 1'b1;
                default:     is_valid_cal_row = 1'b0;
            endcase
        end
    endfunction

    function [2:0] cal_row_to_idx;
        input [9:0] rid;
        begin
            case (rid)
                `CAL_BG_SUB: cal_row_to_idx = IDX_BG_SUB;
                `CAL_DISP_A: cal_row_to_idx = IDX_DISP_A;
                `CAL_DISP_B: cal_row_to_idx = IDX_DISP_B;
                `CAL_KLIN_A: cal_row_to_idx = IDX_KLIN_A;
                `CAL_KLIN_B: cal_row_to_idx = IDX_KLIN_B;
                `CAL_KLIN_C: cal_row_to_idx = IDX_KLIN_C;
                `CAL_KLIN_D: cal_row_to_idx = IDX_KLIN_D;
                `CAL_KLIN_E: cal_row_to_idx = IDX_KLIN_E;
                default:     cal_row_to_idx = IDX_BG_SUB;
            endcase
        end
    endfunction

    task automatic reset_transaction_state;
    begin
        cal_loading       <= 1'b0;
        state             <= ST_IDLE;
        cur_target_idx    <= 3'd0;
        cur_target_row_id <= 10'd0;
        cur_batch_id      <= 2'd0;
        sample_count      <= 8'd0;
        wr_addr           <= 10'd0;
        watchdog_ctr      <= {WD_W{1'b0}};
    end
    endtask

    task automatic abort_current;
    begin
        cal_error <= 1'b1;
        reset_transaction_state();
    end
    endtask

    task automatic start_transaction(
        input [9:0] rid,
        input [2:0] idx,
        input [1:0] bid
    );
    begin
        runtime_valid[idx] <= 1'b0;

        cur_target_row_id <= rid;
        cur_target_idx    <= idx;
        cur_batch_id      <= bid;
        sample_count      <= 8'd0;
        wr_addr           <= {bid, 8'd0};
        cal_loading       <= 1'b1;
        state             <= ST_LOADING;
        watchdog_ctr      <= {WD_W{1'b0}};
    end
    endtask

    wire active_sample = (state == ST_LOADING) && sample_valid;
    wire final_sample  = active_sample && (sample_count == 8'd255);
    wire watchdog_fire = ((state == ST_LOADING) || (state == ST_WAITHDR)) &&
                         (watchdog_ctr == WATCHDOG_CYCLES-1);

    // ------------------------------------------------------------
    // combinational write outputs
    // ------------------------------------------------------------
    always @* begin
        bg_wr_en       = 1'b0;
        bg_wr_we       = 1'b0;
        bg_wr_addr     = 10'd0;
        bg_wr_data     = 32'd0;

        disp_a_wr_en   = 1'b0;
        disp_a_wr_we   = 1'b0;
        disp_a_wr_addr = 10'd0;
        disp_a_wr_data = 32'd0;

        disp_b_wr_en   = 1'b0;
        disp_b_wr_we   = 1'b0;
        disp_b_wr_addr = 10'd0;
        disp_b_wr_data = 32'd0;

        klin_a_wr_en   = 1'b0;
        klin_a_wr_we   = 1'b0;
        klin_a_wr_addr = 10'd0;
        klin_a_wr_data = 32'd0;

        klin_b_wr_en   = 1'b0;
        klin_b_wr_we   = 1'b0;
        klin_b_wr_addr = 10'd0;
        klin_b_wr_data = 32'd0;

        klin_c_wr_en   = 1'b0;
        klin_c_wr_we   = 1'b0;
        klin_c_wr_addr = 10'd0;
        klin_c_wr_data = 32'd0;

        klin_d_wr_en   = 1'b0;
        klin_d_wr_we   = 1'b0;
        klin_d_wr_addr = 10'd0;
        klin_d_wr_data = 32'd0;

        klin_e_wr_en   = 1'b0;
        klin_e_wr_we   = 1'b0;
        klin_e_wr_addr = 10'd0;
        klin_e_wr_data = 32'd0;

        if (active_sample) begin
            case (cur_target_idx)
                IDX_BG_SUB: begin
                    bg_wr_en   = 1'b1;
                    bg_wr_we   = 1'b1;
                    bg_wr_addr = wr_addr;
                    bg_wr_data = sample_data;
                end
                IDX_DISP_A: begin
                    disp_a_wr_en   = 1'b1;
                    disp_a_wr_we   = 1'b1;
                    disp_a_wr_addr = wr_addr;
                    disp_a_wr_data = sample_data;
                end
                IDX_DISP_B: begin
                    disp_b_wr_en   = 1'b1;
                    disp_b_wr_we   = 1'b1;
                    disp_b_wr_addr = wr_addr;
                    disp_b_wr_data = sample_data;
                end
                IDX_KLIN_A: begin
                    klin_a_wr_en   = 1'b1;
                    klin_a_wr_we   = 1'b1;
                    klin_a_wr_addr = wr_addr;
                    klin_a_wr_data = sample_data;
                end
                IDX_KLIN_B: begin
                    klin_b_wr_en   = 1'b1;
                    klin_b_wr_we   = 1'b1;
                    klin_b_wr_addr = wr_addr;
                    klin_b_wr_data = sample_data;
                end
                IDX_KLIN_C: begin
                    klin_c_wr_en   = 1'b1;
                    klin_c_wr_we   = 1'b1;
                    klin_c_wr_addr = wr_addr;
                    klin_c_wr_data = sample_data;
                end
                IDX_KLIN_D: begin
                    klin_d_wr_en   = 1'b1;
                    klin_d_wr_we   = 1'b1;
                    klin_d_wr_addr = wr_addr;
                    klin_d_wr_data = sample_data;
                end
                IDX_KLIN_E: begin
                    klin_e_wr_en   = 1'b1;
                    klin_e_wr_we   = 1'b1;
                    klin_e_wr_addr = wr_addr;
                    klin_e_wr_data = sample_data;
                end
                default: begin
                end
            endcase
        end
    end

    // ------------------------------------------------------------
    // FSM + watchdog
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state             <= ST_IDLE;
            cur_target_idx    <= 3'd0;
            cur_target_row_id <= 10'd0;
            cur_batch_id      <= 2'd0;
            sample_count      <= 8'd0;
            wr_addr           <= 10'd0;
            watchdog_ctr      <= {WD_W{1'b0}};

            cal_loading       <= 1'b0;
            cal_done_pulse    <= 1'b0;
            cal_error         <= 1'b0;
            cal_rejected_busy <= 1'b0;
            cal_rejected_mode <= 1'b0;
            runtime_valid     <= 8'd0;
        end else begin
            cal_done_pulse    <= 1'b0;
            cal_error         <= 1'b0;
            cal_rejected_busy <= 1'b0;
            cal_rejected_mode <= 1'b0;

            // default watchdog behavior:
            // count only while an in-flight transaction exists
            if ((state == ST_LOADING) || (state == ST_WAITHDR)) begin
                if (!watchdog_fire)
                    watchdog_ctr <= watchdog_ctr + {{(WD_W-1){1'b0}}, 1'b1};
            end else begin
                watchdog_ctr <= {WD_W{1'b0}};
            end

            // watchdog timeout has highest priority among runtime faults
            if (watchdog_fire) begin
                abort_current();
            end else begin

                // ----------------------------------------------------
                // Header processing
                // ----------------------------------------------------
                if (hdr_valid) begin
                    if (!pkt_is_cal || (pkt_msg_type != 8'h02)) begin
                        if (state != ST_IDLE)
                            abort_current();
                    end else if (!allow_cal) begin
                        cal_rejected_mode <= 1'b1;
                        if (state != ST_IDLE)
                            abort_current();
                    end else if (!is_valid_cal_row(row_id)) begin
                        cal_error <= 1'b1;
                        if (state != ST_IDLE)
                            reset_transaction_state();
                    end else begin
                        case (state)
                            ST_IDLE: begin
                                if (batch_id != 2'd0) begin
                                    cal_error <= 1'b1;
                                    reset_transaction_state();
                                end else begin
                                    start_transaction(row_id, cal_row_to_idx(row_id), batch_id);
                                end
                            end

                            ST_WAITHDR: begin
                                if ((row_id != cur_target_row_id) ||
                                    (batch_id != (cur_batch_id + 2'd1))) begin
                                    abort_current();
                                end else begin
                                    cur_batch_id <= batch_id;
                                    sample_count <= 8'd0;
                                    wr_addr      <= {batch_id, 8'd0};
                                    cal_loading  <= 1'b1;
                                    state        <= ST_LOADING;
                                    watchdog_ctr <= {WD_W{1'b0}};
                                end
                            end

                            ST_LOADING: begin
                                abort_current();
                            end

                            default: begin
                                abort_current();
                            end
                        endcase
                    end
                end

                // ----------------------------------------------------
                // Payload processing
                // ----------------------------------------------------
                if (state == ST_LOADING) begin
                    if (sample_valid) begin
                        if (!final_sample) begin
                            if (sample_last || batch_valid) begin
                                abort_current();
                            end else begin
                                sample_count <= sample_count + 8'd1;
                                wr_addr      <= wr_addr + 10'd1;
                                watchdog_ctr <= {WD_W{1'b0}};
                            end
                        end else begin
                            if (!sample_last || !batch_valid) begin
                                abort_current();
                            end else begin
                                if (cur_batch_id == 2'd3) begin
                                    runtime_valid[cur_target_idx] <= 1'b1;
                                    cal_done_pulse                <= 1'b1;
                                    reset_transaction_state();
                                end else begin
                                    cal_loading  <= 1'b0;
                                    state        <= ST_WAITHDR;
                                    sample_count <= 8'd0;
                                    wr_addr      <= 10'd0;
                                    watchdog_ctr <= {WD_W{1'b0}};
                                end
                            end
                        end
                    end else if (batch_valid) begin
                        abort_current();
                    end
                end else begin
                    if (sample_valid || batch_valid) begin
                        if (state == ST_WAITHDR)
                            abort_current();
                        else begin
                            cal_error <= 1'b1;
                            reset_transaction_state();
                        end
                    end
                end
            end
        end
    end

endmodule
