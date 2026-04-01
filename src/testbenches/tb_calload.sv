
`timescale 1ns/1ps

module tb_calibration_loader;

    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // DUT inputs
    // ------------------------------------------------------------
    logic        hdr_valid;
    logic        pkt_is_cal;
    logic [7:0]  pkt_msg_type;
    logic [1:0]  batch_id;
    logic [9:0]  row_id;
    logic        sample_valid;
    logic [31:0] sample_data;
    logic        sample_last;
    logic        batch_valid;
    logic        allow_cal;
    logic        dsp_busy;

    // ------------------------------------------------------------
    // DUT outputs
    // ------------------------------------------------------------
    logic        cal_loading;
    logic        cal_done_pulse;
    logic        cal_error;
    logic        cal_rejected_busy;
    logic        cal_rejected_mode;
    logic [7:0]  runtime_valid;

    logic        bg_wr_en;
    logic [0:0]  bg_wr_we;
    logic [9:0]  bg_wr_addr;
    logic [31:0] bg_wr_data;

    logic        disp_a_wr_en;
    logic [0:0]  disp_a_wr_we;
    logic [9:0]  disp_a_wr_addr;
    logic [31:0] disp_a_wr_data;

    logic        disp_b_wr_en;
    logic [0:0]  disp_b_wr_we;
    logic [9:0]  disp_b_wr_addr;
    logic [31:0] disp_b_wr_data;

    logic        klin_a_wr_en;
    logic [0:0]  klin_a_wr_we;
    logic [9:0]  klin_a_wr_addr;
    logic [31:0] klin_a_wr_data;

    logic        klin_b_wr_en;
    logic [0:0]  klin_b_wr_we;
    logic [9:0]  klin_b_wr_addr;
    logic [31:0] klin_b_wr_data;

    logic        klin_c_wr_en;
    logic [0:0]  klin_c_wr_we;
    logic [9:0]  klin_c_wr_addr;
    logic [31:0] klin_c_wr_data;

    logic        klin_d_wr_en;
    logic [0:0]  klin_d_wr_we;
    logic [9:0]  klin_d_wr_addr;
    logic [31:0] klin_d_wr_data;

    logic        klin_e_wr_en;
    logic [0:0]  klin_e_wr_we;
    logic [9:0]  klin_e_wr_addr;
    logic [31:0] klin_e_wr_data;

    // ------------------------------------------------------------
    // Readback ports
    // ------------------------------------------------------------
    logic        bg_rd_en;
    logic [9:0]  bg_rd_addr;
    logic [31:0] bg_rd_data;

    logic        klin_a_rd_en;
    logic [9:0]  klin_a_rd_addr;
    logic [9:0]  klin_a_rd_data;

    logic        klin_b_rd_en;
    logic [9:0]  klin_b_rd_addr;
    logic [17:0] klin_b_rd_data;

    logic        klin_c_rd_en;
    logic [9:0]  klin_c_rd_addr;
    logic [17:0] klin_c_rd_data;

    logic        klin_d_rd_en;
    logic [9:0]  klin_d_rd_addr;
    logic [17:0] klin_d_rd_data;

    logic        klin_e_rd_en;
    logic [9:0]  klin_e_rd_addr;
    logic [17:0] klin_e_rd_data;

    // ------------------------------------------------------------
    // Event latches / counters
    // ------------------------------------------------------------
    logic clear_event_latches;
    logic saw_cal_error;
    logic saw_done_pulse;

    int bg_write_count_seen;
    int klin_a_write_count_seen;
    int klin_b_write_count_seen;
    int klin_c_write_count_seen;
    int klin_d_write_count_seen;
    int klin_e_write_count_seen;

    // ------------------------------------------------------------
    // Scoreboard
    // ------------------------------------------------------------
    int pass = 0;
    int fail = 0;

    localparam [9:0] RID_BG      = 10'd0;
    localparam [9:0] RID_KLIN_A  = 10'd24;
    localparam [9:0] RID_KLIN_B  = 10'd25;
    localparam [9:0] RID_KLIN_C  = 10'd26;
    localparam [9:0] RID_KLIN_D  = 10'd27;
    localparam [9:0] RID_KLIN_E  = 10'd28;

    localparam int IDX_BG        = 0;
    localparam int IDX_KLIN_A    = 3;
    localparam int IDX_KLIN_B    = 4;
    localparam int IDX_KLIN_C    = 5;
    localparam int IDX_KLIN_D    = 6;
    localparam int IDX_KLIN_E    = 7;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    calibration_loader dut (
        .clk(clk),
        .rst(rst),

        .hdr_valid(hdr_valid),
        .pkt_is_cal(pkt_is_cal),
        .pkt_msg_type(pkt_msg_type),
        .batch_id(batch_id),
        .row_id(row_id),

        .sample_valid(sample_valid),
        .sample_data(sample_data),
        .sample_last(sample_last),
        .batch_valid(batch_valid),

        .allow_cal(allow_cal),
        .dsp_busy(dsp_busy),

        .cal_loading(cal_loading),
        .cal_done_pulse(cal_done_pulse),
        .cal_error(cal_error),
        .cal_rejected_busy(cal_rejected_busy),
        .cal_rejected_mode(cal_rejected_mode),
        .runtime_valid(runtime_valid),

        .bg_wr_en(bg_wr_en),
        .bg_wr_we(bg_wr_we),
        .bg_wr_addr(bg_wr_addr),
        .bg_wr_data(bg_wr_data),

        .disp_a_wr_en(disp_a_wr_en),
        .disp_a_wr_we(disp_a_wr_we),
        .disp_a_wr_addr(disp_a_wr_addr),
        .disp_a_wr_data(disp_a_wr_data),

        .disp_b_wr_en(disp_b_wr_en),
        .disp_b_wr_we(disp_b_wr_we),
        .disp_b_wr_addr(disp_b_wr_addr),
        .disp_b_wr_data(disp_b_wr_data),

        .klin_a_wr_en(klin_a_wr_en),
        .klin_a_wr_we(klin_a_wr_we),
        .klin_a_wr_addr(klin_a_wr_addr),
        .klin_a_wr_data(klin_a_wr_data),

        .klin_b_wr_en(klin_b_wr_en),
        .klin_b_wr_we(klin_b_wr_we),
        .klin_b_wr_addr(klin_b_wr_addr),
        .klin_b_wr_data(klin_b_wr_data),

        .klin_c_wr_en(klin_c_wr_en),
        .klin_c_wr_we(klin_c_wr_we),
        .klin_c_wr_addr(klin_c_wr_addr),
        .klin_c_wr_data(klin_c_wr_data),

        .klin_d_wr_en(klin_d_wr_en),
        .klin_d_wr_we(klin_d_wr_we),
        .klin_d_wr_addr(klin_d_wr_addr),
        .klin_d_wr_data(klin_d_wr_data),

        .klin_e_wr_en(klin_e_wr_en),
        .klin_e_wr_we(klin_e_wr_we),
        .klin_e_wr_addr(klin_e_wr_addr),
        .klin_e_wr_data(klin_e_wr_data)
    );

    // ------------------------------------------------------------
    // Memory models / BRAMs
    // ------------------------------------------------------------
    bgsub_blk_mem_gen u_bg (
        .clka(clk),
        .ena(bg_wr_en),
        .wea(bg_wr_we),
        .addra(bg_wr_addr),
        .dina(bg_wr_data),
        .clkb(clk),
        .enb(bg_rd_en),
        .addrb(bg_rd_addr),
        .doutb(bg_rd_data)
    );

    klin_base_rom u_klin_a (
        .clka(clk),
        .ena(klin_a_wr_en),
        .wea(klin_a_wr_we),
        .addra(klin_a_wr_addr),
        .dina(klin_a_wr_data[9:0]),
        .clkb(clk),
        .enb(klin_a_rd_en),
        .addrb(klin_a_rd_addr),
        .doutb(klin_a_rd_data)
    );

    klin_c0_rom u_klin_b (
        .clka(clk),
        .ena(klin_b_wr_en),
        .wea(klin_b_wr_we),
        .addra(klin_b_wr_addr),
        .dina(klin_b_wr_data[17:0]),
        .clkb(clk),
        .enb(klin_b_rd_en),
        .addrb(klin_b_rd_addr),
        .doutb(klin_b_rd_data)
    );

    klin_c1_rom u_klin_c (
        .clka(clk),
        .ena(klin_c_wr_en),
        .wea(klin_c_wr_we),
        .addra(klin_c_wr_addr),
        .dina(klin_c_wr_data[17:0]),
        .clkb(clk),
        .enb(klin_c_rd_en),
        .addrb(klin_c_rd_addr),
        .doutb(klin_c_rd_data)
    );

    klin_c2_rom u_klin_d (
        .clka(clk),
        .ena(klin_d_wr_en),
        .wea(klin_d_wr_we),
        .addra(klin_d_wr_addr),
        .dina(klin_d_wr_data[17:0]),
        .clkb(clk),
        .enb(klin_d_rd_en),
        .addrb(klin_d_rd_addr),
        .doutb(klin_d_rd_data)
    );

    klin_c3_rom u_klin_e (
        .clka(clk),
        .ena(klin_e_wr_en),
        .wea(klin_e_wr_we),
        .addra(klin_e_wr_addr),
        .dina(klin_e_wr_data[17:0]),
        .clkb(clk),
        .enb(klin_e_rd_en),
        .addrb(klin_e_rd_addr),
        .doutb(klin_e_rd_data)
    );

    // ------------------------------------------------------------
    // Event capture
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            saw_cal_error        <= 1'b0;
            saw_done_pulse       <= 1'b0;
            bg_write_count_seen  <= 0;
            klin_a_write_count_seen <= 0;
            klin_b_write_count_seen <= 0;
            klin_c_write_count_seen <= 0;
            klin_d_write_count_seen <= 0;
            klin_e_write_count_seen <= 0;
        end else if (clear_event_latches) begin
            saw_cal_error        <= 1'b0;
            saw_done_pulse       <= 1'b0;
            bg_write_count_seen  <= 0;
            klin_a_write_count_seen <= 0;
            klin_b_write_count_seen <= 0;
            klin_c_write_count_seen <= 0;
            klin_d_write_count_seen <= 0;
            klin_e_write_count_seen <= 0;
        end else begin
            if (cal_error)      saw_cal_error  <= 1'b1;
            if (cal_done_pulse) saw_done_pulse <= 1'b1;

            if (bg_wr_en)       bg_write_count_seen      <= bg_write_count_seen + 1;
            if (klin_a_wr_en)   klin_a_write_count_seen  <= klin_a_write_count_seen + 1;
            if (klin_b_wr_en)   klin_b_write_count_seen  <= klin_b_write_count_seen + 1;
            if (klin_c_wr_en)   klin_c_write_count_seen  <= klin_c_write_count_seen + 1;
            if (klin_d_wr_en)   klin_d_write_count_seen  <= klin_d_write_count_seen + 1;
            if (klin_e_wr_en)   klin_e_write_count_seen  <= klin_e_write_count_seen + 1;
        end
    end

    // ------------------------------------------------------------
    // Basic helpers
    // ------------------------------------------------------------
    task automatic expect_local(input logic cond, input string msg);
    begin
        if (cond) begin
            $display("PASS: %s", msg);
            pass++;
        end else begin
            $display("FAIL: %s", msg);
            fail++;
        end
    end
    endtask

    task automatic clear_drive;
    begin
        hdr_valid    = 1'b0;
        pkt_is_cal   = 1'b0;
        pkt_msg_type = 8'h00;
        batch_id     = 2'd0;
        row_id       = 10'd0;
        sample_valid = 1'b0;
        sample_data  = 32'd0;
        sample_last  = 1'b0;
        batch_valid  = 1'b0;
    end
    endtask

    task automatic clear_reads;
    begin
        bg_rd_en      = 1'b0; bg_rd_addr      = 10'd0;
        klin_a_rd_en  = 1'b0; klin_a_rd_addr  = 10'd0;
        klin_b_rd_en  = 1'b0; klin_b_rd_addr  = 10'd0;
        klin_c_rd_en  = 1'b0; klin_c_rd_addr  = 10'd0;
        klin_d_rd_en  = 1'b0; klin_d_rd_addr  = 10'd0;
        klin_e_rd_en  = 1'b0; klin_e_rd_addr  = 10'd0;
    end
    endtask

    task automatic reset_event_capture;
    begin
        @(negedge clk);
        clear_event_latches = 1'b1;
        @(negedge clk);
        clear_event_latches = 1'b0;
    end
    endtask

    task automatic idle_cycles(input int n);
        int i;
    begin
        for (i = 0; i < n; i++) begin
            @(negedge clk);
            clear_drive();
        end
    end
    endtask

    task automatic hard_reset_dut;
    begin
        @(negedge clk);
        clear_drive();
        rst = 1'b1;
        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);
        clear_drive();
        reset_event_capture();
    end
    endtask

    task automatic require_idle(input string tag);
    begin
        expect_local(cal_loading == 1'b0, {tag, " cal_loading==0"});
    end
    endtask

    // ------------------------------------------------------------
    // Stimulus helpers
    // ------------------------------------------------------------
    task automatic send_cal_header(input [9:0] rid, input [1:0] bid);
    begin
        @(negedge clk);
        hdr_valid    = 1'b1;
        pkt_is_cal   = 1'b1;
        pkt_msg_type = 8'h02;
        batch_id     = bid;
        row_id       = rid;
        sample_valid = 1'b0;
        sample_data  = 32'd0;
        sample_last  = 1'b0;
        batch_valid  = 1'b0;

        @(negedge clk);
        clear_drive();
    end
    endtask

    task automatic send_batch_payload_valid(input [31:0] base);
        int i;
    begin
        for (i = 0; i < 256; i++) begin
            @(negedge clk);
            hdr_valid    = 1'b0;
            pkt_is_cal   = 1'b0;
            pkt_msg_type = 8'h00;
            batch_id     = 2'd0;
            row_id       = 10'd0;
            sample_valid = 1'b1;
            sample_data  = base + i;
            sample_last  = (i == 255);
            batch_valid  = (i == 255);
        end
        @(negedge clk);
        clear_drive();
    end
    endtask

    task automatic send_batch_payload_early_end(input [31:0] base, input int last_index);
        int i;
    begin
        for (i = 0; i <= last_index; i++) begin
            @(negedge clk);
            hdr_valid    = 1'b0;
            pkt_is_cal   = 1'b0;
            pkt_msg_type = 8'h00;
            batch_id     = 2'd0;
            row_id       = 10'd0;
            sample_valid = 1'b1;
            sample_data  = base + i;
            sample_last  = (i == last_index);
            batch_valid  = (i == last_index);
        end
        @(negedge clk);
        clear_drive();
    end
    endtask

    task automatic send_full_cal(input [9:0] rid, input [31:0] base);
        int b;
    begin
        for (b = 0; b < 4; b++) begin
            send_cal_header(rid, b[1:0]);
            send_batch_payload_valid(base + (b * 32'h1000));
        end
    end
    endtask

    task automatic send_invalid_cal_early_end(
        input [9:0] rid,
        input [31:0] base,
        input int last_index
    );
    begin
        send_cal_header(rid, 2'd0);
        idle_cycles(1);
        send_batch_payload_early_end(base, last_index);
    end
    endtask

    // ------------------------------------------------------------
    // Read helpers
    // ------------------------------------------------------------
    task automatic read_bg_addr(input [9:0] addr, output logic [31:0] data);
    begin
        @(negedge clk);
        bg_rd_en   = 1'b1;
        bg_rd_addr = addr;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        data = bg_rd_data;
        bg_rd_en   = 1'b0;
        bg_rd_addr = '0;
    end
    endtask

    task automatic read_klin_a_addr(input [9:0] addr, output logic [9:0] data);
    begin
        @(negedge clk);
        klin_a_rd_en   = 1'b1;
        klin_a_rd_addr = addr;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        data = klin_a_rd_data;
        klin_a_rd_en   = 1'b0;
        klin_a_rd_addr = '0;
    end
    endtask

    task automatic read_klin_b_addr(input [9:0] addr, output logic [17:0] data);
    begin
        @(negedge clk);
        klin_b_rd_en   = 1'b1;
        klin_b_rd_addr = addr;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        data = klin_b_rd_data;
        klin_b_rd_en   = 1'b0;
        klin_b_rd_addr = '0;
    end
    endtask

    task automatic read_klin_c_addr(input [9:0] addr, output logic [17:0] data);
    begin
        @(negedge clk);
        klin_c_rd_en   = 1'b1;
        klin_c_rd_addr = addr;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        data = klin_c_rd_data;
        klin_c_rd_en   = 1'b0;
        klin_c_rd_addr = '0;
    end
    endtask

    task automatic read_klin_d_addr(input [9:0] addr, output logic [17:0] data);
    begin
        @(negedge clk);
        klin_d_rd_en   = 1'b1;
        klin_d_rd_addr = addr;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        data = klin_d_rd_data;
        klin_d_rd_en   = 1'b0;
        klin_d_rd_addr = '0;
    end
    endtask

    task automatic read_klin_e_addr(input [9:0] addr, output logic [17:0] data);
    begin
        @(negedge clk);
        klin_e_rd_en   = 1'b1;
        klin_e_rd_addr = addr;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        data = klin_e_rd_data;
        klin_e_rd_en   = 1'b0;
        klin_e_rd_addr = '0;
    end
    endtask

    // ------------------------------------------------------------
    // Key point checkers
    // ------------------------------------------------------------
    task automatic check_bg_key_points(input [31:0] base, input string tag);
        logic [31:0] got, exp;
    begin
        read_bg_addr(10'd0, got);     exp = base + 32'd0;
        expect_local(got === exp, {tag, " BG[0]"});

        read_bg_addr(10'd17, got);    exp = base + 32'd17;
        expect_local(got === exp, {tag, " BG[17]"});

        read_bg_addr(10'd255, got);   exp = base + 32'd255;
        expect_local(got === exp, {tag, " BG[255]"});

        read_bg_addr(10'd256, got);   exp = base + 32'h1000;
        expect_local(got === exp, {tag, " BG[256]"});

        read_bg_addr(10'd511, got);   exp = base + 32'h1000 + 32'd255;
        expect_local(got === exp, {tag, " BG[511]"});

        read_bg_addr(10'd768, got);   exp = base + 32'h3000;
        expect_local(got === exp, {tag, " BG[768]"});

        read_bg_addr(10'd1023, got);  exp = base + 32'h3000 + 32'd255;
        expect_local(got === exp, {tag, " BG[1023]"});
    end
    endtask

    task automatic check_klin_a_key_points(input [31:0] base, input string tag);
        logic [9:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_a_addr(10'd0, got);     temp = base + 32'd0;               exp = temp[9:0];
        expect_local(got === exp, {tag, " KLIN_A[0]"});

        read_klin_a_addr(10'd17, got);    temp = base + 32'd17;              exp = temp[9:0];
        expect_local(got === exp, {tag, " KLIN_A[17]"});

        read_klin_a_addr(10'd255, got);   temp = base + 32'd255;             exp = temp[9:0];
        expect_local(got === exp, {tag, " KLIN_A[255]"});

        read_klin_a_addr(10'd256, got);   temp = base + 32'h1000;            exp = temp[9:0];
        expect_local(got === exp, {tag, " KLIN_A[256]"});

        read_klin_a_addr(10'd1023, got);  temp = base + 32'h3000 + 32'd255;  exp = temp[9:0];
        expect_local(got === exp, {tag, " KLIN_A[1023]"});
    end
    endtask

    task automatic check_klin_b_key_points(input [31:0] base, input string tag);
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_b_addr(10'd0, got);     temp = base + 32'd0;               exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_B[0]"});

        read_klin_b_addr(10'd17, got);    temp = base + 32'd17;              exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_B[17]"});

        read_klin_b_addr(10'd255, got);   temp = base + 32'd255;             exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_B[255]"});

        read_klin_b_addr(10'd256, got);   temp = base + 32'h1000;            exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_B[256]"});

        read_klin_b_addr(10'd1023, got);  temp = base + 32'h3000 + 32'd255;  exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_B[1023]"});
    end
    endtask

    task automatic check_klin_c_key_points(input [31:0] base, input string tag);
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_c_addr(10'd0, got);     temp = base + 32'd0;               exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_C[0]"});

        read_klin_c_addr(10'd17, got);    temp = base + 32'd17;              exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_C[17]"});

        read_klin_c_addr(10'd255, got);   temp = base + 32'd255;             exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_C[255]"});

        read_klin_c_addr(10'd256, got);   temp = base + 32'h1000;            exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_C[256]"});

        read_klin_c_addr(10'd1023, got);  temp = base + 32'h3000 + 32'd255;  exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_C[1023]"});
    end
    endtask

    task automatic check_klin_d_key_points(input [31:0] base, input string tag);
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_d_addr(10'd0, got);     temp = base + 32'd0;               exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_D[0]"});

        read_klin_d_addr(10'd17, got);    temp = base + 32'd17;              exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_D[17]"});

        read_klin_d_addr(10'd255, got);   temp = base + 32'd255;             exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_D[255]"});

        read_klin_d_addr(10'd256, got);   temp = base + 32'h1000;            exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_D[256]"});

        read_klin_d_addr(10'd1023, got);  temp = base + 32'h3000 + 32'd255;  exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_D[1023]"});
    end
    endtask

    task automatic check_klin_e_key_points(input [31:0] base, input string tag);
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_e_addr(10'd0, got);     temp = base + 32'd0;               exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_E[0]"});

        read_klin_e_addr(10'd17, got);    temp = base + 32'd17;              exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_E[17]"});

        read_klin_e_addr(10'd255, got);   temp = base + 32'd255;             exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_E[255]"});

        read_klin_e_addr(10'd256, got);   temp = base + 32'h1000;            exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_E[256]"});

        read_klin_e_addr(10'd1023, got);  temp = base + 32'h3000 + 32'd255;  exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_E[1023]"});
    end
    endtask

    // ------------------------------------------------------------
    // BG flow tests
    // ------------------------------------------------------------
    task automatic test_bg_valid_valid_invalid;
    begin
        $display("--------------------------------------------------");
        $display("TEST BG: valid -> valid -> invalid");
        $display("--------------------------------------------------");

        hard_reset_dut();

        reset_event_capture();
        send_full_cal(RID_BG, 32'h1000_0000);
        idle_cycles(8);
        expect_local(runtime_valid[IDX_BG] == 1'b1, "BG valid #1 sets runtime_valid");
        expect_local(saw_done_pulse == 1'b1, "BG valid #1 done");
        expect_local(saw_cal_error == 1'b0, "BG valid #1 no error");
        require_idle("BG valid #1");
        check_bg_key_points(32'h1000_0000, "BG valid #1");

        reset_event_capture();
        send_full_cal(RID_BG, 32'h2000_0000);
        idle_cycles(8);
        expect_local(runtime_valid[IDX_BG] == 1'b1, "BG valid #2 sets runtime_valid");
        expect_local(saw_done_pulse == 1'b1, "BG valid #2 done");
        expect_local(saw_cal_error == 1'b0, "BG valid #2 no error");
        require_idle("BG valid #2");
        check_bg_key_points(32'h2000_0000, "BG valid #2");

        reset_event_capture();
        send_cal_header(RID_BG, 2'd0);
        idle_cycles(1);
        expect_local(runtime_valid[IDX_BG] == 1'b0, "BG invalid attempt clears runtime_valid immediately");
        send_batch_payload_early_end(32'h3000_0000, 73);
        idle_cycles(4);
        expect_local(saw_cal_error == 1'b1, "BG invalid row raises error");
        expect_local(saw_done_pulse == 1'b0, "BG invalid row no done");
        expect_local(runtime_valid[IDX_BG] == 1'b0, "BG invalid row leaves runtime_valid low");
        expect_local(bg_write_count_seen > 0, "BG invalid row still wrote some samples");
        require_idle("BG invalid");
    end
    endtask

    task automatic test_bg_invalid_then_valid;
    begin
        $display("--------------------------------------------------");
        $display("TEST BG: invalid -> wait -> valid");
        $display("--------------------------------------------------");

        hard_reset_dut();

        reset_event_capture();
        send_invalid_cal_early_end(RID_BG, 32'h4000_0000, 51);
        idle_cycles(4);
        expect_local(saw_cal_error == 1'b1, "BG initial invalid raises error");
        expect_local(saw_done_pulse == 1'b0, "BG initial invalid no done");
        expect_local(runtime_valid[IDX_BG] == 1'b0, "BG initial invalid keeps valid low");
        require_idle("BG after invalid");

        reset_event_capture();
        idle_cycles(5);
        expect_local(cal_loading == 1'b0, "BG still idle a few cycles later");

        reset_event_capture();
        send_full_cal(RID_BG, 32'h5000_0000);
        idle_cycles(8);
        expect_local(runtime_valid[IDX_BG] == 1'b1, "BG recovery valid sets runtime_valid");
        expect_local(saw_done_pulse == 1'b1, "BG recovery valid done");
        expect_local(saw_cal_error == 1'b0, "BG recovery valid no new error");
        require_idle("BG recovery");
        check_bg_key_points(32'h5000_0000, "BG recovery");
    end
    endtask

    // ------------------------------------------------------------
    // Generic k-lin flow tests
    // ------------------------------------------------------------
    task automatic test_klin_flow(
        input [9:0] rid,
        input int idx,
        input [31:0] base1,
        input [31:0] base2,
        input [31:0] base_bad,
        input [31:0] base_recover,
        input string name
    );
    begin
        $display("--------------------------------------------------");
        $display("TEST %s: valid -> valid -> invalid", name);
        $display("--------------------------------------------------");

        hard_reset_dut();

        reset_event_capture();
        send_full_cal(rid, base1);
        idle_cycles(8);
        expect_local(runtime_valid[idx] == 1'b1, {name, " valid #1 sets runtime_valid"});
        expect_local(saw_done_pulse == 1'b1, {name, " valid #1 done"});
        expect_local(saw_cal_error == 1'b0, {name, " valid #1 no error"});
        require_idle({name, " valid #1"});

        reset_event_capture();
        send_full_cal(rid, base2);
        idle_cycles(8);
        expect_local(runtime_valid[idx] == 1'b1, {name, " valid #2 sets runtime_valid"});
        expect_local(saw_done_pulse == 1'b1, {name, " valid #2 done"});
        expect_local(saw_cal_error == 1'b0, {name, " valid #2 no error"});
        require_idle({name, " valid #2"});

        reset_event_capture();
        send_cal_header(rid, 2'd0);
        idle_cycles(1);
        expect_local(runtime_valid[idx] == 1'b0, {name, " invalid attempt clears runtime_valid immediately"});
        send_batch_payload_early_end(base_bad, 73);
        idle_cycles(4);
        expect_local(saw_cal_error == 1'b1, {name, " invalid row raises error"});
        expect_local(saw_done_pulse == 1'b0, {name, " invalid row no done"});
        expect_local(runtime_valid[idx] == 1'b0, {name, " invalid row leaves runtime_valid low"});
        require_idle({name, " invalid"});

        $display("--------------------------------------------------");
        $display("TEST %s: invalid -> wait -> valid", name);
        $display("--------------------------------------------------");

        hard_reset_dut();

        reset_event_capture();
        send_invalid_cal_early_end(rid, base_bad + 32'h0100_0000, 51);
        idle_cycles(4);
        expect_local(saw_cal_error == 1'b1, {name, " initial invalid raises error"});
        expect_local(saw_done_pulse == 1'b0, {name, " initial invalid no done"});
        expect_local(runtime_valid[idx] == 1'b0, {name, " initial invalid keeps valid low"});
        require_idle({name, " after invalid"});

        reset_event_capture();
        idle_cycles(5);
        expect_local(cal_loading == 1'b0, {name, " still idle a few cycles later"});

        reset_event_capture();
        send_full_cal(rid, base_recover);
        idle_cycles(8);
        expect_local(runtime_valid[idx] == 1'b1, {name, " recovery valid sets runtime_valid"});
        expect_local(saw_done_pulse == 1'b1, {name, " recovery valid done"});
        expect_local(saw_cal_error == 1'b0, {name, " recovery valid no new error"});
        require_idle({name, " recovery"});
    end
    endtask

    // ------------------------------------------------------------
    // K-lin readback tests after recovery
    // ------------------------------------------------------------
    task automatic test_klin_readbacks;
    begin
        $display("--------------------------------------------------");
        $display("TEST: k-lin key point readbacks");
        $display("--------------------------------------------------");

        hard_reset_dut();

        send_full_cal(RID_KLIN_A, 32'h6100_0000);
        send_full_cal(RID_KLIN_B, 32'h6200_0000);
        send_full_cal(RID_KLIN_C, 32'h6300_0000);
        send_full_cal(RID_KLIN_D, 32'h6400_0000);
        send_full_cal(RID_KLIN_E, 32'h6500_0000);
        idle_cycles(8);

        expect_local(runtime_valid[IDX_KLIN_A] == 1'b1, "KLIN_A runtime_valid high");
        expect_local(runtime_valid[IDX_KLIN_B] == 1'b1, "KLIN_B runtime_valid high");
        expect_local(runtime_valid[IDX_KLIN_C] == 1'b1, "KLIN_C runtime_valid high");
        expect_local(runtime_valid[IDX_KLIN_D] == 1'b1, "KLIN_D runtime_valid high");
        expect_local(runtime_valid[IDX_KLIN_E] == 1'b1, "KLIN_E runtime_valid high");

        check_klin_a_key_points(32'h6100_0000, "KLIN_A");
        check_klin_b_key_points(32'h6200_0000, "KLIN_B");
        check_klin_c_key_points(32'h6300_0000, "KLIN_C");
        check_klin_d_key_points(32'h6400_0000, "KLIN_D");
        check_klin_e_key_points(32'h6500_0000, "KLIN_E");
    end
    endtask

    // ------------------------------------------------------------
    // Main test flow
    // ------------------------------------------------------------
    initial begin
        clear_drive();
        clear_reads();
        clear_event_latches = 1'b0;
        allow_cal  = 1'b1;
        dsp_busy   = 1'b0;

        repeat (8) @(negedge clk);
        rst = 1'b0;
        idle_cycles(2);

        // BG
        test_bg_valid_valid_invalid();
        test_bg_invalid_then_valid();

        // k-lin
        test_klin_flow(RID_KLIN_A, IDX_KLIN_A,
                       32'h1100_0000, 32'h1200_0000, 32'h1300_0000, 32'h1400_0000, "KLIN_A");

        test_klin_flow(RID_KLIN_B, IDX_KLIN_B,
                       32'h2100_0000, 32'h2200_0000, 32'h2300_0000, 32'h2400_0000, "KLIN_B");

        test_klin_flow(RID_KLIN_C, IDX_KLIN_C,
                       32'h3100_0000, 32'h3200_0000, 32'h3300_0000, 32'h3400_0000, "KLIN_C");

        test_klin_flow(RID_KLIN_D, IDX_KLIN_D,
                       32'h4100_0000, 32'h4200_0000, 32'h4300_0000, 32'h4400_0000, "KLIN_D");

        test_klin_flow(RID_KLIN_E, IDX_KLIN_E,
                       32'h5100_0000, 32'h5200_0000, 32'h5300_0000, 32'h5400_0000, "KLIN_E");

        test_klin_readbacks();

        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");
        $finish;
    end

endmodule
