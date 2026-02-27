
module packet_header_parser (
    input  wire        clk,
    input  wire        rst,

    // UDP RX input (AXIS, byte stream)
    input  wire [7:0]  s_udp_tdata,
    input  wire        s_udp_tvalid,
    output wire        s_udp_tready,
    input  wire        s_udp_tlast,

    // Header output
    output reg         hdr_valid,
    input  wire        hdr_ready,
    output reg  [31:0] hdr_type,        // #FFFF0000 or #FFFF0001

    // Real/Imaginary sample outputs (32-bit each)
    // Note: First 512 samples are real, next 512 are imaginary
    output wire [31:0] m_real_tdata,    // 512 x 32-bit real samples
    output wire        m_real_tvalid,
    input  wire        m_real_tready,
    output wire        m_real_tlast,    // Last real sample
    output wire [9:0]  m_real_count,    // 0-511

    output wire [31:0] m_imag_tdata,    // 512 x 32-bit imaginary samples
    output wire        m_imag_tvalid,
    input  wire        m_imag_tready,
    output wire        m_imag_tlast,    // Last imaginary sample
    output wire [9:0]  m_imag_count     // 0-511
);

    // ========================================================================
    // Byte buffering into 32-bit words
    // ========================================================================
    reg [1:0]  byte_ptr;
    reg [31:0] word_buffer;

    wire [31:0] assembled_word = {word_buffer[23:0], s_udp_tdata};  // Big-endian

    // ========================================================================
    // State machine: HEADER -> REAL_SAMPLES -> IMAG_SAMPLES -> IDLE
    // ========================================================================
    localparam STATE_IDLE        = 3'b000;
    localparam STATE_HEADER      = 3'b001;
    localparam STATE_REAL        = 3'b010;
    localparam STATE_IMAG        = 3'b011;

    reg [2:0]  state, next_state;
    reg [9:0]  sample_count;              // 0-511 for reals or imags

    // ========================================================================
    // Output assignments
    // ========================================================================
    assign m_real_tdata = word_buffer;
    assign m_real_tvalid = (state == STATE_REAL) && s_udp_tvalid && (byte_ptr == 2'b11);
    assign m_real_tlast = (sample_count == 10'd511) && m_real_tvalid && m_real_tready;
    assign m_real_count = sample_count;

    assign m_imag_tdata = word_buffer;
    assign m_imag_tvalid = (state == STATE_IMAG) && s_udp_tvalid && (byte_ptr == 2'b11);
    assign m_imag_tlast = (sample_count == 10'd511) && m_imag_tvalid && m_imag_tready;
    assign m_imag_count = sample_count;

    assign s_udp_tready = ((state == STATE_HEADER) || 
                           (state == STATE_REAL && m_real_tready) ||
                           (state == STATE_IMAG && m_imag_tready));

    // ========================================================================
    // Main state machine logic
    // ========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            byte_ptr <= 0;
            word_buffer <= 0;
            sample_count <= 0;
            hdr_valid <= 0;
            hdr_type <= 0;
        end else begin
            state <= next_state;

            // Accumulate bytes into 32-bit word (big-endian)
            if (s_udp_tvalid && s_udp_tready) begin
                word_buffer <= assembled_word;
                byte_ptr <= byte_ptr + 1;

                // When we complete a 32-bit word
                if (byte_ptr == 2'b11) begin
                    if (state == STATE_HEADER) begin
                        hdr_valid <= 1;
                        hdr_type <= assembled_word;
                    end else if ((state == STATE_REAL || state == STATE_IMAG) && m_real_tready && m_imag_tready) begin
                        // Only advance if output is ready
                        if (sample_count == 10'd511) begin
                            sample_count <= 0;
                        end else begin
                            sample_count <= sample_count + 1;
                        end
                    end
                    byte_ptr <= 0;
                end
            end

            // Clear header valid once consumed
            if (hdr_valid && hdr_ready) begin
                hdr_valid <= 0;
            end

            // End of packet
            if (s_udp_tlast && s_udp_tvalid && s_udp_tready) begin
                state <= STATE_IDLE;
                sample_count <= 0;
                byte_ptr <= 0;
            end
        end
    end

    // ========================================================================
    // Next state logic
    // ========================================================================
    always @(*) begin
        next_state = state;

        case (state)
            STATE_IDLE: begin
                // Wait for first byte to arrive
                if (s_udp_tvalid) begin
                    next_state = STATE_HEADER;
                end
            end

            STATE_HEADER: begin
                // Stay until header is consumed
                if (hdr_valid && hdr_ready) begin
                    next_state = STATE_REAL;
                end
            end

            STATE_REAL: begin
                // Process 512 real samples, then move to imaginary
                if ((sample_count == 10'd511) && (byte_ptr == 2'b11) && s_udp_tvalid && m_real_tready) begin
                    next_state = STATE_IMAG;
                end
            end

            STATE_IMAG: begin
                // Process 512 imaginary samples
                // At end of packet, return to idle
                if (s_udp_tlast && s_udp_tvalid && m_imag_tready) begin
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end

endmodule

