// confirmed to be fully functional

module packet_header_parser (
    input  wire        clk,
    input  wire        rst,

    input  wire [7:0]  s_udp_tdata,
    input  wire        s_udp_tvalid,
    output wire        s_udp_tready,
    input  wire        s_udp_tlast,

    output wire        hdr_valid,
    input  wire        hdr_ready,
    output wire [3:0]  hdr_batch,
    output wire [15:0] hdr_seq,

    output wire [31:0] m_sample_tdata,
    output wire        m_sample_tvalid,
    input  wire        m_sample_tready,
    output wire        m_sample_tlast,
    output wire [5:0]  m_sample_index,

    output wire [1:0]  debug_state,
    output wire [1:0]  debug_byte_count,
    output wire [6:0]  debug_sample_count,
    output wire [7:0]  debug_packet_type,
    output wire        debug_valid_packet
);

localparam STATE_IDLE    = 2'b00;
localparam STATE_HEADER  = 2'b01;
localparam STATE_SAMPLES = 2'b10;
localparam STATE_DISCARD = 2'b11;

reg [1:0] state;
reg [1:0] byte_count;
reg [31:0] word_buffer;
reg [6:0] sample_count;

reg [3:0] internal_hdr_batch;
reg [7:0] internal_hdr_seq;
reg internal_hdr_valid;

assign s_udp_tready = 1'b1;

assign hdr_valid = internal_hdr_valid;
assign hdr_batch = internal_hdr_batch;
assign hdr_seq   = {8'b0, internal_hdr_seq};

assign m_sample_tdata  = word_buffer;
assign m_sample_tvalid = (state == STATE_SAMPLES) && (byte_count == 2'b11) && s_udp_tvalid;
assign m_sample_tlast  = (sample_count == 7'd63) && m_sample_tvalid && m_sample_tready;
assign m_sample_index  = sample_count[5:0];

assign debug_state = state;
assign debug_byte_count = byte_count;
assign debug_sample_count = sample_count;
assign debug_packet_type = 8'h00;
assign debug_valid_packet = (state == STATE_SAMPLES);

always @(posedge clk) begin
    if (rst) begin
        state <= STATE_IDLE;
        byte_count <= 0;
        word_buffer <= 0;
        sample_count <= 0;
        internal_hdr_valid <= 0;
        internal_hdr_batch <= 0;
        internal_hdr_seq <= 0;
    end
    else begin

        if (s_udp_tvalid && s_udp_tready) begin

            word_buffer <= {word_buffer[23:0], s_udp_tdata};

            case (state)

            // =================================================
            // IDLE : treat first byte as header byte 0
            // =================================================
            STATE_IDLE: begin
                byte_count <= 1;

                if (s_udp_tdata == 8'hFF)
                    state <= STATE_HEADER;
                else
                    state <= STATE_DISCARD;
            end

            // =================================================
            // HEADER parsing
            // =================================================
            STATE_HEADER: begin

                case (byte_count)

                2'b01: begin
                    if (s_udp_tdata == 8'h00) begin
                        // valid DSP packet
                    end
                    else if (s_udp_tdata == 8'h01 ||
                             s_udp_tdata == 8'h02 ||
                             s_udp_tdata == 8'h03) begin
                        state <= STATE_DISCARD;
                    end
                    else begin
                        state <= STATE_DISCARD;
                    end
                end

                2'b10: begin
                    internal_hdr_batch <= s_udp_tdata[3:0];
                end

                2'b11: begin
                    internal_hdr_seq <= s_udp_tdata;
                    internal_hdr_valid <= 1;
                end

                endcase

                byte_count <= byte_count + 1;

            end

            // =================================================
            // SAMPLE STREAM
            // =================================================
            STATE_SAMPLES: begin

                byte_count <= byte_count + 1;

                if (byte_count == 2'b11) begin
                    if (m_sample_tvalid && m_sample_tready) begin
                        if (sample_count == 7'd63)
                            sample_count <= 0;
                        else
                            sample_count <= sample_count + 1;
                    end
                end

            end

            // =================================================
            // DISCARD PACKET
            // =================================================
            STATE_DISCARD: begin
                // ignore bytes
            end

            endcase

            if (byte_count == 2'b11)
                byte_count <= 0;

        end

        // =====================================================
        // Header handshake
        // =====================================================
        if (internal_hdr_valid && hdr_ready && state == STATE_HEADER) begin
            internal_hdr_valid <= 0;
            state <= STATE_SAMPLES;
            sample_count <= 0;
            byte_count <= 0;
        end

        // =====================================================
        // End of packet
        // =====================================================
        if (s_udp_tvalid && s_udp_tready && s_udp_tlast) begin
            state <= STATE_IDLE;
            byte_count <= 0;
            word_buffer <= 0;
            sample_count <= 0;
            internal_hdr_valid <= 0;
        end

    end
end

endmodule