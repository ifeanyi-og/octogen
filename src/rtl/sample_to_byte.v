
module sample_to_byte (
    input  wire        clk,
    input  wire        rst,
    
    // 32-bit sample input
    input  wire [31:0] s_sample_tdata,
    input  wire        s_sample_tvalid,
    output reg         s_sample_tready,
    input  wire        s_sample_tlast,
    
    // Byte stream output
    output wire [7:0]  m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    reg [31:0] sample_hold;
    reg [1:0]  byte_ptr;
    reg        sending;
    reg        last_flag;
    
    reg [7:0] byte_out;

    // ========================================================================
    // Combinatorial: Extract current byte from sample_hold
    // ========================================================================
    always @(*) begin
        case(byte_ptr)
            2'd0: byte_out = sample_hold[31:24];
            2'd1: byte_out = sample_hold[23:16];
            2'd2: byte_out = sample_hold[15:8];
            2'd3: byte_out = sample_hold[7:0];
            default: byte_out = 8'h00;
        endcase
    end

    // ========================================================================
    // Output assignments
    // ========================================================================
    assign m_axis_tdata  = byte_out;
    assign m_axis_tvalid = sending;
    assign m_axis_tlast  = sending && (byte_ptr == 2'd3) && last_flag;
    
    // Ready when not currently sending
    always @(*) begin
        s_sample_tready = !sending;
    end

    // ========================================================================
    // Sequential logic
    // ========================================================================
    always @(posedge clk) begin
        if (rst) begin
            sending     <= 0;
            byte_ptr    <= 0;
            sample_hold <= 0;
            last_flag   <= 0;
        end
        else begin
            // Load new sample when not sending and input is valid
            if (!sending && s_sample_tvalid) begin
                sample_hold <= s_sample_tdata;
                last_flag   <= s_sample_tlast;
                byte_ptr    <= 0;
                sending     <= 1;
            end
            // Transmit bytes when sending and downstream is ready
            else if (sending && m_axis_tvalid && m_axis_tready) begin
                if (byte_ptr == 2'd3) begin
                    // Final byte sent - stop sending
                    sending  <= 0;
                    byte_ptr <= 0;
                end
                else begin
                    // Move to next byte
                    byte_ptr <= byte_ptr + 1;
                end
            end
        end
    end

endmodule
