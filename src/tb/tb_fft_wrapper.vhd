library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_fft_wrapper is
end entity;

architecture sim of tb_fft_wrapper is

    constant CLK_PERIOD       : time := 10 ns;
    constant NFFT             : integer := 1024;
    constant TONE_BIN         : integer := 37;
    constant AMP              : real    := 10000.0;
    constant POST_RESET_DELAY : integer := 1200;

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';

    signal in_real         : signed(31 downto 0) := (others => '0');
    signal in_imag         : signed(31 downto 0) := (others => '0');
    signal in_valid        : std_logic := '0';
    signal start_of_ascan  : std_logic := '0';
    signal end_of_ascan    : std_logic := '0';

    signal out_real            : signed(31 downto 0);
    signal out_imag            : signed(31 downto 0);
    signal out_valid           : std_logic;
    signal start_of_ascan_out  : std_logic;

    signal dbg_event_frame_started          : std_logic;
    signal dbg_event_tlast_unexpected       : std_logic;
    signal dbg_event_tlast_missing          : std_logic;
    signal dbg_event_status_channel_halt    : std_logic;
    signal dbg_event_data_in_channel_halt   : std_logic;
    signal dbg_event_data_out_channel_halt  : std_logic;
    signal dbg_input_backpressure_violation : std_logic;

    --------------------------------------------------------------------
    -- Monitoring / capture
    --------------------------------------------------------------------
    type int_array_t is array (0 to NFFT-1) of integer;

    signal soa_in_count      : integer := 0;
    signal soa_out_count     : integer := 0;
    signal out_count_total   : integer := 0;

    signal frame_capture_active : std_logic := '0';
    signal out_idx_in_frame     : integer range 0 to NFFT := 0;
    signal mag_sq_store         : int_array_t := (others => 0);
    signal capture_done         : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    dut : entity work.fft_wrapper
        port map (
            clk   => clk,
            rst   => rst,

            in_real        => in_real,
            in_imag        => in_imag,
            in_valid       => in_valid,
            start_of_ascan => start_of_ascan,
            end_of_ascan   => end_of_ascan,

            out_real           => out_real,
            out_imag           => out_imag,
            out_valid          => out_valid,
            start_of_ascan_out => start_of_ascan_out,

            dbg_event_frame_started          => dbg_event_frame_started,
            dbg_event_tlast_unexpected       => dbg_event_tlast_unexpected,
            dbg_event_tlast_missing          => dbg_event_tlast_missing,
            dbg_event_status_channel_halt    => dbg_event_status_channel_halt,
            dbg_event_data_in_channel_halt   => dbg_event_data_in_channel_halt,
            dbg_event_data_out_channel_halt  => dbg_event_data_out_channel_halt,
            dbg_input_backpressure_violation => dbg_input_backpressure_violation
        );

    --------------------------------------------------------------------
    -- Reset
    --------------------------------------------------------------------
    p_reset : process
    begin
        rst <= '1';
        wait for 50 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait;
    end process;

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    p_stimulus : process
        procedure send_complex_tone_frame (
            constant bin_idx : in integer;
            constant amp_val : in real
        ) is
            variable n      : integer;
            variable theta  : real;
            variable re_val : integer;
            variable im_val : integer;
        begin
            for n in 0 to NFFT-1 loop
                theta  := 2.0 * math_pi * real(bin_idx * n) / real(NFFT);
                re_val := integer(amp_val * cos(theta));
                im_val := integer(-amp_val * sin(theta));

                in_real        <= to_signed(re_val, 32);
                in_imag        <= to_signed(im_val, 32);
                in_valid       <= '1';
                start_of_ascan <= '0';
                end_of_ascan   <= '0';

                if n = 0 then
                    start_of_ascan <= '1';
                end if;

                if n = NFFT-1 then
                    end_of_ascan <= '1';
                end if;

                wait until rising_edge(clk);
            end loop;
        end procedure;
    begin
        wait until rst = '0';

        report "Waiting after reset to mimic upstream latency..." severity note;
        for i in 0 to POST_RESET_DELAY loop
            wait until rising_edge(clk);
        end loop;

        report "Sending one complex-tone frame for natural-order bin check" severity note;
        send_complex_tone_frame(TONE_BIN, AMP);

        in_valid        <= '0';
        start_of_ascan  <= '0';
        end_of_ascan    <= '0';
        in_real         <= (others => '0');
        in_imag         <= (others => '0');

        wait until capture_done = '1';
        wait for 100 ns;

        report "FFT natural-order bin-check stimulus complete" severity note;
        wait;
    end process;

    --------------------------------------------------------------------
    -- Input monitor
    --------------------------------------------------------------------
    p_input_monitor : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then
                if in_valid = '1' and start_of_ascan = '1' then
                    soa_in_count <= soa_in_count + 1;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Output / event monitor and frame capture
    --------------------------------------------------------------------
    p_monitor : process(clk)
        variable re_i  : integer;
        variable im_i  : integer;
        variable mag_i : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                soa_out_count        <= 0;
                out_count_total      <= 0;
                frame_capture_active <= '0';
                out_idx_in_frame     <= 0;
                capture_done         <= '0';
            else
                ----------------------------------------------------------------
                -- Critical assertions
                ----------------------------------------------------------------
                assert dbg_input_backpressure_violation = '0'
                    report "Backpressure violation!"
                    severity failure;

                assert dbg_event_data_in_channel_halt = '0'
                    report "FFT input halt detected!"
                    severity failure;

                assert dbg_event_tlast_missing = '0'
                    report "Missing TLAST!"
                    severity failure;

                assert dbg_event_tlast_unexpected = '0'
                    report "Unexpected TLAST!"
                    severity failure;

                assert dbg_event_status_channel_halt = '0'
                    report "Status channel halt detected!"
                    severity failure;

                assert dbg_event_data_out_channel_halt = '0'
                    report "FFT output halt detected!"
                    severity failure;

                ----------------------------------------------------------------
                -- Output handling
                ----------------------------------------------------------------
                if out_valid = '1' then
                    out_count_total <= out_count_total + 1;

                    if start_of_ascan_out = '1' then
                        soa_out_count <= soa_out_count + 1;
                        frame_capture_active <= '1';
                        out_idx_in_frame <= 0;
                    end if;

                    if frame_capture_active = '1' or start_of_ascan_out = '1' then
                        re_i  := to_integer(out_real);
                        im_i  := to_integer(out_imag);
                        mag_i := re_i * re_i + im_i * im_i;

                        if out_idx_in_frame < NFFT then
                            mag_sq_store(out_idx_in_frame) <= mag_i;
                            out_idx_in_frame <= out_idx_in_frame + 1;
                        end if;

                        if out_idx_in_frame = NFFT-1 then
                            frame_capture_active <= '0';
                            capture_done <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Bin correctness check for NATURAL-ORDER FFT output
    --------------------------------------------------------------------
    p_check : process
        variable max_mag       : integer;
        variable max_idx       : integer;
        variable second_mag    : integer;
        variable expected_idx  : integer;
    begin
        wait until capture_done = '1';
        wait for 1 ns;

        ----------------------------------------------------------------
        -- Find largest and second-largest bins
        ----------------------------------------------------------------
        max_mag    := mag_sq_store(0);
        max_idx    := 0;
        second_mag := 0;

        for i in 1 to NFFT-1 loop
            if mag_sq_store(i) > max_mag then
                second_mag := max_mag;
                max_mag    := mag_sq_store(i);
                max_idx    := i;
            elsif mag_sq_store(i) > second_mag then
                second_mag := mag_sq_store(i);
            end if;
        end loop;

        expected_idx := TONE_BIN;

        report "Expected dominant output index = " & integer'image(expected_idx) severity note;
        report "Observed dominant output index = " & integer'image(max_idx) severity note;
        report "Observed dominant magnitude^2 = " & integer'image(max_mag) severity note;
        report "Observed second-largest magnitude^2 = " & integer'image(second_mag) severity note;

        assert soa_in_count = 1
            report "Expected 1 input frame start, got " & integer'image(soa_in_count)
            severity failure;

        assert soa_out_count = 1
            report "Expected 1 output frame start, got " & integer'image(soa_out_count)
            severity failure;

        assert max_idx = expected_idx
            report "FFT dominant bin index mismatch: expected " &
                   integer'image(expected_idx) & ", got " &
                   integer'image(max_idx)
            severity failure;

        assert max_mag > second_mag
            report "Dominant FFT bin is not larger than second-largest bin"
            severity failure;

        report "TEST PASSED: FFT natural-order bin correctness verified" severity note;
        wait;
    end process;

end architecture;