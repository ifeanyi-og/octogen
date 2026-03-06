
module sample_to_byte (
    input  wire        clk,
    input  wire        rst,

    // 32-bit sample input (from DSP or parser)
    input  wire [31:0] s_sample_tdata,
    input  wire        s_sample_tvalid,
    output wire        s_sample_tready,
    input  wire        s_sample_tlast,

    // Byte stream output (to UDP TX)
    output wire [7:0]  m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,
    
    // DEBUG: byte pointer and hold register
    output wire [1:0]  debug_byte_ptr,
    output wire [31:0] debug_sample_hold
);

    reg [1:0]  byte_ptr;
    reg [31:0] sample_hold;
    reg        last_flag;
    reg        sending;  // Flag: currently sending a sample

    // ========================================================================
    // Output Logic - Explicit Assignments
    // ========================================================================
    // Extract byte at position byte_ptr (big-endian MSB first)
    assign m_axis_tdata = sample_hold[(3 - byte_ptr) * 8 +: 8];
    
    // Only valid when actively sending a sample
    assign m_axis_tvalid = sending;
    
    // tlast only at last byte (byte_ptr==3) of last sample (last_flag==1)
    assign m_axis_tlast = (byte_ptr == 2'b11) && last_flag && m_axis_tvalid && m_axis_tready;
    
    // Ready to accept new sample only when NOT currently sending
    assign s_sample_tready = !sending;
    
    // DEBUG outputs
    assign debug_byte_ptr = byte_ptr;
    assign debug_sample_hold = sample_hold;

    // ========================================================================
    // FSM: Load sample when ready, send bytes one at a time
    // NO FLUSH - Parser handles alignment via s_udp_tlast resets
    // ========================================================================
    always @(posedge clk) begin
        if (rst) begin
            byte_ptr <= 0;
            sending <= 0;
            sample_hold <= 0;
            last_flag <= 0;
        end else begin
            
            // ===== STATE 1: Wait for sample and load it =====
            if (!sending && s_sample_tvalid) begin
                // New sample arrived and we're not sending
                sample_hold <= s_sample_tdata;
                last_flag <= s_sample_tlast;
                sending <= 1;
                byte_ptr <= 0;
            end
            
            // ===== STATE 2: Send bytes one at a time =====
            if (sending && m_axis_tvalid && m_axis_tready) begin
                // Output accepted, move to next byte
                byte_ptr <= byte_ptr + 1;
                
                // After sending 4th byte (byte_ptr was 3), done with this sample
                if (byte_ptr == 2'b11) begin
                    sending <= 0;
                    // Ready for next sample
                end
            end
            
        end
    end

endmodule

