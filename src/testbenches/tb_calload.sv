`timescale 1ns/1ps

`timescale 1ns/1ps

module tb_calibration_loader;

    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    // DUT inputs
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

    // DUT outputs
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

    // real BG memory readback port
    logic        bg_rd_en;
    logic [9:0]  bg_rd_addr;
    logic [31:0] bg_rd_data;

    int pass = 0;
    int fail = 0;
    int bg_write_count = 0;
    logic [9:0]  bg_last_addr;
    logic [31:0] bg_last_data;

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

        .disp_a_wr_en(),
        .disp_a_wr_we(),
        .disp_a_wr_addr(),
        .disp_a_wr_data(),

        .disp_b_wr_en(),
        .disp_b_wr_we(),
        .disp_b_wr_addr(),
        .disp_b_wr_data(),

        .klin_a_wr_en(),
        .klin_a_wr_we(),
        .klin_a_wr_addr(),
        .klin_a_wr_data(),

        .klin_b_wr_en(),
        .klin_b_wr_we(),
        .klin_b_wr_addr(),
        .klin_b_wr_data(),

        .klin_c_wr_en(),
        .klin_c_wr_we(),
        .klin_c_wr_addr(),
        .klin_c_wr_data(),

        .klin_d_wr_en(),
        .klin_d_wr_we(),
        .klin_d_wr_addr(),
        .klin_d_wr_data(),

        .klin_e_wr_en(),
        .klin_e_wr_we(),
        .klin_e_wr_addr(),
        .klin_e_wr_data()
    );

    // real working BG memory
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

    // ------------------------------------------------------------
    // monitors
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            bg_write_count <= 0;
            bg_last_addr   <= '0;
            bg_last_data   <= '0;
        end else if (bg_wr_en && bg_wr_we[0]) begin
            bg_write_count <= bg_write_count + 1;
            bg_last_addr   <= bg_wr_addr;
            bg_last_data   <= bg_wr_data;
            $display("[BG WR] t=%0t addr=%0d data=0x%08h", $time, bg_wr_addr, bg_wr_data);
        end
    end

    always @(posedge clk) begin
        if (!rst) begin
            $display("[TB->DUT] t=%0t hdr_valid=%0b pkt_is_cal=%0b msg=0x%02h batch_id=%0d row_id=%0d sample_valid=%0b sample_data=0x%08h sample_last=%0b batch_valid=%0b | stateful: cal_loading=%0b cal_error=%0b runtime_valid=0x%02h",
                     $time, hdr_valid, pkt_is_cal, pkt_msg_type, batch_id, row_id,
                     sample_valid, sample_data, sample_last, batch_valid,
                     cal_loading, cal_error, runtime_valid);
        end
    end

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

    task automatic send_batch_payload(input [31:0] base);
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

    task automatic send_full_bg(input [31:0] base);
        int b;
    begin
        for (b = 0; b < 4; b++) begin
            send_cal_header(10'd0, b[1:0]);
            send_batch_payload(base + (b * 32'h1000));
        end
    end
    endtask

    // 2-step synchronous port-B read:
    // request address, wait one extra cycle for registered BRAM output to align,
    // then sample doutb.
    task automatic read_bg_addr(input [9:0] addr, output logic [31:0] data);
    begin
        @(negedge clk);
        bg_rd_en   = 1'b1;
        bg_rd_addr = addr;

        @(posedge clk);   // BRAM captures addr/en
        @(posedge clk);   // registered output updates for that captured addr
        @(negedge clk);
        data = bg_rd_data;

        bg_rd_en   = 1'b0;
        bg_rd_addr = '0;
    end
    endtask

    task automatic check_bg_anchor(input [9:0] addr, input [31:0] exp);
        logic [31:0] got;
    begin
        read_bg_addr(addr, got);
        $display("[BG RD] t=%0t addr=%0d got=0x%08h exp=0x%08h", $time, addr, got, exp);
        expect_local(got === exp, $sformatf("BG[%0d] matches expected", addr));
    end
    endtask

    initial begin
        clear_drive();
        bg_rd_en   = 1'b0;
        bg_rd_addr = 10'd0;
        allow_cal  = 1'b1;
        dsp_busy   = 1'b0;

        repeat (8) @(negedge clk);
        rst = 1'b0;
        idle_cycles(2);

        $display("--------------------------------------------------");
        $display("BG LOCALIZATION TEST");
        $display("--------------------------------------------------");

        send_full_bg(32'h0001_0000);
        idle_cycles(8);

        expect_local(!cal_error, "No error on valid BG load");
        expect_local(bg_write_count == 1024, "BG issued 1024 writes");
        expect_local(bg_last_addr == 10'd1023, "BG last write addr is 1023");
        expect_local(bg_last_data == (32'h0001_0000 + 32'h3000 + 32'd255), "BG last write data correct");
        expect_local(runtime_valid[0] == 1'b1, "runtime_valid[0] set");

        check_bg_anchor(10'd0,    32'h0001_0000);
        check_bg_anchor(10'd1,    32'h0001_0001);
        check_bg_anchor(10'd255,  32'h0001_00FF);
        check_bg_anchor(10'd256,  32'h0001_1000);
        check_bg_anchor(10'd511,  32'h0001_10FF);
        check_bg_anchor(10'd512,  32'h0001_2000);
        check_bg_anchor(10'd767,  32'h0001_20FF);
        check_bg_anchor(10'd768,  32'h0001_3000);
        check_bg_anchor(10'd1023, 32'h0001_30FF);

        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");
        $finish;
    end

endmodule

/*
module tb_calibration_loader;

    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    // -----------------------------
    // DUT inputs
    // -----------------------------
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

    // -----------------------------
    // DUT outputs
    // -----------------------------
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
    logic [17:0] disp_a_wr_data;

    logic        disp_b_wr_en;
    logic [0:0]  disp_b_wr_we;
    logic [9:0]  disp_b_wr_addr;
    logic [17:0] disp_b_wr_data;

    logic        klin_a_wr_en;
    logic [0:0]  klin_a_wr_we;
    logic [9:0]  klin_a_wr_addr;
    logic [9:0]  klin_a_wr_data;

    logic        klin_b_wr_en;
    logic [0:0]  klin_b_wr_we;
    logic [9:0]  klin_b_wr_addr;
    logic [17:0] klin_b_wr_data;

    logic        klin_c_wr_en;
    logic [0:0]  klin_c_wr_we;
    logic [9:0]  klin_c_wr_addr;
    logic [17:0] klin_c_wr_data;

    logic        klin_d_wr_en;
    logic [0:0]  klin_d_wr_we;
    logic [9:0]  klin_d_wr_addr;
    logic [17:0] klin_d_wr_data;

    logic        klin_e_wr_en;
    logic [0:0]  klin_e_wr_we;
    logic [9:0]  klin_e_wr_addr;
    logic [17:0] klin_e_wr_data;

    // -----------------------------
    // Memory readback port B
    // -----------------------------
    logic        bg_rd_en;
    logic [9:0]  bg_rd_addr;
    logic [31:0] bg_rd_data;

    logic        disp_a_rd_en;
    logic [9:0]  disp_a_rd_addr;
    logic [17:0] disp_a_rd_data;

    logic        disp_b_rd_en;
    logic [9:0]  disp_b_rd_addr;
    logic [17:0] disp_b_rd_data;

    logic        klin_a_rd_en;
    logic [9:0]  klin_a_rd_addr;
    logic [9:0]  klin_a_rd_data_rb;

    logic        klin_b_rd_en;
    logic [9:0]  klin_b_rd_addr;
    logic [17:0] klin_b_rd_data_rb;

    logic        klin_c_rd_en;
    logic [9:0]  klin_c_rd_addr;
    logic [17:0] klin_c_rd_data_rb;

    logic        klin_d_rd_en;
    logic [9:0]  klin_d_rd_addr;
    logic [17:0] klin_d_rd_data_rb;

    logic        klin_e_rd_en;
    logic [9:0]  klin_e_rd_addr;
    logic [17:0] klin_e_rd_data_rb;

    int pass = 0;
    int fail = 0;

    // -----------------------------
    // DUT
    // -----------------------------
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

    // -----------------------------
    // Real working memory instances
    // -----------------------------
    // BG: vendor-style name from your notes
    bgsub_blk_mem_gen u_bg (
        .clka  (clk),
        .ena   (bg_wr_en),
        .wea   (bg_wr_we),
        .addra (bg_wr_addr),
        .dina  (bg_wr_data),
        .clkb  (clk),
        .enb   (bg_rd_en),
        .addrb (bg_rd_addr),
        .doutb (bg_rd_data)
    );

    // Future BRAM form for disp paths, instantiated but not actively tested
    dp_ram_18x1024 u_disp_a (
        .clka  (clk),
        .ena   (disp_a_wr_en),
        .wea   (disp_a_wr_we),
        .addra (disp_a_wr_addr),
        .dina  (disp_a_wr_data),
        .clkb  (clk),
        .enb   (disp_a_rd_en),
        .addrb (disp_a_rd_addr),
        .doutb (disp_a_rd_data)
    );

    dp_ram_18x1024 u_disp_b (
        .clka  (clk),
        .ena   (disp_b_wr_en),
        .wea   (disp_b_wr_we),
        .addra (disp_b_wr_addr),
        .dina  (disp_b_wr_data),
        .clkb  (clk),
        .enb   (disp_b_rd_en),
        .addrb (disp_b_rd_addr),
        .doutb (disp_b_rd_data)
    );

    // klin_base = klin A
    klin_base_rom u_klin_a (
        .clka  (clk),
        .ena   (klin_a_wr_en),
        .wea   (klin_a_wr_we),
        .addra (klin_a_wr_addr),
        .dina  (klin_a_wr_data),
        .clkb  (clk),
        .enb   (klin_a_rd_en),
        .addrb (klin_a_rd_addr),
        .doutb (klin_a_rd_data_rb)
    );

    // klin_c0..c4 = klin B..E in your naming convention
    klin_c0_rom u_klin_b (
        .clka  (clk),
        .ena   (klin_b_wr_en),
        .wea   (klin_b_wr_we),
        .addra (klin_b_wr_addr),
        .dina  (klin_b_wr_data),
        .clkb  (clk),
        .enb   (klin_b_rd_en),
        .addrb (klin_b_rd_addr),
        .doutb (klin_b_rd_data_rb)
    );

    klin_c1_rom u_klin_c (
        .clka  (clk),
        .ena   (klin_c_wr_en),
        .wea   (klin_c_wr_we),
        .addra (klin_c_wr_addr),
        .dina  (klin_c_wr_data),
        .clkb  (clk),
        .enb   (klin_c_rd_en),
        .addrb (klin_c_rd_addr),
        .doutb (klin_c_rd_data_rb)
    );

    klin_c2_rom u_klin_d (
        .clka  (clk),
        .ena   (klin_d_wr_en),
        .wea   (klin_d_wr_we),
        .addra (klin_d_wr_addr),
        .dina  (klin_d_wr_data),
        .clkb  (clk),
        .enb   (klin_d_rd_en),
        .addrb (klin_d_rd_addr),
        .doutb (klin_d_rd_data_rb)
    );

    klin_c3_rom u_klin_e (
        .clka  (clk),
        .ena   (klin_e_wr_en),
        .wea   (klin_e_wr_we),
        .addra (klin_e_wr_addr),
        .dina  (klin_e_wr_data),
        .clkb  (clk),
        .enb   (klin_e_rd_en),
        .addrb (klin_e_rd_addr),
        .doutb (klin_e_rd_data_rb)
    );

    // 8th writable memory block to reflect your full architecture now.
    // Not driven by current klin mapping, but instantiated as requested.
    // Keep it for the eventual remaining BRAMized path.
    logic        reserve_wr_en;
    logic [0:0]  reserve_wr_we;
    logic [9:0]  reserve_wr_addr;
    logic [17:0] reserve_wr_data;
    logic        reserve_rd_en;
    logic [9:0]  reserve_rd_addr;
    logic [17:0] reserve_rd_data;

    klin_c4_rom u_reserve (
        .clka  (clk),
        .ena   (reserve_wr_en),
        .wea   (reserve_wr_we),
        .addra (reserve_wr_addr),
        .dina  (reserve_wr_data),
        .clkb  (clk),
        .enb   (reserve_rd_en),
        .addrb (reserve_rd_addr),
        .doutb (reserve_rd_data)
    );

    // reserve unused for now
    initial begin
        reserve_wr_en   = 1'b0;
        reserve_wr_we   = 1'b0;
        reserve_wr_addr = '0;
        reserve_wr_data = '0;
        reserve_rd_en   = 1'b0;
        reserve_rd_addr = '0;
    end

    // -----------------------------
    // Helpers
    // -----------------------------
    task automatic expect_local(input logic cond, input string msg);
    begin
        if (cond) begin
            $display("PASS: %s", msg);
            pass++;
        end else begin
            //$display("FAIL: %s", msg);
            fail++;
        end
    end
    endtask

    task automatic clear_drive();
    begin
        hdr_valid    = 0;
        pkt_is_cal   = 0;
        pkt_msg_type = 8'h00;
        batch_id     = 2'd0;
        row_id       = 10'd0;
        sample_valid = 0;
        sample_data  = 32'd0;
        sample_last  = 0;
        batch_valid  = 0;
    end
    endtask

    task automatic clear_read_ports();
    begin
        bg_rd_en      = 0; bg_rd_addr      = '0;
        disp_a_rd_en  = 0; disp_a_rd_addr  = '0;
        disp_b_rd_en  = 0; disp_b_rd_addr  = '0;
        klin_a_rd_en  = 0; klin_a_rd_addr  = '0;
        klin_b_rd_en  = 0; klin_b_rd_addr  = '0;
        klin_c_rd_en  = 0; klin_c_rd_addr  = '0;
        klin_d_rd_en  = 0; klin_d_rd_addr  = '0;
        klin_e_rd_en  = 0; klin_e_rd_addr  = '0;
    end
    endtask

    task automatic idle_cycles(input int n);
        int i;
    begin
        for (i = 0; i < n; i++) begin
            @(posedge clk);
            clear_drive();
        end
    end
    endtask

    task automatic send_cal_header(input [9:0] rid, input [1:0] bid);
    begin
        @(posedge clk);
        hdr_valid    <= 1'b1;
        pkt_is_cal   <= 1'b1;
        pkt_msg_type <= 8'h02;
        batch_id     <= bid;
        row_id       <= rid;
        sample_valid <= 1'b0;
        sample_last  <= 1'b0;
        batch_valid  <= 1'b0;

        @(posedge clk);
        clear_drive();
    end
    endtask

    task automatic send_noncal_header();
    begin
        @(posedge clk);
        hdr_valid    <= 1'b1;
        pkt_is_cal   <= 1'b0;
        pkt_msg_type <= 8'h01;
        batch_id     <= 2'd0;
        row_id       <= 10'd5;
        sample_valid <= 1'b0;
        sample_last  <= 1'b0;
        batch_valid  <= 1'b0;

        @(posedge clk);
        clear_drive();
    end
    endtask

    task automatic send_batch_payload(input [31:0] base);
        int i;
    begin
        for (i = 0; i < 256; i++) begin
            @(posedge clk);
            hdr_valid    <= 1'b0;
            pkt_is_cal   <= 1'b0;
            pkt_msg_type <= 8'h00;
            batch_id     <= 2'd0;
            row_id       <= 10'd0;

            sample_valid <= 1'b1;
            sample_data  <= base + i;
            sample_last  <= (i == 255);
            batch_valid  <= (i == 255);
        end

        @(posedge clk);
        clear_drive();
    end
    endtask

    task automatic send_full_cal(input [9:0] rid, input [31:0] base);
        int b;
    begin
        for (b = 0; b < 4; b++) begin
            send_cal_header(rid, b[1:0]);
            send_batch_payload(base + (b * 32'h1000));
        end
    end
    endtask

    // -----------------------------
    // Readback helpers
    // -----------------------------
    task automatic read_bg(input [9:0] addr, output logic [31:0] data);
    begin
        @(posedge clk);
        bg_rd_en   <= 1'b1;
        bg_rd_addr <= addr;
        @(posedge clk);
        data = bg_rd_data;
        bg_rd_en   <= 1'b0;
    end
    endtask

    task automatic read_klin_a(input [9:0] addr, output logic [9:0] data);
    begin
        @(posedge clk);
        klin_a_rd_en   <= 1'b1;
        klin_a_rd_addr <= addr;
        @(posedge clk);
        data = klin_a_rd_data_rb;
        klin_a_rd_en   <= 1'b0;
    end
    endtask

    task automatic read_klin_b(input [9:0] addr, output logic [17:0] data);
    begin
        @(posedge clk);
        klin_b_rd_en   <= 1'b1;
        klin_b_rd_addr <= addr;
        @(posedge clk);
        data = klin_b_rd_data_rb;
        klin_b_rd_en   <= 1'b0;
    end
    endtask

    task automatic read_klin_c(input [9:0] addr, output logic [17:0] data);
    begin
        @(posedge clk);
        klin_c_rd_en   <= 1'b1;
        klin_c_rd_addr <= addr;
        @(posedge clk);
        data = klin_c_rd_data_rb;
        klin_c_rd_en   <= 1'b0;
    end
    endtask

    task automatic read_klin_d(input [9:0] addr, output logic [17:0] data);
    begin
        @(posedge clk);
        klin_d_rd_en   <= 1'b1;
        klin_d_rd_addr <= addr;
        @(posedge clk);
        data = klin_d_rd_data_rb;
        klin_d_rd_en   <= 1'b0;
    end
    endtask

    task automatic read_klin_e(input [9:0] addr, output logic [17:0] data);
    begin
        @(posedge clk);
        klin_e_rd_en   <= 1'b1;
        klin_e_rd_addr <= addr;
        @(posedge clk);
        data = klin_e_rd_data_rb;
        klin_e_rd_en   <= 1'b0;
    end
    endtask

    // -----------------------------
    // Full-memory scoreboards
    // -----------------------------
    task automatic check_bg_contents(input [31:0] base);
        int i, b;
        logic [31:0] got, exp;
    begin
        for (b = 0; b < 4; b++) begin
            for (i = 0; i < 256; i++) begin
                read_bg({b[1:0], i[7:0]}, got);
                exp = base + (b * 32'h1000) + i;
                expect_local(got === exp,
                    $sformatf("BG[%0d] == 0x%08h", {b[1:0], i[7:0]}, exp));
            end
        end
    end
    endtask

    task automatic check_klin_a_contents(input [31:0] base);
        int i, b;
        logic [9:0] got, exp;
        logic [31:0] temp;
    begin
        for (b = 0; b < 4; b++) begin
            for (i = 0; i < 256; i++) begin
                read_klin_a({b[1:0], i[7:0]}, got);
                temp = (base + (b * 32'h1000) + i);
                exp = temp[9:0];
                expect_local(got === exp,
                    $sformatf("KLIN_A[%0d] == 0x%03h", {b[1:0], i[7:0]}, exp));
            end
        end
    end
    endtask

    task automatic check_klin_b_contents(input [31:0] base);
        int i, b;
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        for (b = 0; b < 4; b++) begin
            for (i = 0; i < 256; i++) begin
                read_klin_b({b[1:0], i[7:0]}, got);
                temp = (base + (b * 32'h1000) + i);
                exp = temp[17:0];
                expect_local(got === exp,
                    $sformatf("KLIN_B[%0d] == 0x%05h", {b[1:0], i[7:0]}, exp));
            end
        end
    end
    endtask

    task automatic check_klin_c_contents(input [31:0] base);
        int i, b;
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        for (b = 0; b < 4; b++) begin
            for (i = 0; i < 256; i++) begin
                read_klin_c({b[1:0], i[7:0]}, got);
                temp = (base + (b * 32'h1000) + i);
                exp = temp[17:0];
                expect_local(got === exp,
                    $sformatf("KLIN_C[%0d] == 0x%05h", {b[1:0], i[7:0]}, exp));
            end
        end
    end
    endtask

    task automatic check_klin_d_contents(input [31:0] base);
        int i, b;
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        for (b = 0; b < 4; b++) begin
            for (i = 0; i < 256; i++) begin
                read_klin_d({b[1:0], i[7:0]}, got);
                temp = (base + (b * 32'h1000) + i);
                exp = temp[17:0];
                expect_local(got === exp,
                    $sformatf("KLIN_D[%0d] == 0x%05h", {b[1:0], i[7:0]}, exp));
            end
        end
    end
    endtask

    task automatic check_klin_e_contents(input [31:0] base);
        int i, b;
        logic [17:0] got, exp;
        logic [31:0] temp;
    begin
        for (b = 0; b < 4; b++) begin
            for (i = 0; i < 256; i++) begin
                read_klin_e({b[1:0], i[7:0]}, got);
                temp = (base + (b * 32'h1000) + i);
                exp = temp[17:0];
                expect_local(got === exp,
                    $sformatf("KLIN_E[%0d] == 0x%05h", {b[1:0], i[7:0]}, exp));
            end
        end
    end
    endtask

    // -----------------------------
    // Test sequence
    // -----------------------------
    initial begin
        clear_drive();
        clear_read_ports();
        allow_cal = 1'b1;
        dsp_busy  = 1'b0;

        repeat (8) @(posedge clk);
        rst = 0;
        idle_cycles(2);

        $display("--------------------------------------------------");
        $display("TEST1: valid full background calibration");
        $display("--------------------------------------------------");
        send_full_cal(10'd0, 32'h0001_0000);
        idle_cycles(4);
        expect_local(runtime_valid[0] == 1'b1, "BG runtime_valid set");
        expect_local(cal_error == 1'b0, "No error on valid BG load");
        check_bg_contents(32'h0001_0000);

        $display("--------------------------------------------------");
        $display("TEST2: valid full klin_a calibration");
        $display("--------------------------------------------------");
        send_full_cal(10'd24, 32'h0030_0000);
        idle_cycles(4);
        expect_local(runtime_valid[3] == 1'b1, "KLIN_A runtime_valid set");
        expect_local(cal_error == 1'b0, "No error on valid KLIN_A load");
        check_klin_a_contents(32'h0030_0000);

        $display("--------------------------------------------------");
        $display("TEST3: valid full klin_b-e calibrations");
        $display("--------------------------------------------------");
        send_full_cal(10'd25, 32'h0040_0000);
        send_full_cal(10'd26, 32'h0050_0000);
        send_full_cal(10'd27, 32'h0060_0000);
        send_full_cal(10'd28, 32'h0070_0000);
        idle_cycles(4);
        expect_local(runtime_valid[4] == 1'b1, "KLIN_B runtime_valid set");
        expect_local(runtime_valid[5] == 1'b1, "KLIN_C runtime_valid set");
        expect_local(runtime_valid[6] == 1'b1, "KLIN_D runtime_valid set");
        expect_local(runtime_valid[7] == 1'b1, "KLIN_E runtime_valid set");
        check_klin_b_contents(32'h0040_0000);
        check_klin_c_contents(32'h0050_0000);
        check_klin_d_contents(32'h0060_0000);
        check_klin_e_contents(32'h0070_0000);

        $display("--------------------------------------------------");
        $display("TEST4: reject invalid row id");
        $display("--------------------------------------------------");
        send_cal_header(10'd19, 2'd0);
        idle_cycles(2);
        expect_local(cal_error, "invalid row triggers cal_error");

        $display("--------------------------------------------------");
        $display("TEST5: reject when dsp_busy");
        $display("--------------------------------------------------");
        dsp_busy = 1'b1;
        send_cal_header(10'd24, 2'd0);
        idle_cycles(2);
        dsp_busy = 1'b0;
        expect_local(cal_rejected_busy, "busy reject asserted");

        $display("--------------------------------------------------");
        $display("TEST6: reject start batch != 0");
        $display("--------------------------------------------------");
        send_cal_header(10'd24, 2'd2);
        idle_cycles(2);
        expect_local(cal_error, "start batch != 0 triggers error");

        $display("--------------------------------------------------");
        $display("TEST7: reject wrong next target/order");
        $display("--------------------------------------------------");
        send_cal_header(10'd24, 2'd0);
        send_batch_payload(32'h0100_0000);
        send_cal_header(10'd25, 2'd1);
        idle_cycles(2);
        expect_local(cal_error, "wrong continuation target triggers error");

        $display("--------------------------------------------------");
        $display("TEST8: reject non-cal header mid transaction");
        $display("--------------------------------------------------");
        send_cal_header(10'd26, 2'd0);
        send_batch_payload(32'h0200_0000);
        send_noncal_header();
        idle_cycles(2);
        expect_local(cal_error, "non-cal header mid transaction triggers error");

        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");
        $finish;
    end

endmodule


// ============================================================
// Real working simulation memories
// These are not stubs. They store data and provide registered
// readback on port B.
// If your Vivado IP models are already compiled, you can replace
// these with the actual IP without changing the TB wiring.
// ============================================================

module bgsub_blk_mem_gen (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [9:0]  addra,
    input  wire [31:0] dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [9:0]  addrb,
    output reg  [31:0] doutb
);
    reg [31:0] mem [0:1023];
    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end
    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end
endmodule

module dp_ram_18x1024 (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [9:0]  addra,
    input  wire [17:0] dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [9:0]  addrb,
    output reg  [17:0] doutb
);
    reg [17:0] mem [0:1023];
    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end
    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end
endmodule

module klin_base_rom (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [9:0]  addra,
    input  wire [9:0]  dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [9:0]  addrb,
    output reg  [9:0]  doutb
);
    reg [9:0] mem [0:1023];
    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end
    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end
endmodule

module klin_c0_rom (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [9:0]  addra,
    input  wire [17:0] dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [9:0]  addrb,
    output reg  [17:0] doutb
);
    reg [17:0] mem [0:1023];
    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end
    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end
endmodule

module klin_c1_rom (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [9:0]  addra,
    input  wire [17:0] dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [9:0]  addrb,
    output reg  [17:0] doutb
);
    reg [17:0] mem [0:1023];
    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end
    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end
endmodule

module klin_c2_rom (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [9:0]  addra,
    input  wire [17:0] dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [9:0]  addrb,
    output reg  [17:0] doutb
);
    reg [17:0] mem [0:1023];
    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end
    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end
endmodule

module klin_c3_rom (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [9:0]  addra,
    input  wire [17:0] dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [9:0]  addrb,
    output reg  [17:0] doutb
);
    reg [17:0] mem [0:1023];
    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end
    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end
endmodule

module klin_c4_rom (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [9:0]  addra,
    input  wire [17:0] dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [9:0]  addrb,
    output reg  [17:0] doutb
);
    reg [17:0] mem [0:1023];
    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end
    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end
endmodule

*/