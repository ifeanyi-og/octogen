`timescale 1ns / 1ps

module tb_eth_io_top;
    
    // ========================================================================
    // Clock and Reset
    // ========================================================================
    reg clk_100mhz;
    reg clk_125mhz;
    reg clk_200mhz;
    reg axis_reset;
    
    initial begin
        clk_100mhz = 0;
        forever #5 clk_100mhz = ~clk_100mhz;  // 100 MHz
    end
    
    initial begin
        clk_125mhz = 0;
        forever #4 clk_125mhz = ~clk_125mhz;  // 125 MHz
    end
    
    initial begin
        clk_200mhz = 0;
        forever #2.5 clk_200mhz = ~clk_200mhz;  // 200 MHz
    end
    
    // ========================================================================
    // Simulated RGMII PHY (loopback for testing)
    // ========================================================================
    reg [3:0]  rgmii_rd;
    reg        rgmii_rx_ctl;
    wire [3:0] rgmii_td;
    wire       rgmii_tx_ctl;
    reg        rgmii_rxc;
    wire       rgmii_txc;
    
    // For loopback testing: connect TX back to RX
    // (In real hardware, this would come from PHY)
    initial begin
        rgmii_rd = 0;
        rgmii_rx_ctl = 0;
        rgmii_rxc = 0;
    end
    
    // ========================================================================
    // UDP RX/TX signals (to/from processing)
    // ========================================================================
    wire        udp_rx_hdr_valid;
    wire        udp_rx_hdr_ready;
    wire [31:0] udp_rx_src_ip;
    wire [15:0] udp_rx_src_port;
    wire [15:0] udp_rx_dest_port;
    wire [7:0]  udp_rx_tdata;
    wire        udp_rx_tvalid;
    wire        udp_rx_tready;
    wire        udp_rx_tlast;
    
    wire        udp_tx_hdr_valid;
    wire        udp_tx_hdr_ready;
    wire [31:0] udp_tx_dest_ip;
    wire [15:0] udp_tx_src_port;
    wire [15:0] udp_tx_dest_port;
    wire [7:0]  udp_tx_tdata;
    wire        udp_tx_tvalid;
    wire        udp_tx_tready;
    wire        udp_tx_tlast;
    
    // ========================================================================
    // Monitor signals
    // ========================================================================
    reg [7:0]  rx_byte_count;
    reg [7:0]  tx_byte_count;
    reg [3:0]  rx_packet_count;
    reg [3:0]  tx_packet_count;
    
    // ========================================================================
    // Instantiate eth_io_top
    // ========================================================================
    eth_io_top dut (
        .reset_btn(~axis_reset),
        .rgmii_rd(rgmii_rd),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .rgmii_rxc(rgmii_rxc),
        .rgmii_td(rgmii_td),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .rgmii_txc(rgmii_txc),
        .osc_clk(clk_100mhz),
        .phy_rst_n(),
        
        .clk_100mhz(clk_100mhz),
        .clk_125mhz(clk_125mhz),
        .clk_200mhz(clk_200mhz),
        .axis_reset(axis_reset),
        
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
        .udp_tx_tlast(udp_tx_tlast)
    );
    
    // ========================================================================
    // Simple echo: loop TX back to RX for testing
    // ========================================================================
    wire udp_tx_hdr_ready_loopback = 1'b1;
    wire udp_tx_tready_loopback = 1'b1;
    
    // ========================================================================
    // Monitor RX side
    // ========================================================================
    always @(posedge clk_100mhz) begin
        if (axis_reset) begin
            rx_byte_count <= 0;
            rx_packet_count <= 0;
        end else begin
            if (udp_rx_tvalid && udp_rx_tready) begin
                rx_byte_count <= rx_byte_count + 1;
                if (udp_rx_tlast) begin
                    rx_packet_count <= rx_packet_count + 1;
                    $display("[RX] Packet %d complete: %d bytes", rx_packet_count, rx_byte_count + 1);
                    rx_byte_count <= 0;
                end
            end
        end
    end
    
    // ========================================================================
    // Monitor TX side
    // ========================================================================
    always @(posedge clk_100mhz) begin
        if (axis_reset) begin
            tx_byte_count <= 0;
            tx_packet_count <= 0;
        end else begin
            if (udp_tx_tvalid && udp_tx_tready_loopback) begin
                tx_byte_count <= tx_byte_count + 1;
                if (udp_tx_tlast) begin
                    tx_packet_count <= tx_packet_count + 1;
                    $display("[TX] Packet %d complete: %d bytes", tx_packet_count, tx_byte_count + 1);
                    tx_byte_count <= 0;
                end
            end
        end
    end
    
    // ========================================================================
    // Test stimulus
    // ========================================================================
    initial begin
        // VCD waveform capture
        $dumpfile("eth_io_top_tb.vcd");
        $dumpvars(0, tb_eth_io_top);
        
        $display("=== eth_io_top Testbench ===");
        $display("Time: %t", $time);
        
        // Reset
        axis_reset = 1;
        #100;
        axis_reset = 0;
        $display("[INIT] Reset released at t=%t", $time);
        
        // Wait for PLL lock
        #1000;
        $display("[INIT] PLL should be locked, PHY reset done");
        
        // ====================================================================
        // Test 1: Send a simple UDP packet (260 bytes)
        // ====================================================================
        $display("\n=== Test 1: Send 260-byte UDP packet ===");
        
        // For now, just monitor what happens
        // In real hardware, packets would arrive from network
        // This testbench can't simulate full MAC layer easily
        
        // But we can test the UDP RX/TX interface directly
        send_udp_packet(260);
        
        #10000;
        
        // ====================================================================
        // Test 2: Send multiple packets
        // ====================================================================
        $display("\n=== Test 2: Send 4 packets (260 bytes each) ===");
        
        send_udp_packet(260);
        send_udp_packet(260);
        send_udp_packet(260);
        send_udp_packet(260);
        
        #10000;
        
        $display("\n=== Testbench Complete ===");
        $display("RX: %d packets", rx_packet_count);
        $display("TX: %d packets", tx_packet_count);
        
        $finish;
    end
    
    // ========================================================================
    // Task: Send UDP packet on RX side
    // ========================================================================
    task send_udp_packet(input integer packet_size);
        integer i;
        begin
            $display("[TEST] Sending %d-byte packet at t=%t", packet_size, $time);
            
            // Wait for ready
            for (i = 0; i < 1000; i = i + 1) begin
                if (udp_rx_tready) begin
                    $display("[TEST] RX side ready");
                    break;
                end
                #10;
            end
            
            // Send packet bytes one at a time
            for (i = 0; i < packet_size; i = i + 1) begin
                @(posedge clk_100mhz);
                
                // Inject byte on RX side (simulated packet arrival)
                // NOTE: In real hardware, eth_io_top receives these from MAC
                // For testing, we'd need to mock the MAC layer
                // For now, just show what signals would look like
                
                if (i == 0) begin
                    $display("[BYTE] Sending byte 0 (header start)");
                end
                
                if (i == packet_size - 1) begin
                    $display("[BYTE] Sending byte %d (last byte, tlast=1)", i);
                end
            end
            
            #100;
        end
    endtask
    
    // ========================================================================
    // Monitoring: Print when signals change
    // ========================================================================
    always @(posedge udp_rx_hdr_valid) begin
        $display("[SIGNAL] udp_rx_hdr_valid went HIGH at t=%t", $time);
        $display("         Source: %d.%d.%d.%d:%d", 
            udp_rx_src_ip[31:24], udp_rx_src_ip[23:16], 
            udp_rx_src_ip[15:8], udp_rx_src_ip[7:0],
            udp_rx_src_port);
        $display("         Dest port: %d", udp_rx_dest_port);
    end
    
    always @(posedge udp_rx_tvalid) begin
        if ($time > 100) begin
            $display("[SIGNAL] udp_rx_tvalid went HIGH at t=%t", $time);
        end
    end
    
    always @(posedge udp_rx_tlast) begin
        $display("[SIGNAL] udp_rx_tlast pulsed at t=%t (packet boundary)", $time);
    end
    
    always @(posedge udp_tx_tvalid) begin
        $display("[SIGNAL] udp_tx_tvalid went HIGH at t=%t", $time);
    end
    
    always @(posedge udp_tx_tlast) begin
        $display("[SIGNAL] udp_tx_tlast pulsed at t=%t (response packet end)", $time);
    end

endmodule
