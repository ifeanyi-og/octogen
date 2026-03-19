`timescale 1ns / 1ps

// =============================================================================
// Module: app_packet_rx
// Description:
//   Parse incoming UDP payloads, validate application header,
//   and extract real int32 samples.
//
// New packet format:
//   Bytes [3:0]      - Application header (32-bit)
//                      [31:24] wakeup   = 0xFF
//                      [23:16] wakeup   = 0xFF
//                      [15:14] batch_id = 0..3
//                      [13:10] reserved = 0
//                      [9:0]   row_id
//
//   Bytes [1027:4]   - 1024 payload bytes = 256 real samples
//                      Each sample: int32, little-endian
//
// Notes:
//   - 4 packets per row => 1024 real samples per row total
//   - batch_valid pulses at the end of each valid batch/packet
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
    output reg  [31:0] sample_data,
    output reg         sample_valid,
    output reg         sample_last,

    // Error / status
    output reg         hdr_error
);

    localparam ST_HDR   = 2'd0;
    localparam ST_SAMP  = 2'd1;
    localparam ST_ERROR = 2'd2;

    localparam SAMPLES_PER_BATCH = 256;

    reg [1:0]  state;

    reg [1:0]  hdr_byte_cnt;
    reg [31:0] hdr_shift;

    reg [1:0]  byte_in_word;     // 0..3 within one int32 sample
    reg [7:0]  sample_cnt;       // 0..255 within one batch
    reg [31:0] sample_shift;

    assign udp_rx_tready = 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= ST_HDR;
            hdr_byte_cnt <= 2'd0;
            hdr_shift    <= 32'd0;

            byte_in_word <= 2'd0;
            sample_cnt   <= 8'd0;
            sample_shift <= 32'd0;

            batch_valid  <= 1'b0;
            batch_row_id <= 10'd0;
            batch_id     <= 2'd0;

            sample_data  <= 32'd0;
            sample_valid <= 1'b0;
            sample_last  <= 1'b0;

            hdr_error    <= 1'b0;
        end else begin
            batch_valid  <= 1'b0;
            sample_valid <= 1'b0;
            sample_last  <= 1'b0;
            hdr_error    <= 1'b0;

            if (udp_rx_tvalid) begin
                case (state)

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

                                if ((hdr_shift[23:16] == 8'hFF) &&
                                    (udp_rx_tdata      == 8'hFF)) begin
                                    batch_id     <= hdr_shift[15:14];
                                    batch_row_id <= hdr_shift[9:0];

                                    byte_in_word <= 2'd0;
                                    sample_cnt   <= 8'd0;
                                    state        <= ST_SAMP;
                                end else begin
                                    hdr_error    <= 1'b1;
                                    state        <= ST_ERROR;
                                end

                                hdr_byte_cnt <= 2'd0;
                            end
                        endcase

                        if (udp_rx_tlast) begin
                            state        <= ST_HDR;
                            hdr_byte_cnt <= 2'd0;
                        end
                    end

                    ST_SAMP: begin
                        case (byte_in_word)
                            2'd0: sample_shift[7:0]   <= udp_rx_tdata;
                            2'd1: sample_shift[15:8]  <= udp_rx_tdata;
                            2'd2: sample_shift[23:16] <= udp_rx_tdata;
                            2'd3: sample_shift[31:24] <= udp_rx_tdata;
                        endcase

                        if (byte_in_word == 2'd3) begin
                            sample_data  <= {udp_rx_tdata, sample_shift[23:0]};
                            sample_valid <= 1'b1;
                            byte_in_word <= 2'd0;

                            if (sample_cnt == SAMPLES_PER_BATCH-1) begin
                                sample_last <= 1'b1;
                                batch_valid <= 1'b1;
                                sample_cnt  <= 8'd0;
                                state       <= ST_HDR;
                                hdr_byte_cnt <= 2'd0;
                            end else begin
                                sample_cnt <= sample_cnt + 8'd1;
                            end
                        end else begin
                            byte_in_word <= byte_in_word + 2'd1;

                            if (udp_rx_tlast) begin
                                state        <= ST_HDR;
                                hdr_byte_cnt <= 2'd0;
                                byte_in_word <= 2'd0;
                                sample_cnt   <= 8'd0;
                            end
                        end
                    end

                    ST_ERROR: begin
                        if (udp_rx_tlast) begin
                            state        <= ST_HDR;
                            hdr_byte_cnt <= 2'd0;
                            byte_in_word <= 2'd0;
                            sample_cnt   <= 8'd0;
                        end
                    end

                    default: begin
                        state        <= ST_HDR;
                        hdr_byte_cnt <= 2'd0;
                        byte_in_word <= 2'd0;
                        sample_cnt   <= 8'd0;
                    end
                endcase
            end
        end
    end

endmodule

