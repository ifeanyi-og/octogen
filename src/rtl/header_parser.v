
module packet_header_parser (
    input  wire        clk,
    input  wire        rst,

    // UDP RX input (AXIS byte stream)
    input  wire [7:0]  s_udp_tdata,
    input  wire        s_udp_tvalid,
    output wire        s_udp_tready,
    input  wire        s_udp_tlast,

    // Header outputs (for DSP control)
    output wire        hdr_valid,
    input  wire        hdr_ready,
    output wire [3:0]  hdr_type,
    output wire [3:0]  hdr_batch,
    output wire [23:0] hdr_seq,

    // Interleaved complex sample outputs
    output wire [31:0] m_sample_tdata,
    output wire        m_sample_tvalid,
    input  wire        m_sample_tready,
    output wire        m_sample_tlast,
    output wire [5:0]  m_sample_index,
    
    // DEBUG: FSM state and counters
    output wire [1:0]  debug_state,
    output wire [1:0]  debug_byte_count,
    output wire [6:0]  debug_sample_count,
    output wire [7:0]  debug_assembled_header_byte0
);

    // ========================================================================
    // State Machine
    // ========================================================================
    localparam STATE_IDLE        = 2'b00;
    localparam STATE_HEADER      = 2'b01;
    localparam STATE_SAMPLES     = 2'b10;

    reg [1:0]  state;
    reg [1:0]  byte_count;
    reg [31:0] word_buffer;
    reg [6:0]  sample_count;
    reg [31:0] assembled_header;
    reg        header_consumed;
    
    reg [3:0]  internal_hdr_type;
    reg [3:0]  internal_hdr_batch;
    reg [23:0] internal_hdr_seq;
    reg        internal_hdr_valid;

    // ========================================================================
    // Construct header word combinatorially (avoid race)
    // ========================================================================
    wire [31:0] header_word = {word_buffer[23:0], s_udp_tdata};

    // ========================================================================
    // Output Logic - CORRECT AXIS-STREAM BEHAVIOR
    // ========================================================================
    assign m_sample_tdata = word_buffer;
    
    // tvalid must NEVER depend on tready
    // Assert valid when we have a complete 32-bit word in the sample state
    assign m_sample_tvalid = (byte_count == 2'b11) && s_udp_tvalid && (state == STATE_SAMPLES);
    
    // tlast asserts when last sample is transferred (both tvalid AND tready)
    assign m_sample_tlast = (sample_count == 7'd63) && m_sample_tvalid && m_sample_tready;
    
    assign m_sample_index = sample_count[5:0];
    assign s_udp_tready = 1'b1;  // Always ready to accept bytes
    
    // Header outputs
    assign hdr_valid = internal_hdr_valid;
    assign hdr_type = internal_hdr_type;
    assign hdr_batch = internal_hdr_batch;
    assign hdr_seq = internal_hdr_seq;
    
    // DEBUG outputs
    assign debug_state = state;
    assign debug_byte_count = byte_count;
    assign debug_sample_count = sample_count;
    assign debug_assembled_header_byte0 = assembled_header[31:24];

    // ========================================================================
    // FSM: Proper AXI-Stream handshake behavior
    // ========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            byte_count <= 0;
            word_buffer <= 0;
            sample_count <= 0;
            internal_hdr_valid <= 0;
            header_consumed <= 0;
            assembled_header <= 0;
            internal_hdr_type <= 0;
            internal_hdr_batch <= 0;
            internal_hdr_seq <= 0;
        end else begin
            
            // ====== RESET on packet boundaries ======
            if (s_udp_tlast && s_udp_tvalid && s_udp_tready) begin
                byte_count <= 0;
                word_buffer <= 0;
            end
            
            // ====== Header handshake ======
            if (state == STATE_HEADER && byte_count == 2'b11 && s_udp_tvalid) begin
                assembled_header <= header_word;
                internal_hdr_type <= header_word[31:28];
                internal_hdr_batch <= header_word[27:24];
                internal_hdr_seq <= header_word[23:0];
                internal_hdr_valid <= 1;
            end
            
            if (internal_hdr_valid && hdr_ready) begin
                internal_hdr_valid <= 0;
                header_consumed <= 1;
                byte_count <= 0;
            end

            // ====== Byte-level processing ======
            if (s_udp_tvalid && s_udp_tready) begin
                word_buffer <= {word_buffer[23:0], s_udp_tdata};
                
                if (byte_count == 2'b11) begin
                    // We have a complete 32-bit word
                    
                    if (state == STATE_SAMPLES) begin
                        // CORRECT: Increment on HANDSHAKE (tvalid AND tready)
                        // NOT just when tready is high
                        if (m_sample_tvalid && m_sample_tready) begin
                            if (sample_count == 7'd63) begin
                                sample_count <= 0;
                            end else begin
                                sample_count <= sample_count + 1;
                            end
                        end
                    end
                    
                    byte_count <= 0;
                end else begin
                    byte_count <= byte_count + 1;
                end
            end

            // ====== State transitions ======
            case (state)
                STATE_IDLE: begin
                    if (s_udp_tvalid) begin
                        state <= STATE_HEADER;
                        byte_count <= 0;
                        word_buffer <= 0;
                        sample_count <= 0;
                    end
                end

                STATE_HEADER: begin
                    if (header_consumed && (byte_count == 2'b00)) begin
                        state <= STATE_SAMPLES;
                        sample_count <= 0;
                        header_consumed <= 0;
                    end
                end

                STATE_SAMPLES: begin
                    // Exit when we've output 64 samples (handshake required)
                    if ((sample_count == 7'd63) && m_sample_tvalid && m_sample_tready) begin
                        state <= STATE_IDLE;
                        sample_count <= 0;
                        byte_count <= 0;
                    end
                end

                default: state <= STATE_IDLE;
            endcase

        end
    end

endmodule

