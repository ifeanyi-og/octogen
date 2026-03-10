// a few smart guys think this works

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
reg       internal_hdr_valid;

reg [7:0] packet_type;

// Registered output sample buffer
reg [31:0] out_sample_data;
reg        out_sample_valid;
reg        out_sample_last;
reg [5:0]  out_sample_index;

// Marks that the packet ended on the 4th byte of a completed sample word.
// We wait until that buffered sample is accepted before resetting to IDLE.
reg pending_eop_after_sample;

// Stall input whenever a header is waiting to be accepted
// or a completed sample word is waiting to be accepted.
assign s_udp_tready = !rst && !internal_hdr_valid && !out_sample_valid;

assign hdr_valid = internal_hdr_valid;
assign hdr_batch = internal_hdr_batch;
assign hdr_seq   = {8'b0, internal_hdr_seq};

assign m_sample_tdata  = out_sample_data;
assign m_sample_tvalid = out_sample_valid;
assign m_sample_tlast  = out_sample_last;
assign m_sample_index  = out_sample_index;

assign debug_state        = state;
assign debug_byte_count   = byte_count;
assign debug_sample_count = sample_count;
assign debug_packet_type  = packet_type;
assign debug_valid_packet = (state == STATE_SAMPLES) || internal_hdr_valid;

always @(posedge clk) begin
    if (rst) begin
        state <= STATE_IDLE;
        byte_count <= 2'b00;
        word_buffer <= 32'b0;
        sample_count <= 7'd0;

        internal_hdr_batch <= 4'b0;
        internal_hdr_seq <= 8'b0;
        internal_hdr_valid <= 1'b0;

        packet_type <= 8'h00;

        out_sample_data <= 32'b0;
        out_sample_valid <= 1'b0;
        out_sample_last <= 1'b0;
        out_sample_index <= 6'd0;

        pending_eop_after_sample <= 1'b0;
    end
    else begin
        // -----------------------------------------------------
        // Header handshake
        // -----------------------------------------------------
        if (internal_hdr_valid && hdr_ready) begin
            internal_hdr_valid <= 1'b0;
            state <= STATE_SAMPLES;
            byte_count <= 2'b00;
            word_buffer <= 32'b0;   // critical fix: clear header residue
            sample_count <= 7'd0;
        end

        // -----------------------------------------------------
        // Sample output handshake
        // -----------------------------------------------------
        if (out_sample_valid && m_sample_tready) begin
            out_sample_valid <= 1'b0;

            if (pending_eop_after_sample) begin
                // Packet ended on the 4th byte of this sample word.
                state <= STATE_IDLE;
                byte_count <= 2'b00;
                word_buffer <= 32'b0;
                sample_count <= 7'd0;
                internal_hdr_valid <= 1'b0;
                pending_eop_after_sample <= 1'b0;
            end
            else begin
                if (sample_count == 7'd63)
                    sample_count <= 7'd0;
                else
                    sample_count <= sample_count + 7'd1;
            end
        end

        // -----------------------------------------------------
        // Input byte handshake
        // -----------------------------------------------------
        if (s_udp_tvalid && s_udp_tready) begin
            case (state)

                // =============================================
                // IDLE: first byte must be magic 0xFF
                // =============================================
                STATE_IDLE: begin
                    byte_count <= 2'b00;
                    word_buffer <= 32'b0;
                    sample_count <= 7'd0;
                    packet_type <= 8'h00;

                    if (s_udp_tdata == 8'hFF) begin
                        state <= STATE_HEADER;
                        byte_count <= 2'b01; // next byte is header byte 1
                    end
                    else begin
                        state <= STATE_DISCARD;
                    end

                    if (s_udp_tlast) begin
                        state <= STATE_IDLE;
                        byte_count <= 2'b00;
                        word_buffer <= 32'b0;
                        sample_count <= 7'd0;
                        internal_hdr_valid <= 1'b0;
                    end
                end

                // =============================================
                // HEADER bytes 1,2,3
                // =============================================
                STATE_HEADER: begin
                    case (byte_count)
                        2'b01: begin
                            packet_type <= s_udp_tdata;

                            if (s_udp_tdata == 8'h00) begin
                                byte_count <= 2'b10;
                            end
                            else begin
                                state <= STATE_DISCARD;
                                byte_count <= 2'b00;
                            end
                        end

                        2'b10: begin
                            internal_hdr_batch <= s_udp_tdata[3:0];
                            byte_count <= 2'b11;
                        end

                        2'b11: begin
                            internal_hdr_seq <= s_udp_tdata;
                            internal_hdr_valid <= 1'b1;
                            byte_count <= 2'b00;
                            // remain in STATE_HEADER until hdr_ready
                        end

                        default: begin
                            byte_count <= 2'b00;
                        end
                    endcase

                    // Truncated packet during header: reset immediately.
                    if (s_udp_tlast) begin
                        state <= STATE_IDLE;
                        byte_count <= 2'b00;
                        word_buffer <= 32'b0;
                        sample_count <= 7'd0;
                        internal_hdr_valid <= 1'b0;
                    end
                end

                // =============================================
                // SAMPLE STREAM: assemble 4 bytes into one word
                // =============================================
                STATE_SAMPLES: begin
                    if (byte_count == 2'b11) begin
                        // 4th byte completes a word
                        out_sample_data  <= {word_buffer[23:0], s_udp_tdata};
                        out_sample_valid <= 1'b1;
                        out_sample_index <= sample_count[5:0];
                        out_sample_last  <= (sample_count == 7'd63) || s_udp_tlast;

                        byte_count <= 2'b00;
                        word_buffer <= 32'b0;

                        if (s_udp_tlast)
                            pending_eop_after_sample <= 1'b1;
                    end
                    else begin
                        word_buffer <= {word_buffer[23:0], s_udp_tdata};
                        byte_count <= byte_count + 2'b01;

                        // Truncated packet in middle of a sample word: drop partial word and reset.
                        if (s_udp_tlast) begin
                            state <= STATE_IDLE;
                            byte_count <= 2'b00;
                            word_buffer <= 32'b0;
                            sample_count <= 7'd0;
                            internal_hdr_valid <= 1'b0;
                            pending_eop_after_sample <= 1'b0;
                        end
                    end
                end

                // =============================================
                // DISCARD until end of packet
                // =============================================
                STATE_DISCARD: begin
                    if (s_udp_tlast) begin
                        state <= STATE_IDLE;
                        byte_count <= 2'b00;
                        word_buffer <= 32'b0;
                        sample_count <= 7'd0;
                        internal_hdr_valid <= 1'b0;
                        pending_eop_after_sample <= 1'b0;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    byte_count <= 2'b00;
                    word_buffer <= 32'b0;
                    sample_count <= 7'd0;
                    internal_hdr_valid <= 1'b0;
                    out_sample_valid <= 1'b0;
                    pending_eop_after_sample <= 1'b0;
                end
            endcase
        end
    end
end

endmodule

