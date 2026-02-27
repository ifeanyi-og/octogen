
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
    output wire        udp_tx_tlast
);

    // ========================================================================
    // Stage 1: Parse incoming UDP packet into header + real/imag samples
    // ========================================================================
    wire        pkt_hdr_valid;
    wire        pkt_hdr_ready;
    wire [31:0] pkt_hdr_type;

    wire [31:0] parsed_real_tdata;
    wire        parsed_real_tvalid;
    wire        parsed_real_tready;
    wire        parsed_real_tlast;
    wire [9:0]  parsed_real_count;

    wire [31:0] parsed_imag_tdata;
    wire        parsed_imag_tvalid;
    wire        parsed_imag_tready;
    wire        parsed_imag_tlast;
    wire [9:0]  parsed_imag_count;

    packet_header_parser hdr_parser (
        .clk(clk),
        .rst(rst),
        .s_udp_tdata(udp_rx_tdata),
        .s_udp_tvalid(udp_rx_tvalid),
        .s_udp_tready(udp_rx_tready),
        .s_udp_tlast(udp_rx_tlast),
        .hdr_valid(pkt_hdr_valid),
        .hdr_ready(pkt_hdr_ready),
        .hdr_type(pkt_hdr_type),
        .m_real_tdata(parsed_real_tdata),
        .m_real_tvalid(parsed_real_tvalid),
        .m_real_tready(parsed_real_tready),
        .m_real_tlast(parsed_real_tlast),
        .m_real_count(parsed_real_count),
        .m_imag_tdata(parsed_imag_tdata),
        .m_imag_tvalid(parsed_imag_tvalid),
        .m_imag_tready(parsed_imag_tready),
        .m_imag_tlast(parsed_imag_tlast),
        .m_imag_count(parsed_imag_count)
    );

    // ========================================================================
    // Stage 2: Store header info (IP, port) for response
    // ========================================================================
    reg [31:0] stored_src_ip;
    reg [15:0] stored_src_port;
    reg [15:0] stored_dest_port;
    reg [31:0] stored_hdr_type;

    always @(posedge clk) begin
        if (rst) begin
            stored_src_ip <= 0;
            stored_src_port <= 0;
            stored_dest_port <= 0;
            stored_hdr_type <= 0;
        end else if (udp_rx_hdr_valid && udp_rx_hdr_ready) begin
            stored_src_ip <= udp_rx_src_ip;
            stored_src_port <= udp_rx_src_port;
            stored_dest_port <= udp_rx_dest_port;
        end else if (pkt_hdr_valid && pkt_hdr_ready) begin
            stored_hdr_type <= pkt_hdr_type;
        end
    end

    assign pkt_hdr_ready = 1'b1;  // Always ready to consume header

    // ========================================================================
    // Stage 3: DSP Chain (placeholder)
    // Process separate real and imaginary streams
    // ========================================================================
    wire [31:0] dsp_real_tdata;
    wire        dsp_real_tvalid;
    wire        dsp_real_tready;
    wire        dsp_real_tlast;

    wire [31:0] dsp_imag_tdata;
    wire        dsp_imag_tvalid;
    wire        dsp_imag_tready;
    wire        dsp_imag_tlast;

    // For now, pass through unchanged
    // TODO: Insert DSP chain:
    // parsed_real -> bg_sub -> k_lin -> FFT -> log_scale -> dsp_real
    // parsed_imag -> [same chain] -> dsp_imag
    
    assign dsp_real_tdata = parsed_real_tdata;
    assign dsp_real_tvalid = parsed_real_tvalid;
    assign parsed_real_tready = dsp_real_tready;
    assign dsp_real_tlast = parsed_real_tlast;

    assign dsp_imag_tdata = parsed_imag_tdata;
    assign dsp_imag_tvalid = parsed_imag_tvalid;
    assign parsed_imag_tready = dsp_imag_tready;
    assign dsp_imag_tlast = parsed_imag_tlast;

    // ========================================================================
    // Stage 4: Convert 32-bit real/imag samples back to byte stream
    // ========================================================================
    wire [7:0]  tx_byte_tdata;
    wire        tx_byte_tvalid;
    wire        tx_byte_tready;
    wire        tx_byte_tlast;

    sample_to_byte s2b (
        .clk(clk),
        .rst(rst),
        .s_real_tdata(dsp_real_tdata),
        .s_real_tvalid(dsp_real_tvalid),
        .s_real_tready(dsp_real_tready),
        .s_real_tlast(dsp_real_tlast),
        .s_imag_tdata(dsp_imag_tdata),
        .s_imag_tvalid(dsp_imag_tvalid),
        .s_imag_tready(dsp_imag_tready),
        .s_imag_tlast(dsp_imag_tlast),
        .m_axis_tdata(tx_byte_tdata),
        .m_axis_tvalid(tx_byte_tvalid),
        .m_axis_tready(tx_byte_tready),
        .m_axis_tlast(tx_byte_tlast)
    );

    // ========================================================================
    // Stage 5: Format UDP TX response
    // ========================================================================
    assign udp_tx_hdr_valid = pkt_hdr_valid;
    assign udp_tx_dest_ip = stored_src_ip;
    assign udp_tx_src_port = stored_dest_port;  // Swap source/dest ports
    assign udp_tx_dest_port = stored_src_port;

    assign udp_tx_tdata = tx_byte_tdata;
    assign udp_tx_tvalid = tx_byte_tvalid;
    assign tx_byte_tready = udp_tx_tready;
    assign udp_tx_tlast = tx_byte_tlast;

endmodule

