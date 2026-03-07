
`timescale 1ns/1ps

module sample_to_byte_tb;

////////////////////////////////////////////////////////////
// Clock
////////////////////////////////////////////////////////////

logic clk = 0;
always #5 clk = ~clk;

////////////////////////////////////////////////////////////
// DUT signals
////////////////////////////////////////////////////////////

logic rst;

// input AXI stream
logic [31:0] s_sample_tdata;
logic        s_sample_tvalid;
logic        s_sample_tready;
logic        s_sample_tlast;

// output AXI stream
logic [7:0]  m_axis_tdata;
logic        m_axis_tvalid;
logic        m_axis_tready;
logic        m_axis_tlast;

////////////////////////////////////////////////////////////
// DUT
////////////////////////////////////////////////////////////

sample_to_byte dut (
    .clk(clk),
    .rst(rst),

    .s_sample_tdata(s_sample_tdata),
    .s_sample_tvalid(s_sample_tvalid),
    .s_sample_tready(s_sample_tready),
    .s_sample_tlast(s_sample_tlast),

    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast)
);

////////////////////////////////////////////////////////////
// AXI SAMPLE DRIVER
// Holds data stable until handshake
////////////////////////////////////////////////////////////

task send_sample(input logic [31:0] data, input logic last);
begin
    @(posedge clk);

    s_sample_tdata  <= data;
    s_sample_tlast  <= last;
    s_sample_tvalid <= 1;

    // Wait until DUT accepts the sample
    while (!s_sample_tready)
        @(posedge clk);

    @(posedge clk);

    s_sample_tvalid <= 0;
end
endtask

////////////////////////////////////////////////////////////
// BYTE MONITOR
////////////////////////////////////////////////////////////

int byte_index = 0;
int sample_index = 0;
logic [31:0] reconstructed;

always @(posedge clk)
begin
    if (m_axis_tvalid && m_axis_tready)
    begin
        $display("  Byte %0d: %02h", byte_index, m_axis_tdata);

        reconstructed = {reconstructed[23:0], m_axis_tdata};

        byte_index++;

        if (byte_index == 4)
        begin
            $display("Sample %0d reconstructed = %h\n",
                sample_index, reconstructed);

            byte_index = 0;
            sample_index++;
        end

        if (m_axis_tlast)
            $display("✓ TLAST asserted\n");
    end
end

////////////////////////////////////////////////////////////
// Reset
////////////////////////////////////////////////////////////

initial
begin
    rst = 1;

    s_sample_tvalid = 0;
    s_sample_tdata  = 0;
    s_sample_tlast  = 0;

    m_axis_tready   = 1;

    repeat(5) @(posedge clk);

    rst = 0;
end

////////////////////////////////////////////////////////////
// TEST SEQUENCE
////////////////////////////////////////////////////////////

initial
begin

////////////////////////////////////////////////////////////
// TEST 1
////////////////////////////////////////////////////////////

    @(negedge rst);

    $display("\n==============================");
    $display("TEST 1: Single Sample");
    $display("==============================\n");

    send_sample(32'h01020304, 1);

    repeat(20) @(posedge clk);



////////////////////////////////////////////////////////////
// TEST 2
////////////////////////////////////////////////////////////

    $display("\n==============================");
    $display("TEST 2: Three Samples With TLAST On Last");
    $display("==============================\n");

    sample_index = 0;
    byte_index   = 0;

    send_sample(32'h01020304, 0);
    send_sample(32'h02030405, 0);
    send_sample(32'h03040506, 1);

    repeat(40) @(posedge clk);



////////////////////////////////////////////////////////////
// TEST 3
////////////////////////////////////////////////////////////

    $display("\n==============================");
    $display("TEST 3: Continuous Stream");
    $display("==============================\n");

    sample_index = 0;
    byte_index   = 0;

    send_sample(32'h11121314, 0);
    send_sample(32'h21222324, 0);
    send_sample(32'h31323334, 0);
    send_sample(32'h41424344, 1);

    repeat(50) @(posedge clk);



////////////////////////////////////////////////////////////
// TEST 4
////////////////////////////////////////////////////////////

    $display("\n==============================");
    $display("TEST 4: Backpressure Test");
    $display("==============================\n");

    sample_index = 0;
    byte_index   = 0;

    fork

        // random backpressure
        begin
            repeat(80)
            begin
                @(posedge clk);
                m_axis_tready <= $urandom_range(0,1);
            end

            m_axis_tready <= 1;
        end

        begin
            send_sample(32'hAA55AA55, 0);
            send_sample(32'h12345678, 1);
        end

    join

    repeat(40) @(posedge clk);



////////////////////////////////////////////////////////////
// FINISH
////////////////////////////////////////////////////////////

    $display("\nAll tests complete.\n");

    #100;
    $finish;

end

endmodule
