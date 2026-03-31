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
    // Pulse latches
    // ------------------------------------------------------------
    logic clear_event_latches;
    logic saw_cal_error;
    logic saw_done_pulse;

    // ------------------------------------------------------------
    // Scoreboard
    // ------------------------------------------------------------
    int pass = 0;
    int fail = 0;

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
    // Active memory instances
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
    // Pulse-capture logic
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            saw_cal_error <= 1'b0;
            saw_done_pulse <= 1'b0;
        end else if (clear_event_latches) begin
            saw_cal_error <= 1'b0;
            saw_done_pulse <= 1'b0;
        end else begin
            if (cal_error)
                saw_cal_error <= 1'b1;
            if (cal_done_pulse)
                saw_done_pulse <= 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Helpers
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

    task automatic send_batch_payload_missing_end(input [31:0] base);
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
            sample_last  = 1'b0;
            batch_valid  = 1'b0;
        end
        @(negedge clk);
        clear_drive();
    end
    endtask

    task automatic send_batch_payload_overflow(input [31:0] base);
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
        hdr_valid    = 1'b0;
        pkt_is_cal   = 1'b0;
        pkt_msg_type = 8'h00;
        batch_id     = 2'd0;
        row_id       = 10'd0;
        sample_valid = 1'b1;
        sample_data  = base + 32'h100;
        sample_last  = 1'b0;
        batch_valid  = 1'b0;

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
    // Anchor checks
    // ------------------------------------------------------------
    task automatic check_bg_anchors(input [31:0] base, input string tag);
        logic [31:0] got, exp;
    begin
        read_bg_addr(10'd0, got);     exp = base + 32'd0;
        expect_local(got === exp, {tag, " BG[0]"});

        read_bg_addr(10'd255, got);   exp = base + 32'd255;
        expect_local(got === exp, {tag, " BG[255]"});

        read_bg_addr(10'd256, got);   exp = base + 32'h1000;
        expect_local(got === exp, {tag, " BG[256]"});

        read_bg_addr(10'd1023, got);  exp = base + 32'h3000 + 32'd255;
        expect_local(got === exp, {tag, " BG[1023]"});
    end
    endtask

    task automatic check_klin_a_anchors(input [31:0] base, input string tag);
        logic [9:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_a_addr(10'd0, got);     temp = (base + 32'd0);
        exp = temp[9:0];
        expect_local(got === exp, {tag, " KLIN_A[0]"});

        read_klin_a_addr(10'd255, got);   temp = (base + 32'd255);
        exp = temp[9:0];
        read_klin_a_addr(10'd256, got);   temp = (base + 32'h1000);
        exp = temp[9:0];
        expect_local(got === exp, {tag, " KLIN_A[256]"});

        read_klin_a_addr(10'd1023, got);  temp = (base + 32'h3000 + 32'd255);
        exp = temp[9:0];
        expect_local(got === exp, {tag, " KLIN_A[1023]"});
    end
    endtask

    task automatic check_klin_b_anchors(input [31:0] base, input string tag);
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_b_addr(10'd0, got);     temp = (base + 32'd0);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_B[0]"});

        read_klin_b_addr(10'd255, got);   temp = (base + 32'd255);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_B[255]"});

        read_klin_b_addr(10'd256, got);   temp = (base + 32'h1000);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_B[256]"});

        read_klin_b_addr(10'd1023, got);  temp = (base + 32'h3000 + 32'd255);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_B[1023]"});
    end
    endtask

    task automatic check_klin_c_anchors(input [31:0] base, input string tag);
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_c_addr(10'd0, got);     temp = (base + 32'd0);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_C[0]"});

        read_klin_c_addr(10'd255, got);   temp = (base + 32'd255);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_C[255]"});

        read_klin_c_addr(10'd256, got);   temp = (base + 32'h1000);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_C[256]"});

        read_klin_c_addr(10'd1023, got);  temp = (base + 32'h3000 + 32'd255);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_C[1023]"});
    end
    endtask

    task automatic check_klin_d_anchors(input [31:0] base, input string tag);
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_d_addr(10'd0, got);     temp = (base + 32'd0);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_D[0]"});

        read_klin_d_addr(10'd255, got);   temp = (base + 32'd255);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_D[255]"});

        read_klin_d_addr(10'd256, got);   temp = (base + 32'h1000);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_D[256]"});

        read_klin_d_addr(10'd1023, got);  temp = (base + 32'h3000 + 32'd255);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_D[1023]"});
    end
    endtask

    task automatic check_klin_e_anchors(input [31:0] base, input string tag);
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        read_klin_e_addr(10'd0, got);     temp = (base + 32'd0);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_E[0]"});

        read_klin_e_addr(10'd255, got);   temp = (base + 32'd255);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_E[255]"});

        read_klin_e_addr(10'd256, got);   temp = (base + 32'h1000);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_E[256]"});

        read_klin_e_addr(10'd1023, got);  temp = (base + 32'h3000 + 32'd255);
        exp = temp[17:0];
        expect_local(got === exp, {tag, " KLIN_E[1023]"});
    end
    endtask

    // ------------------------------------------------------------
    // Generic protocol suites
    // ------------------------------------------------------------
    task automatic run_invalidation_suite(
        input [9:0] rid,
        input int valid_idx,
        input [31:0] good_base,
        input [31:0] recover_base,
        input string name
    );
    begin
        $display("--------------------------------------------------");
        $display("%s: prime valid image", name);
        $display("--------------------------------------------------");
        reset_event_capture();
        send_full_cal(rid, good_base);
        idle_cycles(8);
        expect_local(runtime_valid[valid_idx] == 1'b1, {name, " valid set"});
        expect_local(saw_done_pulse == 1'b1, {name, " done pulse seen on valid load"});

        $display("--------------------------------------------------");
        $display("%s: early end invalidates", name);
        $display("--------------------------------------------------");
        reset_event_capture();
        send_cal_header(rid, 2'd0);
        send_batch_payload_early_end(good_base + 32'h0100_0000, 100);
        idle_cycles(4);
        expect_local(saw_cal_error == 1'b1, {name, " early-end error pulse"});
        expect_local(saw_done_pulse == 1'b0, {name, " early-end no done pulse"});
        expect_local(runtime_valid[valid_idx] == 1'b0, {name, " early-end clears valid"});

        $display("--------------------------------------------------");
        $display("%s: missing end invalidates", name);
        $display("--------------------------------------------------");
        reset_event_capture();
        send_cal_header(rid, 2'd0);
        send_batch_payload_missing_end(good_base + 32'h0200_0000);
        idle_cycles(4);
        expect_local(saw_cal_error == 1'b1, {name, " missing-end error pulse"});
        expect_local(saw_done_pulse == 1'b0, {name, " missing-end no done pulse"});
        expect_local(runtime_valid[valid_idx] == 1'b0, {name, " missing-end clears valid"});

        $display("--------------------------------------------------");
        $display("%s: overflow invalidates", name);
        $display("--------------------------------------------------");
        reset_event_capture();
        send_cal_header(rid, 2'd0);
        send_batch_payload_overflow(good_base + 32'h0300_0000);
        idle_cycles(4);
        expect_local(saw_cal_error == 1'b1, {name, " overflow error pulse"});
        expect_local(saw_done_pulse == 1'b0, {name, " overflow no done pulse"});
        expect_local(runtime_valid[valid_idx] == 1'b0, {name, " overflow clears valid"});

        $display("--------------------------------------------------");
        $display("%s: recovery overwrite", name);
        $display("--------------------------------------------------");
        reset_event_capture();
        send_full_cal(rid, recover_base);
        idle_cycles(8);
        expect_local(runtime_valid[valid_idx] == 1'b1, {name, " recovery re-sets valid"});
        expect_local(saw_done_pulse == 1'b1, {name, " recovery done pulse seen"});
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

        // BG full protocol + readback
        run_invalidation_suite(10'd0, 0, 32'h0001_0000, 32'h0002_0000, "BG_SUB");
        check_bg_anchors(32'h0002_0000, "BG_SUB recovery");

        // KLIN_A full protocol + readback
        run_invalidation_suite(10'd24, 3, 32'h0011_0000, 32'h0012_0000, "KLIN_A");
        check_klin_a_anchors(32'h0012_0000, "KLIN_A recovery");

        // KLIN_B full protocol + readback
        run_invalidation_suite(10'd25, 4, 32'h0021_0000, 32'h0022_0000, "KLIN_B");
        check_klin_b_anchors(32'h0022_0000, "KLIN_B recovery");

        // KLIN_C full protocol + readback
        run_invalidation_suite(10'd26, 5, 32'h0031_0000, 32'h0032_0000, "KLIN_C");
        check_klin_c_anchors(32'h0032_0000, "KLIN_C recovery");

        // KLIN_D full protocol + readback
        run_invalidation_suite(10'd27, 6, 32'h0041_0000, 32'h0042_0000, "KLIN_D");
        check_klin_d_anchors(32'h0042_0000, "KLIN_D recovery");

        // KLIN_E full protocol + readback
        run_invalidation_suite(10'd28, 7, 32'h0051_0000, 32'h0052_0000, "KLIN_E");
        check_klin_e_anchors(32'h0052_0000, "KLIN_E recovery");

        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");
        $finish;
    end

endmodule

