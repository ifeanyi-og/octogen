`timescale 1ns / 1ps

// =============================================================================
// Module: app_packet_rx
// Description: Parse incoming UDP payloads, validate application header,
//              and extract complex samples (Re/Im int32 pairs).
//
// Packet format:
//   Bytes [3:0]      - Application header (32-bit)
//                      [31:24] wakeup  = 0xFF
//                      [23:16] wakeup = 0x00
//                      [15:14] batch_id (0-3)
//                      [13:10] reserved
//                      [9:0]   row_id (0-767)
//   Bytes [1027:4]   - 1024 payload bytes = 128 complex samples
//                      Each sample: Re[31:0] Im[31:0] (little-endian int32)
// 
// 0b11111111 0b00000000 0b01xxxxxx0 0b00001001
// 0xFF        0x00   [00, 01, 10, 11]  
// =============================================================================


module app_packet_rx (
    input  wire        clk,
    input  wire        rst,

    // UDP RX byte stream
    input  wire [7:0]  udp_rx_tdata,
    input  wire        udp_rx_tvalid,
    output wire        udp_rx_tready,
    input  wire        udp_rx_tlast,

    // Batch metadata output (registered, valid one cycle)
    output reg         batch_valid,
    output reg  [9:0]  batch_row_id,
    output reg  [1:0]  batch_id,

    // Sample stream output
    output reg  [31:0] sample_re,
    output reg  [31:0] sample_im,
    output reg         sample_valid,
    output reg         sample_last,

    // Error / status
    output reg         hdr_error
);

    // -------------------------------------------------------------------------
    // State encoding
    // -------------------------------------------------------------------------
    localparam ST_HDR   = 2'd0;
    localparam ST_SAMP  = 2'd1;
    localparam ST_ERROR = 2'd2;

    reg [1:0]  state;

    // -------------------------------------------------------------------------
    // Internal registers
    // -------------------------------------------------------------------------
    reg [1:0]  hdr_byte_cnt;   // 0..3
    reg [31:0] hdr_shift;      // stores header bytes in final bit positions

    reg [2:0]  byte_in_word;   // 0..7 within one complex sample
    reg [6:0]  sample_cnt;     // 0..127 within one batch
    reg [31:0] re_shift;
    reg [31:0] im_shift;

    // -------------------------------------------------------------------------
    // Always ready in this version
    // -------------------------------------------------------------------------
    assign udp_rx_tready = 1'b1;

    // -------------------------------------------------------------------------
    // Main FSM
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= ST_HDR;
            hdr_byte_cnt <= 2'd0;
            hdr_shift    <= 32'd0;

            byte_in_word <= 3'd0;
            sample_cnt   <= 7'd0;
            re_shift     <= 32'd0;
            im_shift     <= 32'd0;

            batch_valid  <= 1'b0;
            batch_row_id <= 10'd0;
            batch_id     <= 2'd0;

            sample_re    <= 32'd0;
            sample_im    <= 32'd0;
            sample_valid <= 1'b0;
            sample_last  <= 1'b0;

            hdr_error    <= 1'b0;
        end else begin
            // Default pulse signals low
            batch_valid  <= 1'b0;
            sample_valid <= 1'b0;
            sample_last  <= 1'b0;
            hdr_error    <= 1'b0;

            if (udp_rx_tvalid) begin
                case (state)

                    // ----------------------------------------------------------
                    // HEADER: 4 bytes, LSB first on the wire
                    // ----------------------------------------------------------
                    ST_HDR: begin
                        case (hdr_byte_cnt)
                            2'd0: begin
                                hdr_shift[7:0] <= udp_rx_tdata;
                                hdr_byte_cnt   <= 2'd1;
                            end

                            2'd1: begin
                                hdr_shift[15:8] <= udp_rx_tdata;
                                hdr_byte_cnt    <= 2'd2;
                            end

                            2'd2: begin
                                hdr_shift[23:16] <= udp_rx_tdata;
                                hdr_byte_cnt     <= 2'd3;
                            end

                            2'd3: begin
                                hdr_shift[31:24] <= udp_rx_tdata;

                                // Validate magic bytes:
                                // byte2 is already in hdr_shift[23:16]
                                // current byte is byte3 -> should also be 0xFF
                                if ((hdr_shift[23:16] == 8'hFF) &&
                                    (udp_rx_tdata      == 8'hFF)) begin
                                    batch_id     <= hdr_shift[15:14];
                                    batch_row_id <= hdr_shift[9:0];

                                    byte_in_word <= 3'd0;
                                    sample_cnt   <= 7'd0;
                                    state        <= ST_SAMP;
                                end else begin
                                    hdr_error    <= 1'b1;
                                    state        <= ST_ERROR;
                                end

                                hdr_byte_cnt <= 2'd0;
                            end
                        endcase

                        // If packet ends during header, reset cleanly
                        if (udp_rx_tlast) begin
                            state        <= ST_HDR;
                            hdr_byte_cnt <= 2'd0;
                        end
                    end

                    // ----------------------------------------------------------
                    // PAYLOAD: 128 complex samples, each = Re[31:0], Im[31:0]
                    // little-endian byte order
                    // ----------------------------------------------------------
                    ST_SAMP: begin
                        case (byte_in_word)
                            3'd0: re_shift[7:0]    <= udp_rx_tdata;
                            3'd1: re_shift[15:8]   <= udp_rx_tdata;
                            3'd2: re_shift[23:16]  <= udp_rx_tdata;
                            3'd3: re_shift[31:24]  <= udp_rx_tdata;

                            3'd4: im_shift[7:0]    <= udp_rx_tdata;
                            3'd5: im_shift[15:8]   <= udp_rx_tdata;
                            3'd6: im_shift[23:16]  <= udp_rx_tdata;
                            3'd7: im_shift[31:24]  <= udp_rx_tdata;
                        endcase

                        if (byte_in_word == 3'd7) begin
                            // Complete complex sample now available
                            sample_re    <= re_shift;
                            sample_im    <= {udp_rx_tdata, im_shift[23:0]};
                            sample_valid <= 1'b1;
                            byte_in_word <= 3'd0;

                            if (sample_cnt == 7'd127) begin
                                sample_last <= 1'b1;
                                batch_valid <= 1'b1;
                                sample_cnt  <= 7'd0;
                                state       <= ST_HDR;
                                hdr_byte_cnt <= 2'd0;
                            end else begin
                                sample_cnt <= sample_cnt + 7'd1;
                            end
                        end else begin
                            byte_in_word <= byte_in_word + 3'd1;

                            // Early packet termination during payload:
                            // reset cleanly back to header state
                            if (udp_rx_tlast) begin
                                state        <= ST_HDR;
                                hdr_byte_cnt <= 2'd0;
                                byte_in_word <= 3'd0;
                                sample_cnt   <= 7'd0;
                            end
                        end
                    end

                    // ----------------------------------------------------------
                    // ERROR: drain until end of packet
                    // ----------------------------------------------------------
                    ST_ERROR: begin
                        if (udp_rx_tlast) begin
                            state        <= ST_HDR;
                            hdr_byte_cnt <= 2'd0;
                            byte_in_word <= 3'd0;
                            sample_cnt   <= 7'd0;
                        end
                    end

                    default: begin
                        state        <= ST_HDR;
                        hdr_byte_cnt <= 2'd0;
                        byte_in_word <= 3'd0;
                        sample_cnt   <= 7'd0;
                    end
                endcase
            end
        end
    end

endmodule



