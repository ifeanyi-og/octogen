`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/27/2026 01:40:13 PM
// Design Name: 
// Module Name: sample_to_byte
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sample_to_byte (
    input  wire        clk,
    input  wire        rst,

    // Real sample input (512 x 32-bit)
    input  wire [31:0] s_real_tdata,
    input  wire        s_real_tvalid,
    output wire        s_real_tready,
    input  wire        s_real_tlast,

    // Imaginary sample input (512 x 32-bit)
    input  wire [31:0] s_imag_tdata,
    input  wire        s_imag_tvalid,
    output wire        s_imag_tready,
    input  wire        s_imag_tlast,

    // Byte stream output (to UDP TX)
    output wire [7:0]  m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    // ========================================================================
    // State: which stream are we processing? (REAL -> IMAG -> IDLE)
    // ========================================================================
    reg [1:0] state;
    localparam STATE_REAL = 2'b00;
    localparam STATE_IMAG = 2'b01;
    localparam STATE_IDLE = 2'b10;

    // ========================================================================
    // Byte pointer and sample holding
    // ========================================================================
    reg [1:0]  byte_ptr;
    reg [31:0] sample_hold;
    reg        last_flag;       // Set when last sample of real or imag stream
    reg        is_last_sample;  // Last sample of imaginary stream (end of packet)

    // ========================================================================
    // Output assignments
    // ========================================================================
    assign m_axis_tdata = sample_hold[(byte_ptr * 8) +: 8];
    assign m_axis_tvalid = (state != STATE_IDLE) || (byte_ptr != 0);
    
    // tlast goes high only after the last byte of the imaginary stream
    assign m_axis_tlast = (byte_ptr == 2'b11) && is_last_sample && 
                          ((state == STATE_IMAG && s_imag_tvalid) || (state == STATE_IDLE));

    // Ready to accept new samples depends on state and byte_ptr
    assign s_real_tready = (state == STATE_REAL) && (byte_ptr == 2'b00 || m_axis_tready);
    assign s_imag_tready = (state == STATE_IMAG) && (byte_ptr == 2'b00 || m_axis_tready);

    // ========================================================================
    // Main state machine
    // ========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            byte_ptr <= 0;
            sample_hold <= 0;
            last_flag <= 0;
            is_last_sample <= 0;
        end else begin
            case (state)
                STATE_REAL: begin
                    // Streaming real samples (512 of them)
                    if (m_axis_tvalid && m_axis_tready) begin
                        byte_ptr <= byte_ptr + 1;

                        if (byte_ptr == 2'b11) begin
                            // Finished a 32-bit real sample
                            if (s_real_tvalid) begin
                                sample_hold <= s_real_tdata;
                                last_flag <= s_real_tlast;

                                // Check if this was the last real sample
                                if (s_real_tlast) begin
                                    state <= STATE_IMAG;
                                end
                            end
                            byte_ptr <= 0;
                        end
                    end
                end

                STATE_IMAG: begin
                    // Streaming imaginary samples (512 of them)
                    if (m_axis_tvalid && m_axis_tready) begin
                        byte_ptr <= byte_ptr + 1;

                        if (byte_ptr == 2'b11) begin
                            // Finished a 32-bit imaginary sample
                            if (s_imag_tvalid) begin
                                sample_hold <= s_imag_tdata;
                                is_last_sample <= s_imag_tlast;

                                // Check if this was the last imaginary sample (end of packet)
                                if (s_imag_tlast) begin
                                    state <= STATE_IDLE;
                                end
                            end
                            byte_ptr <= 0;
                        end
                    end
                end

                STATE_IDLE: begin
                    // Idle state; wait for real samples to arrive
                    if (s_real_tvalid) begin
                        state <= STATE_REAL;
                        sample_hold <= s_real_tdata;
                        byte_ptr <= 0;
                        last_flag <= s_real_tlast;
                    end
                end
            endcase
        end
    end

endmodule

