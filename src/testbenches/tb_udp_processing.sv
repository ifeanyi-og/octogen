
/*
 * udp_processing_top_tb.v - FIXED
 * 
 * Integration testbench for complete pipeline
 * Simulates UDP packets arriving and responses being sent
 * 
 * OUTPUT: Check transcript.txt or simulator console for PASS/FAIL
 */

`timescale 1ns / 1ps

module udp_processing_top_tb;

    reg        clk;
    reg        rst;
    
    // UDP RX
    reg        udp_rx_hdr_valid;
    wire       udp_rx_hdr_ready;
    reg [31:0] udp_rx_src_ip;
    reg [15:0] udp_rx_src_port;
    reg [15:0] udp_rx_dest_port;
    reg [7:0]  udp_rx_tdata;
    reg        udp_rx_tvalid;
    wire       udp_rx_tready;
    reg        udp_rx_tlast;
    
    // UDP TX
    wire       udp_tx_hdr_valid;
    reg        udp_tx_hdr_ready;
    wire [31:0] udp_tx_dest_ip;
    wire [15:0] udp_tx_src_port;
    wire [15:0] udp_tx_dest_port;
    wire [7:0]  udp_tx_tdata;
    wire        udp_tx_tvalid;
    reg         udp_tx_tready;
    wire        udp_tx_tlast;
    
    // Debug
    wire [1:0]  debug_parser_state;
    wire [1:0]  debug_parser_byte_count;
    wire [6:0]  debug_parser_sample_count;
    wire [7:0]  debug_parser_packet_type;
    wire        debug_parser_valid_packet;
    wire        debug_parser_hdr_valid;
    wire        debug_parser_sample_tvalid;
    wire        debug_parser_sample_tready;
    wire [1:0]  debug_s2b_byte_ptr;
    wire [31:0] debug_s2b_sample_hold;
    wire        debug_udp_tx_tvalid;
    wire        debug_udp_tx_tlast;
    
    // Test counters
    integer tests_run;
    integer tests_passed;
    integer tests_failed;
    integer i;
    integer j;
    integer byte_count;
    integer response_size;
    
    // Packet buffers
    reg [7:0] packet[0:259];
    reg [7:0] response[0:255];

    udp_processing_top dut (
        .clk(clk),
        .rst(rst),
        .udp_rx_hdr_valid(udp_rx_hdr_valid),
        .udp_rx_hdr_ready(udp_rx_hdr_ready),
        .udp_rx_src_ip(udp_rx_src_ip),
        .udp_rx_src_port(udp_rx_src_port),
        .udp_rx_dest_port(udp_rx_dest_port),
        .udp_rx_tdata(udp_rx_tdata),
        .udp_rx_tvalid(udp_rx_tvalid),
        .udp_rx_tready(udp_rx_tready),
        .udp_rx_tlast(udp_rx_tlast),
        .udp_tx_hdr_valid(udp_tx_hdr_valid),
        .udp_tx_hdr_ready(udp_tx_hdr_ready),
        .udp_tx_dest_ip(udp_tx_dest_ip),
        .udp_tx_src_port(udp_tx_src_port),
        .udp_tx_dest_port(udp_tx_dest_port),
        .udp_tx_tdata(udp_tx_tdata),
        .udp_tx_tvalid(udp_tx_tvalid),
        .udp_tx_tready(udp_tx_tready),
        .udp_tx_tlast(udp_tx_tlast),
        .debug_parser_state(debug_parser_state),
        .debug_parser_byte_count(debug_parser_byte_count),
        .debug_parser_sample_count(debug_parser_sample_count),
        .debug_parser_packet_type(debug_parser_packet_type),
        .debug_parser_valid_packet(debug_parser_valid_packet),
        .debug_parser_hdr_valid(debug_parser_hdr_valid),
        .debug_parser_sample_tvalid(debug_parser_sample_tvalid),
        .debug_parser_sample_tready(debug_parser_sample_tready),
        .debug_s2b_byte_ptr(debug_s2b_byte_ptr),
        .debug_s2b_sample_hold(debug_s2b_sample_hold),
        .debug_udp_tx_tvalid(debug_udp_tx_tvalid),
        .debug_udp_tx_tlast(debug_udp_tx_tlast),
        .debug_stored_src_ip(),
        .debug_stored_src_port(),
        .debug_stored_dest_port()
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper task: Send UDP packet
    // Properly handshakes header, then sends payload bytes
    task send_udp_packet(
        input [31:0] src_ip,
        input [15:0] src_port,
        input [15:0] dest_port,
        input [15:0] data_size
    );
        integer idx;
        
        // ====== Send header ======
        udp_rx_hdr_valid = 1;
        udp_rx_src_ip = src_ip;
        udp_rx_src_port = src_port;
        udp_rx_dest_port = dest_port;
        udp_rx_tvalid = 0;  // No data yet
        @(posedge clk);
        
        // ====== Wait for header ready handshake ======
        while (!udp_rx_hdr_ready) begin
            @(posedge clk);
        end
        
        // ====== Now send payload bytes ======
        udp_rx_hdr_valid = 0;
        for (idx = 0; idx < data_size; idx = idx + 1) begin
            udp_rx_tdata = packet[idx];
            udp_rx_tvalid = 1;
            udp_rx_tlast = (idx == data_size - 1);
            @(posedge clk);
        end
        
        // ====== End of packet ======
        udp_rx_tvalid = 0;
        udp_rx_tlast = 0;
    endtask

    // Helper task: Receive UDP response
    task receive_response;
        integer resp_idx;
        integer timeout_count;
        
        resp_idx = 0;
        timeout_count = 0;
        response_size = 0;
        
        // Wait for tx_hdr_valid
        while (!udp_tx_hdr_valid && timeout_count < 1000) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end
        
        if (timeout_count >= 1000) begin
            $display("      [FAIL] Timeout waiting for TX header");
            return;
        end
        
        udp_tx_hdr_ready = 1;
        @(posedge clk);
        udp_tx_hdr_ready = 0;
        
        // Receive payload
        udp_tx_tready = 1;
        timeout_count = 0;
        while (timeout_count < 2000) begin
            if (udp_tx_tvalid) begin
                response[resp_idx] = udp_tx_tdata;
                resp_idx = resp_idx + 1;
            end
            
            if (udp_tx_tlast && udp_tx_tvalid) begin
                response_size = resp_idx;
                break;
            end
            
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end
        
        udp_tx_tready = 0;
    endtask

    // Helper task: Report test result
    task report_test(input pass, input [200*8:0] message);
        tests_run = tests_run + 1;
        if (pass) begin
            tests_passed = tests_passed + 1;
            $display("  ✓ PASS: %s", message);
        end else begin
            tests_failed = tests_failed + 1;
            $display("  ✗ FAIL: %s", message);
        end
    endtask

    // Main test
    initial begin
        integer timeout;
        
        // Initialize
        tests_run = 0;
        tests_passed = 0;
        tests_failed = 0;
        
        rst = 1;
        udp_rx_hdr_valid = 0;
        udp_rx_tdata = 0;
        udp_rx_tvalid = 0;
        udp_rx_tlast = 0;
        udp_tx_hdr_ready = 0;
        udp_tx_tready = 0;
        
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        $display("");
        $display("================================================================================");
        $display("UDP_PROCESSING_TOP INTEGRATION TEST");
        $display("================================================================================");
        
        // ========================================================================
        // TEST 1: Valid DSP packet to port 5001
        // ========================================================================
        $display("\nTEST 1: Valid DSP packet to port 5001");
        $display("  Setup: Send [0xFF][0x00][batch][seq] + 64 samples");
        
        // Create packet
        packet[0] = 8'hFF;      // Magic
        packet[1] = 8'h00;      // Type = DSP
        packet[2] = 8'h01;      // Batch
        packet[3] = 8'h42;      // Seq
        
        for (i = 0; i < 64; i = i + 1) begin
            packet[4 + i*4 + 0] = 8'h11;
            packet[4 + i*4 + 1] = 8'h22;
            packet[4 + i*4 + 2] = 8'h33;
            packet[4 + i*4 + 3] = 8'h44;
        end
        
        send_udp_packet(
            {8'd192, 8'd168, 8'd10, 8'd10},
            16'd5678,
            16'd5001,
            16'd260
        );
        
        receive_response();
        
        // Check response
        report_test(
            response_size == 256,
            "Response size is 256 bytes"
        );
        
        report_test(
            response[0] == 8'h11 && response[1] == 8'h22,
            "First sample data correct (0x11223344)"
        );
        
        @(posedge clk);
        @(posedge clk);
        
        // ========================================================================
        // TEST 2: Packet to wrong port (5002)
        // ========================================================================
        $display("\nTEST 2: Packet to wrong port (5002 instead of 5001)");
        $display("  Setup: Send packet to port 5002");
        
        packet[0] = 8'hFF;
        packet[1] = 8'h00;
        packet[2] = 8'h00;
        packet[3] = 8'h00;
        for (i = 0; i < 64; i = i + 1) begin
            packet[4 + i*4 + 0] = 8'h55;
            packet[4 + i*4 + 1] = 8'h55;
            packet[4 + i*4 + 2] = 8'h55;
            packet[4 + i*4 + 3] = 8'h55;
        end
        
        send_udp_packet(
            {8'd192, 8'd168, 8'd10, 8'd10},
            16'd5678,
            16'd5002,  // Wrong port!
            16'd260
        );
        
        // Wait and check no response
        timeout = 0;
        while (timeout < 500 && !udp_tx_hdr_valid) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        
        report_test(
            !udp_tx_hdr_valid,
            "Packet correctly filtered (no response)"
        );
        
        @(posedge clk);
        @(posedge clk);
        
        // ========================================================================
        // TEST 3: Bad magic byte (0xAA instead of 0xFF)
        // ========================================================================
        $display("\nTEST 3: Bad magic byte");
        $display("  Setup: Send packet with 0xAA as magic byte");
        
        packet[0] = 8'hAA;  // Bad magic!
        packet[1] = 8'h00;
        packet[2] = 8'h00;
        packet[3] = 8'h00;
        for (i = 0; i < 64; i = i + 1) begin
            packet[4 + i*4 + 0] = 8'h66;
            packet[4 + i*4 + 1] = 8'h66;
            packet[4 + i*4 + 2] = 8'h66;
            packet[4 + i*4 + 3] = 8'h66;
        end
        
        send_udp_packet(
            {8'd192, 8'd168, 8'd10, 8'd10},
            16'd5678,
            16'd5001,
            16'd260
        );
        
        timeout = 0;
        while (timeout < 500 && !udp_tx_hdr_valid) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        
        report_test(
            !udp_tx_hdr_valid,
            "Packet correctly discarded (bad magic)"
        );
        
        @(posedge clk);
        @(posedge clk);
        
        // ========================================================================
        // TEST 4: Bad packet type (0x99 instead of 0x00-0x03)
        // ========================================================================
        $display("\nTEST 4: Invalid packet type");
        $display("  Setup: Send packet with invalid type 0x99");
        
        packet[0] = 8'hFF;
        packet[1] = 8'h99;  // Bad type!
        packet[2] = 8'h00;
        packet[3] = 8'h00;
        for (i = 0; i < 64; i = i + 1) begin
            packet[4 + i*4 + 0] = 8'h77;
            packet[4 + i*4 + 1] = 8'h77;
            packet[4 + i*4 + 2] = 8'h77;
            packet[4 + i*4 + 3] = 8'h77;
        end
        
        send_udp_packet(
            {8'd192, 8'd168, 8'd10, 8'd10},
            16'd5678,
            16'd5001,
            16'd260
        );
        
        timeout = 0;
        while (timeout < 500 && !udp_tx_hdr_valid) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        
        report_test(
            !udp_tx_hdr_valid,
            "Packet correctly discarded (bad type)"
        );
        
        @(posedge clk);
        @(posedge clk);
        
        // ========================================================================
        // TEST 5: Calibration packet (type 0x01)
        // ========================================================================
        $display("\nTEST 5: Calibration packet (should be discarded)");
        $display("  Setup: Send calibration packet (type 0x01)");
        
        packet[0] = 8'hFF;
        packet[1] = 8'h01;  // Calibration type
        packet[2] = 8'h00;
        packet[3] = 8'h00;
        for (i = 0; i < 64; i = i + 1) begin
            packet[4 + i*4 + 0] = 8'h88;
            packet[4 + i*4 + 1] = 8'h88;
            packet[4 + i*4 + 2] = 8'h88;
            packet[4 + i*4 + 3] = 8'h88;
        end
        
        send_udp_packet(
            {8'd192, 8'd168, 8'd10, 8'd10},
            16'd5678,
            16'd5001,
            16'd260
        );
        
        timeout = 0;
        while (timeout < 500 && !udp_tx_hdr_valid) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        
        report_test(
            !udp_tx_hdr_valid,
            "Calibration packet correctly discarded"
        );
        
        @(posedge clk);
        @(posedge clk);
        
        // ========================================================================
        // FINAL SUMMARY
        // ========================================================================
        $display("");
        $display("================================================================================");
        $display("TEST SUMMARY");
        $display("================================================================================");
        $display("Tests Run:    %0d", tests_run);
        $display("Tests Passed: %0d", tests_passed);
        $display("Tests Failed: %0d", tests_failed);
        
        if (tests_failed == 0) begin
            $display("");
            $display("✓✓✓ ALL TESTS PASSED ✓✓✓");
            $display("");
        end else begin
            $display("");
            $display("✗✗✗ SOME TESTS FAILED ✗✗✗");
            $display("");
        end
        
        $display("================================================================================");
        $finish;
    end

endmodule

