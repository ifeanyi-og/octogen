library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_fft_wrapper is
end entity;

architecture sim of tb_fft_wrapper is

    constant CLK_PERIOD : time := 10 ns;
    constant NFFT       : integer := 1024;
    constant TONE_BIN   : integer := 37;
    constant AMP        : real    := 10000.0;
    constant N_FRAMES   : integer := 4;

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
    -- Monitoring
    --------------------------------------------------------------------
    signal in_accept_count : integer := 0;
    signal soa_in_count    : integer := 0;
    signal out_count       : integer := 0;
    signal soa_out_count   : integer := 0;
    
    signal  dbg_cfg_done : std_logic;

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
    --
    -- Sends N_FRAMES back-to-back complex-tone frames with:
    --   * one valid sample every clock
    --   * no gaps between frames
    --
    -- This is the stress test for continuous valid-only streaming.
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
                im_val := integer(amp_val * sin(theta));

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

        variable f : integer;
    begin
        wait until rst = '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        report "Sending " & integer'image(N_FRAMES) &
               " back-to-back complex-tone frames with no gaps"
               severity note;

        for f in 1 to N_FRAMES loop
            send_complex_tone_frame(TONE_BIN, AMP);
        end loop;

        in_valid        <= '0';
        start_of_ascan  <= '0';
        end_of_ascan    <= '0';
        in_real         <= (others => '0');
        in_imag         <= (others => '0');

        ----------------------------------------------------------------
        -- Wait long enough for outputs to drain
        ----------------------------------------------------------------
        wait for 150000 ns;

        ----------------------------------------------------------------
        -- Final checks
        ----------------------------------------------------------------
        assert soa_in_count = N_FRAMES
            report "Expected " & integer'image(N_FRAMES) &
                   " input frame starts, got " & integer'image(soa_in_count)
            severity failure;

        assert soa_out_count = N_FRAMES
            report "Expected " & integer'image(N_FRAMES) &
                   " output frame starts, got " & integer'image(soa_out_count)
            severity failure;

        assert soa_out_count = soa_in_count
            report "Mismatch between input and output frame counts"
            severity failure;

        assert out_count > 0
            report "No FFT outputs observed"
            severity failure;

        report "Back-to-back frame stress test complete" severity note;
        wait;
    end process;

    --------------------------------------------------------------------
    -- Input-side monitor
    --------------------------------------------------------------------
    p_input_monitor : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                in_accept_count <= 0;
                soa_in_count    <= 0;
            else
                if in_valid = '1' then
                    in_accept_count <= in_accept_count + 1;
                end if;

                if in_valid = '1' and start_of_ascan = '1' then
                    soa_in_count <= soa_in_count + 1;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Output/event monitor
    --------------------------------------------------------------------
    p_monitor : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                out_count     <= 0;
                soa_out_count <= 0;
            else
                ----------------------------------------------------------------
                -- These should never assert in the intended operating mode
                ----------------------------------------------------------------
                assert dbg_input_backpressure_violation = '0'
                    report "FFT wrapper saw input valid while FFT input was not ready"
                    severity failure;

                assert dbg_event_tlast_unexpected = '0'
                    report "FFT event_tlast_unexpected asserted"
                    severity failure;

                assert dbg_event_tlast_missing = '0'
                    report "FFT event_tlast_missing asserted"
                    severity failure;

                assert dbg_event_status_channel_halt = '0'
                    report "FFT event_status_channel_halt asserted"
                    severity failure;

                assert dbg_event_data_in_channel_halt = '0'
                    report "FFT event_data_in_channel_halt asserted"
                    severity failure;

                assert dbg_event_data_out_channel_halt = '0'
                    report "FFT event_data_out_channel_halt asserted"
                    severity failure;

                ----------------------------------------------------------------
                -- Output capture / frame-start counting
                ----------------------------------------------------------------
                if out_valid = '1' then
                    out_count <= out_count + 1;

                    if start_of_ascan_out = '1' then
                        soa_out_count <= soa_out_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Optional reporting for waveform/log visibility
    --------------------------------------------------------------------
    p_report : process(clk)
    begin
        if rising_edge(clk) then
            if out_valid = '1' then
                report "FFT OUT re=" & integer'image(to_integer(out_real)) &
                       " im=" & integer'image(to_integer(out_imag)) &
                       " soa=" & std_logic'image(start_of_ascan_out)
                       severity note;
            end if;
        end if;
    end process;

end architecture;