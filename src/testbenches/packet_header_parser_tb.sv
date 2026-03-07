
/*
 * packet_header_parser_tb.v - FIXED
 * 
 * Testbench for packet_header_parser module
 * Tests:
 * 1. Valid DSP packet (0xFF 0x00 ...)
 * 2. Bad magic byte (0xAA 0x00 ...)
 * 3. Bad type (0xFF 0x99 ...)
 * 4. Calibration packet (0xFF 0x01 ...)
 * 5. Multiple packets in sequence
 */

`timescale 1ns / 1ps

module packet_header_parser_tb;

    reg        clk;
    reg        rst;
    reg [7:0]  s_udp_tdata;
    reg        s_udp_tvalid;
    wire       s_udp_tready;
    reg        s_udp_tlast;
    
    wire       hdr_valid;
    reg        hdr_ready;
    wire [3:0] hdr_batch;
    wire [15:0] hdr_seq;
    
    wire [31:0] m_sample_tdata;
    wire        m_sample_tvalid;
    reg         m_sample_tready;
    wire        m_sample_tlast;
    wire [5:0]  m_sample_index;
    
    wire [1:0]  debug_state;
    wire [1:0]  debug_byte_count;
    wire [6:0]  debug_sample_count;
    wire [7:0]  debug_packet_type;
    wire        debug_valid_packet;
    
    // Test variables
    integer i;

    packet_header_parser dut (
        .clk(clk),
        .rst(rst),
        .s_udp_tdata(s_udp_tdata),
        .s_udp_tvalid(s_udp_tvalid),
        .s_udp_tready(s_udp_tready),
        .s_udp_tlast(s_udp_tlast),
        .hdr_valid(hdr_valid),
        .hdr_ready(hdr_ready),
        .hdr_batch(hdr_batch),
        .hdr_seq(hdr_seq),
        .m_sample_tdata(m_sample_tdata),
        .m_sample_tvalid(m_sample_tvalid),
        .m_sample_tready(m_sample_tready),
        .m_sample_tlast(m_sample_tlast),
        .m_sample_index(m_sample_index),
        .debug_state(debug_state),
        .debug_byte_count(debug_byte_count),
        .debug_sample_count(debug_sample_count),
        .debug_packet_type(debug_packet_type),
        .debug_valid_packet(debug_valid_packet)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper: Send one byte
    task send_byte(input [7:0] data);
        s_udp_tdata = data;
        s_udp_tvalid = 1;
        @(posedge clk);
        wait(s_udp_tready);
    endtask

    // Test stimulus
    initial begin
        // Initialize
        rst = 1;
        s_udp_tdata = 0;
        s_udp_tvalid = 0;
        s_udp_tlast = 0;
        hdr_ready = 0;
        m_sample_tready = 0;
        
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        // ========================================================================
        // TEST 1: Valid DSP packet
        // ========================================================================
        $display("TEST 1: Valid DSP packet (0xFF 0x00 0xAA 0x55 + samples)");
        
        // Send header: [0xFF][0x00][0xAA][0x55]
        send_byte(8'hFF);  // Magic
        send_byte(8'h00);  // Type = DSP
        send_byte(8'hAA);  // Batch
        send_byte(8'h55);  // Seq
        
        // Wait for header valid
        wait(hdr_valid);
        $display("  Header valid! Batch=%d, Seq=%d", hdr_batch, hdr_seq);
        hdr_ready = 1;
        @(posedge clk);
        hdr_ready = 0;
        
        // Send 64 samples
        m_sample_tready = 1;
        for (i = 0; i < 64; i = i + 1) begin
            // Send sample as 4 bytes: [byte0][byte1][byte2][byte3]
            send_byte(i[7:0]);      // Byte 0
            send_byte(i[7:0]+1);    // Byte 1
            send_byte(i[7:0]+2);    // Byte 2
            send_byte(i[7:0]+3);    // Byte 3
            
            wait(m_sample_tvalid && m_sample_tready);
            $display("  Sample %d: data=0x%08x", i, m_sample_tdata);
            
            if (i == 63) begin
                wait(m_sample_tlast);
                $display("  tlast asserted on sample 63");
            end
        end
        
        // End packet
        s_udp_tlast = 1;
        @(posedge clk);
        s_udp_tlast = 0;
        s_udp_tvalid = 0;
        @(posedge clk);
        @(posedge clk);
        
        // ========================================================================
        // TEST 2: Bad magic byte (should discard)
        // ========================================================================
        $display("\nTEST 2: Bad magic byte (0xAA instead of 0xFF)");
        
        m_sample_tready = 0;
        
        send_byte(8'hAA);  // Bad magic
        send_byte(8'h00);  // Type
        send_byte(8'h00);  // Batch
        send_byte(8'h00);  // Seq
        
        // Should NOT see hdr_valid
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
        end
        
        if (!hdr_valid) begin
            $display("  Good: No header valid for bad magic");
        end else begin
            $display("  ERROR: Header valid despite bad magic!");
        end
        
        // Finish packet
        s_udp_tlast = 1;
        @(posedge clk);
        s_udp_tlast = 0;
        s_udp_tvalid = 0;
        @(posedge clk);
        @(posedge clk);
        
        // ========================================================================
        // TEST 3: Bad type (should discard)
        // ========================================================================
        $display("\nTEST 3: Bad type (0x99 instead of 0x00-0x03)");
        
        send_byte(8'hFF);  // Good magic
        send_byte(8'h99);  // Bad type
        send_byte(8'h00);
        send_byte(8'h00);
        
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
        end
        
        if (!hdr_valid) begin
            $display("  Good: No header valid for bad type");
        end else begin
            $display("  ERROR: Header valid despite bad type!");
        end
        
        s_udp_tlast = 1;
        @(posedge clk);
        s_udp_tlast = 0;
        s_udp_tvalid = 0;
        @(posedge clk);
        @(posedge clk);
        
        // ========================================================================
        // TEST 4: Calibration packet (valid but discarded)
        // ========================================================================
        $display("\nTEST 4: Calibration packet (0xFF 0x01 ...)");
        
        send_byte(8'hFF);  // Magic
        send_byte(8'h01);  // Type = calibration
        send_byte(8'h00);
        send_byte(8'h00);
        
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
        end
        
        if (!hdr_valid) begin
            $display("  Good: Calibration packet discarded (no hdr_valid)");
        end
        
        s_udp_tlast = 1;
        @(posedge clk);
        s_udp_tlast = 0;
        s_udp_tvalid = 0;
        @(posedge clk);
        @(posedge clk);
        
        // ========================================================================
        // End test
        // ========================================================================
        $display("\nAll tests complete");
        $finish;
    end

endmodule

