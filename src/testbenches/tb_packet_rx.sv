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

    logic [31:0] sample_data;
    logic        sample_valid;
    logic        sample_last;

    logic hdr_error;

    int pass = 0;
    int fail = 0;

    logic       seen_batch_valid;
    logic [9:0] seen_batch_row_id;
    logic [1:0] seen_batch_id;

    logic       seen_hdr_error;

    logic       seen_last_sample;
    logic [31:0] last_sample_data;

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
        .sample_data(sample_data),
        .sample_valid(sample_valid),
        .sample_last(sample_last),
        .hdr_error(hdr_error)
    );

    always @(posedge clk) begin
        if (rst) begin
            seen_batch_valid <= 0;
            seen_batch_row_id <= '0;
            seen_batch_id <= '0;
            seen_hdr_error <= 0;
            seen_last_sample <= 0;
            last_sample_data <= '0;
            sample_count_seen <= 0;
        end else begin
            if (batch_valid) begin
                seen_batch_valid <= 1;
                seen_batch_row_id <= batch_row_id;
                seen_batch_id <= batch_id;
            end

            if (hdr_error)
                seen_hdr_error <= 1;

            if (sample_valid) begin
                sample_count_seen <= sample_count_seen + 1;
                if (sample_last) begin
                    seen_last_sample <= 1;
                    last_sample_data <= sample_data;
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
        last_sample_data = '0;
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
        hdr = {8'hFF, 8'h01, batch, 4'b0000, row};

        send_byte(hdr[7:0],   1'b0);
        send_byte(hdr[15:8],  1'b0);
        send_byte(hdr[23:16], 1'b0);
        send_byte(hdr[31:24], 1'b0);
    end
    endtask

    task send_payload;
        int i;
        logic [31:0] val;
    begin
        for (i = 0; i < 256; i++) begin
            val = i + 32'h1000;

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

        repeat(10) @(posedge clk);
        rst = 0;

        $display("TEST1: valid packet");
        clear_captures();

        send_header(10, 2);
        send_payload();
        idle_cycles(4);

        expect_local(seen_batch_valid, "batch_valid pulse seen");
        expect_local(seen_batch_row_id == 10, "row id correct");
        expect_local(seen_batch_id == 2, "batch id correct");
        expect_local(sample_count_seen == 256, "256 samples seen");

        $display("TEST2: last sample reconstruction");
        expect_local(seen_last_sample, "last sample seen");
        expect_local(last_sample_data == (32'h1000 + 255), "last sample correct");

        $display("TEST3: header error");
        clear_captures();

        send_byte(8'h00, 1'b0);
        send_byte(8'h00, 1'b0);
        send_byte(8'h00, 1'b0);
        send_byte(8'h00, 1'b1);
        idle_cycles(4);

        expect_local(seen_hdr_error, "header error detected");

        $display("TEST4: back-to-back packets");
        clear_captures();

        send_header(55, 1);
        send_payload();
        idle_cycles(2);

        clear_captures();

        send_header(56, 3);
        send_payload();
        idle_cycles(4);

        expect_local(seen_batch_valid, "second packet batch_valid seen");
        expect_local(seen_batch_row_id == 56, "second packet row id correct");
        expect_local(seen_batch_id == 3, "second packet batch id correct");
        expect_local(last_sample_data == (32'h1000 + 255), "second packet last sample correct");

        $display("=================================");
        $display("TOTAL PASS = %0d", pass);
        $display("TOTAL FAIL = %0d", fail);
        $display("=================================");

        $finish;
    end

endmodule

