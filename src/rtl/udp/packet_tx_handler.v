`timescale 1ns / 1ps
// =============================================================================
// Module: app_packet_tx
// Description:
//   Captures one full processed row of 512 complex samples and packetizes it
//   into 4 outgoing application packets.
//
// Packet format:
//   4-byte application header + 1024-byte payload
//
// Header word:
//   [31:24] = 8'hFF
//   [23:16] = 8'hFF
//   [15:14] = batch_id
//   [13:10] = 4'b0000
//   [9:0]   = row_id
//
// Header is transmitted LSB-first:
//   byte0 = header[7:0]
//   byte1 = header[15:8]
//   byte2 = header[23:16]
//   byte3 = header[31:24]
//
// Payload per packet:
//   128 complex samples
//   serialized as:
//      Re0[7:0], Re0[15:8], Re0[23:16], Re0[31:24],
//      Im0[7:0], Im0[15:8], Im0[23:16], Im0[31:24], ...
//
// Notes:
//   - This version captures a full row first, then transmits it.
//   - tx_tdata / tx_tvalid / tx_tlast are combinational from current indices.
//   - Counters advance only on handshake.
// =============================================================================

module app_packet_tx (
    input  wire        clk,
    input  wire        rst,

    // -------------------------------------------------------------------------
    // Input row stream
    // -------------------------------------------------------------------------
    input  wire        row_in_valid,
    output wire        row_in_ready,
    input  wire        row_in_start,
    input  wire [9:0]  row_in_row_id,
    input  wire [31:0] row_in_re,
    input  wire [31:0] row_in_im,

    // -------------------------------------------------------------------------
    // Packetized byte stream output
    // -------------------------------------------------------------------------
    output wire [7:0]  tx_tdata,
    output wire        tx_tvalid,
    input  wire        tx_tready,
    output wire        tx_tlast,

    // -------------------------------------------------------------------------
    // Packet metadata / event outputs
    // -------------------------------------------------------------------------
    output reg         pkt_start,      // pulse on first byte handshake of packet
    output reg  [1:0]  pkt_batch_id,   // current packet batch
    output reg  [9:0]  pkt_row_id,     // current row id
    output reg         row_done        // pulse on final byte handshake of row
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam ROW_SAMPLES         = 512;
    localparam BATCH_SAMPLES       = 128;
    localparam PACKETS_PER_ROW     = 4;
    localparam HEADER_BYTES        = 4;
    localparam PAYLOAD_BYTES       = 1024;
    localparam BYTES_PER_PACKET    = HEADER_BYTES + PAYLOAD_BYTES; // 1028

    localparam ST_IDLE    = 2'd0;
    localparam ST_CAPTURE = 2'd1;
    localparam ST_TX      = 2'd2;

    // =========================================================================
    // Storage
    // =========================================================================
    reg [63:0] row_mem [0:ROW_SAMPLES-1];   // {Re, Im}

    reg [1:0] state;
    reg [8:0] cap_count;                    // 0..511
    reg [9:0] row_id_reg;

    reg [1:0]  packet_idx;                  // 0..3
    reg [10:0] byte_idx;                    // 0..1027

    // =========================================================================
    // Input ready
    // =========================================================================
    assign row_in_ready = (state == ST_IDLE) || (state == ST_CAPTURE);

    // =========================================================================
    // Combinational TX generation
    // =========================================================================
    reg [7:0] tx_tdata_r;

    integer payload_index;
    integer sample_local_index;
    integer global_sample_index;
    integer byte_in_sample;
    reg [63:0] sample_word;
    reg [31:0] sample_re_word;
    reg [31:0] sample_im_word;
    reg [31:0] hdr_word;

    always @(*) begin
        tx_tdata_r = 8'h00;

        hdr_word = {8'hFF, 8'hFF, packet_idx[1:0], 4'b0000, row_id_reg[9:0]};

        if (state == ST_TX) begin
            case (byte_idx)
                11'd0: tx_tdata_r = hdr_word[7:0];
                11'd1: tx_tdata_r = hdr_word[15:8];
                11'd2: tx_tdata_r = hdr_word[23:16];
                11'd3: tx_tdata_r = hdr_word[31:24];
                default: begin
                    payload_index       = byte_idx - HEADER_BYTES;      // 0..1023
                    sample_local_index  = payload_index >> 3;           // /8 => 0..127
                    global_sample_index = (packet_idx * BATCH_SAMPLES) + sample_local_index;
                    byte_in_sample      = payload_index[2:0];           // %8

                    sample_word    = row_mem[global_sample_index];
                    sample_re_word = sample_word[63:32];
                    sample_im_word = sample_word[31:0];

                    case (byte_in_sample)
                        3'd0: tx_tdata_r = sample_re_word[7:0];
                        3'd1: tx_tdata_r = sample_re_word[15:8];
                        3'd2: tx_tdata_r = sample_re_word[23:16];
                        3'd3: tx_tdata_r = sample_re_word[31:24];
                        3'd4: tx_tdata_r = sample_im_word[7:0];
                        3'd5: tx_tdata_r = sample_im_word[15:8];
                        3'd6: tx_tdata_r = sample_im_word[23:16];
                        3'd7: tx_tdata_r = sample_im_word[31:24];
                        default: tx_tdata_r = 8'h00;
                    endcase
                end
            endcase
        end
    end

    assign tx_tdata  = tx_tdata_r;
    assign tx_tvalid = (state == ST_TX);
    assign tx_tlast  = (state == ST_TX) && (byte_idx == BYTES_PER_PACKET-1);

    // =========================================================================
    // Main FSM / storage / counters
    // =========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= ST_IDLE;
            cap_count   <= 9'd0;
            row_id_reg  <= 10'd0;
            packet_idx  <= 2'd0;
            byte_idx    <= 11'd0;

            pkt_start   <= 1'b0;
            pkt_batch_id <= 2'd0;
            pkt_row_id   <= 10'd0;
            row_done    <= 1'b0;
        end else begin
            pkt_start <= 1'b0;
            row_done  <= 1'b0;

            case (state)
                // -------------------------------------------------------------
                // Wait for first sample of a row
                // -------------------------------------------------------------
                ST_IDLE: begin
                    if (row_in_valid && row_in_ready && row_in_start) begin
                        row_mem[0] <= {row_in_re, row_in_im};
                        row_id_reg <= row_in_row_id;
                        cap_count  <= 9'd1;
                        state      <= ST_CAPTURE;
                    end
                end

                // -------------------------------------------------------------
                // Capture full row
                // -------------------------------------------------------------
                ST_CAPTURE: begin
                    if (row_in_valid && row_in_ready) begin
                        row_mem[cap_count] <= {row_in_re, row_in_im};

                        if (cap_count == ROW_SAMPLES-1) begin
                            packet_idx <= 2'd0;
                            byte_idx   <= 11'd0;
                            state      <= ST_TX;
                        end else begin
                            cap_count <= cap_count + 9'd1;
                        end
                    end
                end

                // -------------------------------------------------------------
                // Transmit packets
                // -------------------------------------------------------------
                ST_TX: begin
                    pkt_batch_id <= packet_idx;
                    pkt_row_id   <= row_id_reg;

                    if (tx_tready) begin
                        if (byte_idx == 11'd0)
                            pkt_start <= 1'b1;

                        if (byte_idx == BYTES_PER_PACKET-1) begin
                            // End of this packet
                            if (packet_idx == PACKETS_PER_ROW-1) begin
                                // End of row transmission
                                state      <= ST_IDLE;
                                cap_count  <= 9'd0;
                                packet_idx <= 2'd0;
                                byte_idx   <= 11'd0;
                                row_done   <= 1'b1;
                            end else begin
                                packet_idx <= packet_idx + 2'd1;
                                byte_idx   <= 11'd0;
                            end
                        end else begin
                            byte_idx <= byte_idx + 11'd1;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule