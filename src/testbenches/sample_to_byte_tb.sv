
`timescale 1ns/1ps

module sample_to_byte_tb;

    // ============================================================
    // Clock
    // ============================================================
    logic clk = 0;
    always #5 clk = ~clk;

    // ============================================================
    // DUT signals
    // ============================================================
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

    // ============================================================
    // DUT
    // ============================================================
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

    // ============================================================
    // Scoreboard / logging
    // ============================================================
    integer pass_count = 0;
    integer fail_count = 0;
    integer cycle_count = 0;

    bit verbose_cycle_log = 0;
    bit verbose_byte_log  = 0;

    reg [7:0] captured_bytes [0:1023];
    reg       captured_last  [0:1023];
    integer   captured_cycle [0:1023];
    integer   cap_count = 0;

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;

        if (verbose_cycle_log) begin
            $display("CYCLE=%0d | rst=%0b | in: data=0x%08h valid=%0b ready=%0b last=%0b | out: data=0x%02h valid=%0b ready=%0b last=%0b",
                     cycle_count,
                     rst,
                     s_sample_tdata, s_sample_tvalid, s_sample_tready, s_sample_tlast,
                     m_axis_tdata, m_axis_tvalid, m_axis_tready, m_axis_tlast);
        end

        if (m_axis_tvalid && m_axis_tready) begin
            captured_bytes[cap_count] = m_axis_tdata;
            captured_last[cap_count]  = m_axis_tlast;
            captured_cycle[cap_count] = cycle_count;

            if (verbose_byte_log) begin
                $display("BYTE_HS @ cycle %0d : byte[%0d]=0x%02h last=%0b",
                         cycle_count, cap_count, m_axis_tdata, m_axis_tlast);
            end

            cap_count = cap_count + 1;
        end
    end

    // ============================================================
    // Utility tasks
    // ============================================================
    task automatic check_true(input string name, input bit cond);
    begin
        if (cond) begin
            pass_count = pass_count + 1;
            $display("PASS: %s", name);
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: %s", name);
        end
    end
    endtask

    task automatic check_eq_u8(input string name, input logic [7:0] got, input logic [7:0] exp);
    begin
        if (got === exp) begin
            pass_count = pass_count + 1;
            $display("PASS: %s | got=0x%02h", name, got);
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: %s | got=0x%02h exp=0x%02h", name, got, exp);
        end
    end
    endtask

    task automatic clear_capture;
        integer k;
    begin
        for (k = 0; k < 1024; k = k + 1) begin
            captured_bytes[k] = 8'h00;
            captured_last[k]  = 1'b0;
            captured_cycle[k] = 0;
        end
        cap_count = 0;
    end
    endtask

    task automatic apply_reset;
    begin
        rst = 1'b1;
        s_sample_tdata  = 32'h00000000;
        s_sample_tlast  = 1'b0;
        s_sample_tvalid = 1'b0;
        m_axis_tready   = 1'b0;
        verbose_cycle_log = 1'b0;
        verbose_byte_log  = 1'b0;
        clear_capture();

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
    end
    endtask

    task automatic send_sample(input logic [31:0] data, input logic last);
        integer timeout;
    begin
        @(negedge clk);
        s_sample_tdata  <= data;
        s_sample_tlast  <= last;
        s_sample_tvalid <= 1'b1;

        timeout = 0;
        while (s_sample_tready !== 1'b1) begin
            @(posedge clk);
            timeout = timeout + 1;
            if (timeout > 100) begin
                fail_count = fail_count + 1;
                $display("FAIL: send_sample timeout waiting for s_sample_tready");
                disable send_sample;
            end
        end

        @(posedge clk); // handshake edge

        @(negedge clk);
        s_sample_tvalid <= 1'b0;
        s_sample_tlast  <= 1'b0;
        s_sample_tdata  <= 32'h00000000;
    end
    endtask

    task automatic wait_for_byte_count(input integer target_count, input integer max_cycles, output bit ok);
        integer k;
    begin
        ok = 0;
        for (k = 0; k < max_cycles; k = k + 1) begin
            if (cap_count >= target_count) begin
                ok = 1;
                disable wait_done_bc;
            end
            @(posedge clk);
        end
        begin : wait_done_bc end
    end
    endtask

    task automatic wait_n_cycles(input integer n);
        integer k;
    begin
        for (k = 0; k < n; k = k + 1)
            @(posedge clk);
    end
    endtask

    task automatic check_bytes_4(
        input integer base,
        input logic [7:0] b0,
        input logic [7:0] b1,
        input logic [7:0] b2,
        input logic [7:0] b3
    );
    begin
        check_eq_u8($sformatf("byte[%0d]", base+0), captured_bytes[base+0], b0);
        check_eq_u8($sformatf("byte[%0d]", base+1), captured_bytes[base+1], b1);
        check_eq_u8($sformatf("byte[%0d]", base+2), captured_bytes[base+2], b2);
        check_eq_u8($sformatf("byte[%0d]", base+3), captured_bytes[base+3], b3);
    end
    endtask

    task automatic check_last_flags_4(
        input integer base,
        input bit l0,
        input bit l1,
        input bit l2,
        input bit l3
    );
    begin
        check_true($sformatf("last[%0d]==%0b", base+0, l0), captured_last[base+0] === l0);
        check_true($sformatf("last[%0d]==%0b", base+1, l1), captured_last[base+1] === l1);
        check_true($sformatf("last[%0d]==%0b", base+2, l2), captured_last[base+2] === l2);
        check_true($sformatf("last[%0d]==%0b", base+3, l3), captured_last[base+3] === l3);
    end
    endtask

    task automatic check_output_stable_before_first_handshake(
        input logic [31:0] sample_data,
        input logic        sample_last,
        input integer      stall_cycles
    );
        logic [7:0] held_data;
        logic       held_last;
        integer k;
        bit ok;
    begin
        clear_capture();
    
        @(negedge clk);
        m_axis_tready <= 1'b0;
    
        fork
            begin
                send_sample(sample_data, sample_last);
            end
            begin
                ok = 0;
                for (k = 0; k < 40; k = k + 1) begin
                    @(posedge clk);
                    if (m_axis_tvalid === 1'b1) begin
                        ok = 1;
                        disable got_valid_hold;
                    end
                end
                begin : got_valid_hold end
    
                check_true("stall stability precondition: m_axis_tvalid seen before first handshake", ok);
    
                if (ok) begin
                    held_data = m_axis_tdata;
                    held_last = m_axis_tlast;
    
                    for (k = 0; k < stall_cycles; k = k + 1) begin
                        @(posedge clk);
                        check_true($sformatf("stall data stable cycle %0d", k),  m_axis_tdata  === held_data);
                        check_true($sformatf("stall last stable cycle %0d", k),  m_axis_tlast  === held_last);
                        check_true($sformatf("stall valid high cycle %0d", k),   m_axis_tvalid === 1'b1);
                    end
                end
    
                @(negedge clk);
                m_axis_tready <= 1'b1;
            end
        join
    
        // Wait for the 4 bytes from this helper transaction to fully drain
        ok = 0;
        wait_for_byte_count(4, 40, ok);
        check_true("stall helper transaction completed", ok);
    
        @(negedge clk);
        m_axis_tready <= 1'b1;
    end
    endtask



    // ============================================================
    // Main test sequence
    // ============================================================
    integer base_cap;
    bit ok;

    initial begin
        apply_reset();

        // ========================================================
        // TEST 1: Single sample exact byte order
        // ========================================================
        $display("\n============================================================");
        $display("TEST 1: Single sample exact byte order");
        $display("============================================================");

        clear_capture();
        base_cap = cap_count;

        verbose_cycle_log = 1'b1;
        verbose_byte_log  = 1'b1;

        @(negedge clk);
        m_axis_tready <= 1'b1;

        check_true("T1 ready high when idle", s_sample_tready === 1'b1);

        send_sample(32'h01020304, 1'b1);

        wait_for_byte_count(base_cap + 4, 30, ok);
        check_true("T1 got 4 byte handshakes", ok);

        if (ok) begin
            check_bytes_4(base_cap, 8'h01, 8'h02, 8'h03, 8'h04);
            check_last_flags_4(base_cap, 1'b0, 1'b0, 1'b0, 1'b1);
        end

        verbose_cycle_log = 1'b0;
        verbose_byte_log  = 1'b0;

        wait_n_cycles(4);

        // ========================================================
        // TEST 2: Three samples exact sequence
        // ========================================================
        $display("\n============================================================");
        $display("TEST 2: Three samples exact sequence");
        $display("============================================================");

        clear_capture();
        base_cap = cap_count;

        @(negedge clk);
        m_axis_tready <= 1'b1;

        send_sample(32'h01020304, 1'b0);
        send_sample(32'h02030405, 1'b0);
        send_sample(32'h03040506, 1'b1);

        wait_for_byte_count(base_cap + 12, 80, ok);
        check_true("T2 got 12 byte handshakes", ok);

        if (ok) begin
            check_bytes_4(base_cap + 0, 8'h01, 8'h02, 8'h03, 8'h04);
            check_last_flags_4(base_cap + 0, 1'b0, 1'b0, 1'b0, 1'b0);

            check_bytes_4(base_cap + 4, 8'h02, 8'h03, 8'h04, 8'h05);
            check_last_flags_4(base_cap + 4, 1'b0, 1'b0, 1'b0, 1'b0);

            check_bytes_4(base_cap + 8, 8'h03, 8'h04, 8'h05, 8'h06);
            check_last_flags_4(base_cap + 8, 1'b0, 1'b0, 1'b0, 1'b1);
        end

        wait_n_cycles(4);

        // ========================================================
        // TEST 3: Continuous stream + ready behavior
        // ========================================================
        $display("\n============================================================");
        $display("TEST 3: Continuous stream + ready behavior");
        $display("============================================================");

        clear_capture();
        base_cap = cap_count;

        @(negedge clk);
        m_axis_tready <= 1'b1;

        check_true("T3 idle ready before send", s_sample_tready === 1'b1);

        fork
            begin
                send_sample(32'h11121314, 1'b0);
                send_sample(32'h21222324, 1'b0);
                send_sample(32'h31323334, 1'b0);
                send_sample(32'h41424344, 1'b1);
            end

            begin
                integer seen_bytes;
                bit done;
                seen_bytes = 0;
                done = 0;
            
                for (integer k = 0; (k < 40) && !done; k = k + 1) begin
                    @(posedge clk);
                    if (m_axis_tvalid && m_axis_tready) begin
                        if (seen_bytes < 3) begin
                            @(negedge clk);
                            check_true($sformatf("T3 ready low during byte %0d of sample", seen_bytes),
                                       s_sample_tready === 1'b0);
                        end
                        seen_bytes = seen_bytes + 1;
                        if (seen_bytes >= 4)
                            done = 1;
                    end
                end
            
                check_true("T3 saw at least one full sample for ready check", seen_bytes >= 4);
            end
        join

        wait_for_byte_count(base_cap + 16, 120, ok);
        check_true("T3 got 16 byte handshakes", ok);

        if (ok) begin
            check_bytes_4(base_cap + 0,  8'h11, 8'h12, 8'h13, 8'h14);
            check_bytes_4(base_cap + 4,  8'h21, 8'h22, 8'h23, 8'h24);
            check_bytes_4(base_cap + 8,  8'h31, 8'h32, 8'h33, 8'h34);
            check_bytes_4(base_cap + 12, 8'h41, 8'h42, 8'h43, 8'h44);
            check_last_flags_4(base_cap + 12, 1'b0, 1'b0, 1'b0, 1'b1);
        end

        wait_n_cycles(6);
        check_true("T3 ready high again after stream completes", s_sample_tready === 1'b1);

        // ========================================================
        // TEST 4: Backpressure exact correctness + stability
        // ========================================================
        $display("\n============================================================");
        $display("TEST 4: Backpressure exact correctness + stability");
        $display("============================================================");

        // First prove stall-hold behavior cleanly on one sample.
        check_output_stable_before_first_handshake(32'hAA55AA55, 1'b0, 3);
        
        wait_n_cycles(4);
        clear_capture();
        base_cap = cap_count;

        // Then run two samples with irregular stalls and check exact output.
        clear_capture();
        base_cap = cap_count;

        @(negedge clk);
        m_axis_tready <= 1'b1;

        fork
            begin
                send_sample(32'hAA55AA55, 1'b0);
                send_sample(32'h12345678, 1'b1);
            end
            begin
                wait_n_cycles(6);
                @(negedge clk); m_axis_tready <= 1'b0;
                wait_n_cycles(2);
                @(negedge clk); m_axis_tready <= 1'b1;

                wait_n_cycles(3);
                @(negedge clk); m_axis_tready <= 1'b0;
                wait_n_cycles(1);
                @(negedge clk); m_axis_tready <= 1'b1;
            end
        join

        wait_for_byte_count(base_cap + 8, 120, ok);
        check_true("T4 got 8 byte handshakes", ok);

        if (ok) begin
            check_bytes_4(base_cap + 0, 8'hAA, 8'h55, 8'hAA, 8'h55);
            check_last_flags_4(base_cap + 0, 1'b0, 1'b0, 1'b0, 1'b0);

            check_bytes_4(base_cap + 4, 8'h12, 8'h34, 8'h56, 8'h78);
            check_last_flags_4(base_cap + 4, 1'b0, 1'b0, 1'b0, 1'b1);
        end

        // ========================================================
        // TEST 5: Reset mid-transfer
        // ========================================================
        $display("\n============================================================");
        $display("TEST 5: Reset mid-transfer");
        $display("============================================================");

        clear_capture();
        base_cap = cap_count;

        @(negedge clk);
        m_axis_tready <= 1'b1;

        fork
            begin
                send_sample(32'hDEADBEEF, 1'b1);
            end
            begin
                wait_for_byte_count(base_cap + 2, 30, ok);
                check_true("T5 saw at least 2 bytes before reset", ok);

                @(negedge clk);
                rst <= 1'b1;
                @(posedge clk);
                @(posedge clk);
                @(negedge clk);
                rst <= 1'b0;
            end
        join

        wait_n_cycles(4);
        check_true("T5 valid low after reset", m_axis_tvalid === 1'b0);
        check_true("T5 ready high after reset idle", s_sample_tready === 1'b1);

        clear_capture();
        base_cap = cap_count;

        send_sample(32'h0A0B0C0D, 1'b1);
        wait_for_byte_count(base_cap + 4, 40, ok);
        check_true("T5 recovery sample emitted 4 bytes", ok);

        if (ok) begin
            check_bytes_4(base_cap, 8'h0A, 8'h0B, 8'h0C, 8'h0D);
            check_last_flags_4(base_cap, 1'b0, 1'b0, 1'b0, 1'b1);
        end

        // ========================================================
        // TEST 6: Mixed-value sanity test
        // ========================================================
        $display("\n============================================================");
        $display("TEST 6: Mixed-value sanity test");
        $display("============================================================");

        clear_capture();
        base_cap = cap_count;

        @(negedge clk);
        m_axis_tready <= 1'b1;

        send_sample(32'h00FF807F, 1'b0);
        send_sample(32'hFFFFFFFF, 1'b1);

        wait_for_byte_count(base_cap + 8, 60, ok);
        check_true("T6 got 8 bytes", ok);

        if (ok) begin
            check_bytes_4(base_cap + 0, 8'h00, 8'hFF, 8'h80, 8'h7F);
            check_last_flags_4(base_cap + 0, 1'b0, 1'b0, 1'b0, 1'b0);

            check_bytes_4(base_cap + 4, 8'hFF, 8'hFF, 8'hFF, 8'hFF);
            check_last_flags_4(base_cap + 4, 1'b0, 1'b0, 1'b0, 1'b1);
        end

        // ========================================================
        // Summary
        // ========================================================
        $display("\n============================================================");
        $display("FINAL SUMMARY");
        $display("============================================================");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule

