`timescale 1ns/1ps

module tb_packet_rx;

    logic clk = 0;
    logic rst = 1;

    always #5 clk = ~clk;

    logic [7:0] udp_rx_tdata;
    logic       udp_rx_tvalid;
    logic       udp_rx_tlast;
    logic       udp_rx_tready;

    logic       hdr_valid;
    logic       hdr_error;
    logic       pkt_is_data;
    logic       pkt_is_cal;
    logic [7:0] pkt_msg_type;
    logic [1:0] batch_id;
    logic [9:0] row_id;

    logic       batch_valid;
    logic [31:0] sample_data;
    logic        sample_valid;
    logic        sample_last;

    int pass = 0;
    int fail = 0;

    logic       seen_hdr_valid;
    logic       seen_hdr_error;
    logic       seen_pkt_is_data;
    logic       seen_pkt_is_cal;
    logic [7:0] seen_pkt_msg_type;
    logic [1:0] seen_batch_id;
    logic [9:0] seen_row_id;

    logic       seen_batch_valid;
    logic       seen_last_sample;
    logic [31:0] last_sample_data;
    int          sample_count_seen;

    app_packet_rx dut (
        .clk(clk),
        .rst(rst),
        .udp_rx_tdata(udp_rx_tdata),
        .udp_rx_tvalid(udp_rx_tvalid),
        .udp_rx_tready(udp_rx_tready),
        .udp_rx_tlast(udp_rx_tlast),

        .hdr_valid(hdr_valid),
        .hdr_error(hdr_error),
        .pkt_is_data(pkt_is_data),
        .pkt_is_cal(pkt_is_cal),
        .pkt_msg_type(pkt_msg_type),
        .batch_id(batch_id),
        .row_id(row_id),

        .batch_valid(batch_valid),
        .sample_data(sample_data),
        .sample_valid(sample_valid),
        .sample_last(sample_last)
    );
    
    logic counting_active;
    
    always @(posedge clk) begin
        if (rst) begin
            seen_hdr_valid     <= 0;
            seen_hdr_error     <= 0;
            seen_pkt_is_data   <= 0;
            seen_pkt_is_cal    <= 0;
            seen_pkt_msg_type  <= '0;
            seen_batch_id      <= '0;
            seen_row_id        <= '0;
            seen_batch_valid   <= 0;
            seen_last_sample   <= 0;
            last_sample_data   <= '0;
            sample_count_seen  <= 0;
            counting_active    <= 0;
        end else begin
            if (hdr_valid) begin
                seen_hdr_valid    <= 1;
                seen_pkt_is_data  <= pkt_is_data;
                seen_pkt_is_cal   <= pkt_is_cal;
                seen_pkt_msg_type <= pkt_msg_type;
                seen_batch_id     <= batch_id;
                seen_row_id       <= row_id;
                sample_count_seen <= 0;
                counting_active   <= 1;
            end
    
            if (hdr_error)
                seen_hdr_error <= 1;
    
            if (sample_valid && counting_active) begin
                sample_count_seen <= sample_count_seen + 1;
                if (sample_last) begin
                    seen_last_sample <= 1;
                    last_sample_data <= sample_data;
                end
            end
    
            if (batch_valid) begin
                seen_batch_valid <= 1;
                counting_active  <= 0;
            end
        end
    end

    task clear_captures;
    begin
        seen_hdr_valid    = 0;
        seen_hdr_error    = 0;
        seen_pkt_is_data  = 0;
        seen_pkt_is_cal   = 0;
        seen_pkt_msg_type = '0;
        seen_batch_id     = '0;
        seen_row_id       = '0;
        seen_batch_valid  = 0;
        seen_last_sample  = 0;
        last_sample_data  = '0;
        sample_count_seen = 0;
        counting_active   = 0;
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

    task send_header(input [7:0] msg_type, input [9:0] row, input [1:0] batch);
        logic [31:0] hdr;
    begin
        hdr = {8'hFF, msg_type, batch, 4'b0000, row};

        send_byte(hdr[7:0],   1'b0);
        send_byte(hdr[15:8],  1'b0);
        send_byte(hdr[23:16], 1'b0);
        send_byte(hdr[31:24], 1'b0);
    end
    endtask

    task send_payload(input [31:0] base);
        int i;
        logic [31:0] val;
    begin
        for (i = 0; i < 256; i++) begin
            val = base + i;

            send_byte(val[7:0],   1'b0);
            send_byte(val[15:8],  1'b0);
            send_byte(val[23:16], 1'b0);
            send_byte(val[31:24], (i == 255));
        end
    end
    endtask

    initial begin
        udp_rx_tvalid = 0;
        udp_rx_tlast  = 0;
        udp_rx_tdata  = 0;

        repeat (10) @(posedge clk);
        rst = 0;

        // ------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST1: valid data packet 0xFF01");
        $display("--------------------------------------------------");
        clear_captures();

        send_header(8'h01, 10'd10, 2'd2);
        send_payload(32'h00001000);
        idle_cycles(4);

        expect_local(seen_hdr_valid, "hdr_valid seen");
        expect_local(!seen_hdr_error, "no hdr_error");
        expect_local(seen_pkt_is_data, "classified as data");
        expect_local(!seen_pkt_is_cal, "not classified as cal");
        expect_local(seen_pkt_msg_type == 8'h01, "msg_type correct");
        expect_local(seen_row_id == 10'd10, "row_id correct");
        expect_local(seen_batch_id == 2'd2, "batch_id correct");
        expect_local(seen_batch_valid, "batch_valid seen");
        expect_local(sample_count_seen == 256, "256 samples seen");
        expect_local(seen_last_sample, "sample_last seen");
        expect_local(last_sample_data == 32'h000010FF, "last sample data correct");

        // ------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST2: valid calibration packet 0xFF02");
        $display("--------------------------------------------------");
        clear_captures();

        send_header(8'h02, 10'd24, 2'd1); // KLIN_A target id
        send_payload(32'h00002000);
        idle_cycles(4);

        expect_local(seen_hdr_valid, "hdr_valid seen");
        expect_local(!seen_hdr_error, "no hdr_error");
        expect_local(!seen_pkt_is_data, "not classified as data");
        expect_local(seen_pkt_is_cal, "classified as cal");
        expect_local(seen_pkt_msg_type == 8'h02, "msg_type correct");
        expect_local(seen_row_id == 10'd24, "cal target row_id correct");
        expect_local(seen_batch_id == 2'd1, "cal batch_id correct");
        expect_local(seen_batch_valid, "cal batch_valid seen");
        expect_local(sample_count_seen == 256, "256 cal samples seen");
        expect_local(last_sample_data == 32'h000020FF, "cal last sample correct");

        // ------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST3: reject 0xFF03");
        $display("--------------------------------------------------");
        clear_captures();

        send_header(8'h03, 10'd12, 2'd0);
        idle_cycles(4);

        expect_local(!seen_hdr_valid, "no hdr_valid for 0xFF03");
        expect_local(seen_hdr_error, "hdr_error for 0xFF03");

        // ------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST4: reject bad magic");
        $display("--------------------------------------------------");
        clear_captures();

        send_byte(8'h0A, 1'b0);
        send_byte(8'h00, 1'b0);
        send_byte(8'h01, 1'b0);
        send_byte(8'hFE, 1'b1);
        idle_cycles(4);

        expect_local(!seen_hdr_valid, "no hdr_valid for bad magic");
        expect_local(seen_hdr_error, "hdr_error for bad magic");

        // ------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST5: reject non-zero reserved bits");
        $display("--------------------------------------------------");
        clear_captures();

        // hdr = {8'hFF,8'h01,2'b01,4'b1010,10'd33}
        send_byte(8'h21, 1'b0); // [7:0]
        send_byte(8'h68, 1'b0); // [15:8] => batch=01, reserved=1010, row[9:8]=00
        send_byte(8'h01, 1'b0); // [23:16]
        send_byte(8'hFF, 1'b1); // [31:24]
        idle_cycles(4);

        expect_local(!seen_hdr_valid, "no hdr_valid for reserved bits != 0");
        expect_local(seen_hdr_error, "hdr_error for reserved bits != 0");

        // ------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("TEST6: back-to-back data then cal");
        $display("--------------------------------------------------");
        clear_captures();

        send_header(8'h01, 10'd55, 2'd1);
        send_payload(32'h00003000);
        idle_cycles(2);

        clear_captures();

        send_header(8'h02, 10'd20, 2'd3);
        send_payload(32'h00004000);
        idle_cycles(4);

        expect_local(seen_hdr_valid, "second hdr_valid seen");
        expect_local(seen_pkt_is_cal, "second packet classified as cal");
        expect_local(seen_pkt_msg_type == 8'h02, "second packet msg_type correct");
        expect_local(seen_row_id == 10'd20, "second packet row_id correct");
        expect_local(seen_batch_id == 2'd3, "second packet batch_id correct");
        expect_local(seen_batch_valid, "second packet batch_valid seen");
        expect_local(sample_count_seen == 256, "second packet 256 samples seen");
        expect_local(last_sample_data == 32'h000040FF, "second packet last sample correct");

        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");

        $finish;
    end

endmodule
