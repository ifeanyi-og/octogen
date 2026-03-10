
`timescale 1ns/1ps

module tb_packet_rx;

    logic clk = 0;
    logic rst = 1;

    always #5 clk = ~clk;

    logic [7:0] udp_rx_tdata;
    logic       udp_rx_tvalid;
    logic       udp_rx_tlast;
    logic       udp_rx_tready;

    logic       batch_valid;
    logic [9:0] batch_row_id;
    logic [1:0] batch_id;

    logic [31:0] sample_re;
    logic [31:0] sample_im;
    logic        sample_valid;
    logic        sample_last;

    logic hdr_error;

    int pass = 0;
    int fail = 0;

    // ------------------------------------------------------------
    // Capture registers for pulse/event-based checking
    // ------------------------------------------------------------
    logic       seen_batch_valid;
    logic [9:0] seen_batch_row_id;
    logic [1:0] seen_batch_id;

    logic       seen_hdr_error;

    logic       seen_last_sample;
    logic [31:0] last_sample_re;
    logic [31:0] last_sample_im;

    int sample_count_seen;

    app_packet_rx dut(
        .clk(clk),
        .rst(rst),
        .udp_rx_tdata(udp_rx_tdata),
        .udp_rx_tvalid(udp_rx_tvalid),
        .udp_rx_tready(udp_rx_tready),
        .udp_rx_tlast(udp_rx_tlast),
        .batch_valid(batch_valid),
        .batch_row_id(batch_row_id),
        .batch_id(batch_id),
        .sample_re(sample_re),
        .sample_im(sample_im),
        .sample_valid(sample_valid),
        .sample_last(sample_last),
        .hdr_error(hdr_error)
    );

    // ------------------------------------------------------------
    // Scoreboard / event monitor
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            seen_batch_valid <= 0;
            seen_batch_row_id <= '0;
            seen_batch_id <= '0;

            seen_hdr_error <= 0;

            seen_last_sample <= 0;
            last_sample_re <= '0;
            last_sample_im <= '0;

            sample_count_seen <= 0;
        end else begin
            if (batch_valid) begin
                seen_batch_valid <= 1;
                seen_batch_row_id <= batch_row_id;
                seen_batch_id <= batch_id;
            end

            if (hdr_error) begin
                seen_hdr_error <= 1;
            end

            if (sample_valid) begin
                sample_count_seen <= sample_count_seen + 1;
                if (sample_last) begin
                    seen_last_sample <= 1;
                    last_sample_re <= sample_re;
                    last_sample_im <= sample_im;
                end
            end
        end
    end

    task clear_captures;
    begin
        seen_batch_valid = 0;
        seen_batch_row_id = '0;
        seen_batch_id = '0;
        seen_hdr_error = 0;
        seen_last_sample = 0;
        last_sample_re = '0;
        last_sample_im = '0;
        sample_count_seen = 0;
    end
    endtask

    task expect_local(input logic cond, input string msg);
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

    // Drive one byte for one cycle
    task send_byte(input [7:0] b, input logic last);
    begin
        @(posedge clk);
        udp_rx_tdata  <= b;
        udp_rx_tvalid <= 1'b1;
        udp_rx_tlast  <= last;
    end
    endtask

    task idle_cycles(input int n);
        int k;
    begin
        for (k = 0; k < n; k++) begin
            @(posedge clk);
            udp_rx_tvalid <= 1'b0;
            udp_rx_tlast  <= 1'b0;
            udp_rx_tdata  <= 8'h00;
        end
    end
    endtask

    task send_header(input [9:0] row, input [1:0] batch);
        logic [31:0] hdr;
    begin
        // header[31:24] = 0xFF
        // header[23:16] = 0xFF
        // header[15:14] = batch
        // header[13:10] = reserved
        // header[9:0]   = row
        hdr = {8'hFF, 8'hFF, batch, 4'b0000, row};

        // stream LSB first
        send_byte(hdr[7:0],   1'b0);
        send_byte(hdr[15:8],  1'b0);
        send_byte(hdr[23:16], 1'b0);
        send_byte(hdr[31:24], 1'b0);
    end
    endtask

    task send_payload;
        int i;
        logic [31:0] re;
        logic [31:0] im;
    begin
        for (i = 0; i < 128; i++) begin
            re = i;
            im = i + 100;

            // Re, little-endian
            send_byte(re[7:0],   1'b0);
            send_byte(re[15:8],  1'b0);
            send_byte(re[23:16], 1'b0);
            send_byte(re[31:24], 1'b0);

            // Im, little-endian
            send_byte(im[7:0],   1'b0);
            send_byte(im[15:8],  1'b0);
            send_byte(im[23:16], 1'b0);
            send_byte(im[31:24], (i == 127));
        end
    end
    endtask

    initial begin
        udp_rx_tvalid = 0;
        udp_rx_tlast  = 0;
        udp_rx_tdata  = 0;

        repeat(10) @(posedge clk);
        rst = 0;

        // --------------------------------------------------------
        // TEST 1: Valid packet
        // --------------------------------------------------------
        $display("TEST1: valid packet");
        clear_captures();

        send_header(10, 2);
        send_payload();
        idle_cycles(4);

        expect_local(seen_batch_valid, "batch_valid pulse seen");
        expect_local(seen_batch_row_id == 10, "row id correct");
        expect_local(seen_batch_id == 2, "batch id correct");
        expect_local(sample_count_seen == 128, "128 samples seen");

        // --------------------------------------------------------
        // TEST 2: Last sample reconstruction
        // --------------------------------------------------------
        $display("TEST2: sample reconstruction");
        expect_local(seen_last_sample, "last sample seen");
        expect_local(last_sample_re == 127, "last sample re correct");
        expect_local(last_sample_im == 227, "last sample im correct");

        // --------------------------------------------------------
        // TEST 3: Header error
        // --------------------------------------------------------
        $display("TEST3: header error");
        clear_captures();

        // bad header, last byte ends packet
        send_byte(8'h00, 1'b0);
        send_byte(8'h00, 1'b0);
        send_byte(8'h00, 1'b0);
        send_byte(8'h00, 1'b1);
        idle_cycles(4);

        expect_local(seen_hdr_error, "header error detected");

        // --------------------------------------------------------
        // TEST 4: Back-to-back packets
        // --------------------------------------------------------
        $display("TEST4: back-to-back packets");
        clear_captures();

        send_header(55, 1);
        send_payload();
        idle_cycles(2);

        // clear after first so we only check second packet
        clear_captures();

        send_header(56, 3);
        send_payload();
        idle_cycles(4);

        expect_local(seen_batch_valid, "second packet batch_valid seen");
        expect_local(seen_batch_row_id == 56, "second packet row id correct");
        expect_local(seen_batch_id == 3, "second packet batch id correct");
        expect_local(last_sample_re == 127, "second packet last sample re correct");
        expect_local(last_sample_im == 227, "second packet last sample im correct");

        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");

        $finish;
    end

endmodule

