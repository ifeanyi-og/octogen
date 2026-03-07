
/*
 * udp_processing_top.v
 * 
 * Complete pipeline:
 * UDP RX → Parser → DSP (passthrough) → sample_to_byte → UDP TX
 * 
 * CRITICAL FIXES:
 * - hdr_valid is PULSE, not level (strobed directly from parser)
 * - Destination port filter to port 5001
 * - Proper header storage and routing
 */

module udp_processing_top (
    input  wire        clk,
    input  wire        rst,

    // UDP RX from ethernet_io_top
    input  wire        udp_rx_hdr_valid,
    output wire        udp_rx_hdr_ready,
    input  wire [31:0] udp_rx_src_ip,
    input  wire [15:0] udp_rx_src_port,
    input  wire [15:0] udp_rx_dest_port,
    input  wire [7:0]  udp_rx_tdata,
    input  wire        udp_rx_tvalid,
    output wire        udp_rx_tready,
    input  wire        udp_rx_tlast,

    // UDP TX to ethernet_io_top
    output wire        udp_tx_hdr_valid,
    input  wire        udp_tx_hdr_ready,
    output wire [31:0] udp_tx_dest_ip,
    output wire [15:0] udp_tx_src_port,
    output wire [15:0] udp_tx_dest_port,
    output wire [7:0]  udp_tx_tdata,
    output wire        udp_tx_tvalid,
    input  wire        udp_tx_tready,
    output wire        udp_tx_tlast,
    
    // DEBUG outputs
    output wire [1:0]  debug_parser_state,
    output wire [1:0]  debug_parser_byte_count,
    output wire [6:0]  debug_parser_sample_count,
    output wire [7:0]  debug_parser_packet_type,
    output wire        debug_parser_valid_packet,
    output wire        debug_parser_hdr_valid,
    output wire        debug_parser_sample_tvalid,
    output wire        debug_parser_sample_tready,
    output wire [1:0]  debug_s2b_byte_ptr,
    output wire [31:0] debug_s2b_sample_hold,
    output wire        debug_udp_tx_tvalid,
    output wire        debug_udp_tx_tlast,
    output wire [31:0] debug_stored_src_ip,
    output wire [15:0] debug_stored_src_port,
    output wire [15:0] debug_stored_dest_port
);

    // ========================================================================
    // INTERNAL WIRES - Parser
    // ========================================================================
    wire        parser_hdr_valid;
    wire        parser_hdr_ready;
    wire [3:0]  parser_hdr_batch;
    wire [15:0] parser_hdr_seq;

    wire [31:0] parser_sample_tdata;
    wire        parser_sample_tvalid;
    wire        parser_sample_tready;
    wire        parser_sample_tlast;
    wire [5:0]  parser_sample_index;
    
    wire [1:0]  parser_debug_state;
    wire [1:0]  parser_debug_byte_count;
    wire [6:0]  parser_debug_sample_count;
    wire [7:0]  parser_debug_packet_type;
    wire        parser_debug_valid_packet;

    // ========================================================================
    // INTERNAL WIRES - DSP Chain (placeholder)
    // ========================================================================
    wire [31:0] dsp_output_tdata;
    wire        dsp_output_tvalid;
    wire        dsp_output_tready;
    wire        dsp_output_tlast;

    // ========================================================================
    // INTERNAL WIRES - sample_to_byte
    // ========================================================================
    wire [7:0]  s2b_axis_tdata;
    wire        s2b_axis_tvalid;
    wire        s2b_axis_tready;
    wire        s2b_axis_tlast;
    
    // wire [1:0]  s2b_debug_byte_ptr;
    // wire [31:0] s2b_debug_sample_hold;

    // ========================================================================
    // INTERNAL WIRES - Response routing
    // ========================================================================
    reg [31:0] stored_src_ip;
    reg [15:0] stored_src_port;
    reg [15:0] stored_dest_port;

    // ========================================================================
    // Filter by destination port before parsing
    // ========================================================================
    wire valid_dest_port = (udp_rx_dest_port == 16'd5001);

    // ========================================================================
    // STAGE 1: Parse packet header with validation
    // ========================================================================
    packet_header_parser hdr_parser (
        .clk(clk),
        .rst(rst),
        .s_udp_tdata(udp_rx_tdata),
        .s_udp_tvalid(udp_rx_tvalid && valid_dest_port),  // Filter by port
        .s_udp_tready(udp_rx_tready),
        .s_udp_tlast(udp_rx_tlast),
        .hdr_valid(parser_hdr_valid),
        .hdr_ready(parser_hdr_ready),
        .hdr_batch(parser_hdr_batch),
        .hdr_seq(parser_hdr_seq),
        .m_sample_tdata(parser_sample_tdata),
        .m_sample_tvalid(parser_sample_tvalid),
        .m_sample_tready(parser_sample_tready),
        .m_sample_tlast(parser_sample_tlast),
        .m_sample_index(parser_sample_index),
        .debug_state(parser_debug_state),
        .debug_byte_count(parser_debug_byte_count),
        .debug_sample_count(parser_debug_sample_count),
        .debug_packet_type(parser_debug_packet_type),
        .debug_valid_packet(parser_debug_valid_packet)
    );

    // ========================================================================
    // STAGE 2: Store header info for response routing
    // ========================================================================
    assign parser_hdr_ready = 1'b1;
    assign udp_rx_hdr_ready = 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            stored_src_ip <= 0;
            stored_src_port <= 0;
            stored_dest_port <= 0;
        end else if (udp_rx_hdr_valid && udp_rx_hdr_ready && valid_dest_port) begin
            stored_src_ip <= udp_rx_src_ip;
            stored_src_port <= udp_rx_src_port;
            stored_dest_port <= udp_rx_dest_port;
        end
    end

    // ========================================================================
    // STAGE 3: DSP Chain (PLACEHOLDER - passthrough)
    // ========================================================================
    assign parser_sample_tready = dsp_output_tready;
    assign dsp_output_tdata = parser_sample_tdata;
    assign dsp_output_tvalid = parser_sample_tvalid;
    assign dsp_output_tlast = parser_sample_tlast;

    // ========================================================================
    // STAGE 4: Convert samples back to byte stream (no flush needed)
    // ========================================================================
    sample_to_byte s2b (
        .clk(clk),
        .rst(rst),
        .s_sample_tdata(dsp_output_tdata),
        .s_sample_tvalid(dsp_output_tvalid),
        .s_sample_tready(dsp_output_tready),
        .s_sample_tlast(dsp_output_tlast),
        .m_axis_tdata(s2b_axis_tdata),
        .m_axis_tvalid(s2b_axis_tvalid),
        .m_axis_tready(s2b_axis_tready),
        .m_axis_tlast(s2b_axis_tlast)
        // .debug_byte_ptr(s2b_debug_byte_ptr),
        // .debug_sample_hold(s2b_debug_sample_hold)
    );

    // ========================================================================
    // STAGE 5: Format UDP TX response (no header, samples only)
    // FIXED: hdr_valid is a PULSE, not a level
    // ========================================================================
    
    // Header valid only when parser outputs it (pulse)
    assign udp_tx_hdr_valid = parser_hdr_valid;

    assign udp_tx_dest_ip = stored_src_ip;
    assign udp_tx_src_port = stored_dest_port;
    assign udp_tx_dest_port = stored_src_port;

    // Send only samples, no header
    assign udp_tx_tdata = s2b_axis_tdata;
    assign udp_tx_tvalid = s2b_axis_tvalid;
    assign s2b_axis_tready = udp_tx_tready;
    assign udp_tx_tlast = s2b_axis_tlast;

    // ========================================================================
    // DEBUG OUTPUT ASSIGNMENTS
    // ========================================================================
    assign debug_parser_state = parser_debug_state;
    assign debug_parser_byte_count = parser_debug_byte_count;
    assign debug_parser_sample_count = parser_debug_sample_count;
    assign debug_parser_packet_type = parser_debug_packet_type;
    assign debug_parser_valid_packet = parser_debug_valid_packet;
    assign debug_parser_hdr_valid = parser_hdr_valid;
    assign debug_parser_sample_tvalid = parser_sample_tvalid;
    assign debug_parser_sample_tready = parser_sample_tready;
    assign debug_s2b_byte_ptr = 2'b0; //s2b_debug_byte_ptr;
    assign debug_s2b_sample_hold = 32'b0; // s2b_debug_sample_hold;
    assign debug_udp_tx_tvalid = udp_tx_tvalid;
    assign debug_udp_tx_tlast = udp_tx_tlast;
    assign debug_stored_src_ip = stored_src_ip;
    assign debug_stored_src_port = stored_src_port;
    assign debug_stored_dest_port = stored_dest_port;

endmodule
