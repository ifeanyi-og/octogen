`timescale 1ns / 1ps

module app_packet_rx (
    input  wire        clk,
    input  wire        rst,

    // UDP RX byte stream
    input  wire [7:0]  udp_rx_tdata,
    input  wire        udp_rx_tvalid,
    output wire        udp_rx_tready,
    input  wire        udp_rx_tlast,

    // Header / packet classification
    output reg         hdr_valid,       // pulse when a valid header is accepted
    output reg         hdr_error,       // pulse when header is invalid
    output reg         pkt_is_data,     // pulse with hdr_valid for 0xFF01
    output reg         pkt_is_cal,      // pulse with hdr_valid for 0xFF02
    output reg  [7:0]  pkt_msg_type,    // 8'h01 or 8'h02 on hdr_valid
    output reg  [1:0]  batch_id,        // header[15:14]
    output reg  [9:0]  row_id,          // data row id or calibration target id

    // Batch metadata output (end-of-packet pulse)
    output reg         batch_valid,

    // Sample stream output
    output reg  [31:0] sample_data,
    output reg         sample_valid,
    output reg         sample_last
);

    // Hardcoded calibration target IDs for protocol visibility/debug
    `define CAL_BG_SUB   10'd0
    `define CAL_DISP_A   10'd20
    `define CAL_DISP_B   10'd21
    `define CAL_KLIN_A   10'd24
    `define CAL_KLIN_B   10'd25
    `define CAL_KLIN_C   10'd26
    `define CAL_KLIN_D   10'd27
    `define CAL_KLIN_E   10'd28

    localparam ST_HDR   = 2'd0;
    localparam ST_SAMP  = 2'd1;
    localparam ST_ERROR = 2'd2;

    localparam SAMPLES_PER_BATCH = 256;

    reg [1:0]  state;

    reg [1:0]  hdr_byte_cnt;
    reg [31:0] hdr_shift;

    reg [1:0]  byte_in_word;
    reg [7:0]  sample_cnt;
    reg [31:0] sample_shift;

    reg [31:0] header_word;

    wire hdr_magic_ok;
    wire hdr_type_ok;
    wire hdr_rsvd_ok;

    assign udp_rx_tready = 1'b1;

    assign hdr_magic_ok = (header_word[31:24] == 8'hFF);
    assign hdr_type_ok  = (header_word[23:16] == 8'h01) ||
                          (header_word[23:16] == 8'h02);
    assign hdr_rsvd_ok  = (header_word[13:10] == 4'b0000);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= ST_HDR;
            hdr_byte_cnt <= 2'd0;
            hdr_shift    <= 32'd0;
    
            byte_in_word <= 2'd0;
            sample_cnt   <= 8'd0;
            sample_shift <= 32'd0;
    
            hdr_valid    <= 1'b0;
            hdr_error    <= 1'b0;
            pkt_is_data  <= 1'b0;
            pkt_is_cal   <= 1'b0;
            pkt_msg_type <= 8'd0;
            batch_id     <= 2'd0;
            row_id       <= 10'd0;
    
            batch_valid  <= 1'b0;
            sample_data  <= 32'd0;
            sample_valid <= 1'b0;
            sample_last  <= 1'b0;
        end else begin
            hdr_valid    <= 1'b0;
            pkt_is_data  <= 1'b0;
            pkt_is_cal   <= 1'b0;
            batch_valid  <= 1'b0;
            sample_valid <= 1'b0;
            sample_last  <= 1'b0;
    
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
                                header_word = {udp_rx_tdata, hdr_shift[23:0]};
    
                                if ((header_word[31:24] == 8'hFF) &&
                                    ((header_word[23:16] == 8'h01) ||
                                     (header_word[23:16] == 8'h02)) &&
                                    (header_word[13:10] == 4'b0000)) begin
    
                                    hdr_valid    <= 1'b1;
                                    hdr_error    <= 1'b0;
                                    pkt_msg_type <= header_word[23:16];
                                    batch_id     <= header_word[15:14];
                                    row_id       <= header_word[9:0];
    
                                    if (header_word[23:16] == 8'h01)
                                        pkt_is_data <= 1'b1;
                                    else
                                        pkt_is_cal  <= 1'b1;
    
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
                            byte_in_word <= 2'd0;
                            sample_cnt   <= 8'd0;
                        end
                    end
    
                    ST_SAMP: begin
                        hdr_error <= 1'b0;
    
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
                                sample_last  <= 1'b1;
                                batch_valid  <= 1'b1;
                                sample_cnt   <= 8'd0;
                                state        <= ST_HDR;
                                hdr_byte_cnt <= 2'd0;
                            end else begin
                                sample_cnt <= sample_cnt + 8'd1;
                            end
                        end else begin
                            byte_in_word <= byte_in_word + 2'd1;
                        end
    
                        if (udp_rx_tlast) begin
                            if (!((byte_in_word == 2'd3) && (sample_cnt == SAMPLES_PER_BATCH-1))) begin
                                state        <= ST_HDR;
                                hdr_byte_cnt <= 2'd0;
                                byte_in_word <= 2'd0;
                                sample_cnt   <= 8'd0;
                            end
                        end
                    end
    
                    ST_ERROR: begin
                        hdr_error <= 1'b1;
    
                        if (udp_rx_tlast) begin
                            state        <= ST_HDR;
                            hdr_byte_cnt <= 2'd0;
                            byte_in_word <= 2'd0;
                            sample_cnt   <= 8'd0;
                            hdr_error    <= 1'b0;
                        end
                    end
    
                    default: begin
                        state        <= ST_HDR;
                        hdr_byte_cnt <= 2'd0;
                        byte_in_word <= 2'd0;
                        sample_cnt   <= 8'd0;
                        hdr_error    <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
