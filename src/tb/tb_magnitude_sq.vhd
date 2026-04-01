library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_mag_sq is
end tb_mag_sq;

architecture sim of tb_mag_sq is

    constant CLK_PER        : time    := 10 ns;
    constant ASCAN_LEN      : integer := 1024;
    constant NUM_ASCANS     : integer := 3;
    constant TOTAL_SAMPLES  : integer := ASCAN_LEN * NUM_ASCANS;

    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal clk                : std_logic := '0';
    signal rst                : std_logic := '1';

    signal re_in              : signed(31 downto 0) := (others => '0');
    signal im_in              : signed(31 downto 0) := (others => '0');
    signal in_valid           : std_logic := '0';
    signal start_of_ascan     : std_logic := '0';

    signal mag_sq_out         : unsigned(64 downto 0);
    signal out_valid          : std_logic;
    signal start_of_ascan_out : std_logic;

begin

    --------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------
    clk <= not clk after CLK_PER / 2;

    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    uut : entity work.mag_calc
        port map (
            clk                => clk,
            rst                => rst,
            re_in              => re_in,
            im_in              => im_in,
            in_valid           => in_valid,
            start_of_ascan     => start_of_ascan,
            mag_sq_out         => mag_sq_out,
            out_valid          => out_valid,
            start_of_ascan_out => start_of_ascan_out
        );

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim_proc : process
        variable sample_idx_global : integer;
        variable sample_idx_ascan  : integer;
        variable ascan_idx         : integer;
        variable re_val            : integer;
        variable im_val            : integer;
    begin
        ----------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------
        rst            <= '1';
        re_in          <= (others => '0');
        im_in          <= (others => '0');
        in_valid       <= '0';
        start_of_ascan <= '0';

        wait for 40 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        ----------------------------------------------------------------
        -- Stream 3 A-scans back-to-back, 1024 samples each
        ----------------------------------------------------------------
        for sample_idx_global in 0 to TOTAL_SAMPLES - 1 loop
            ascan_idx        := sample_idx_global / ASCAN_LEN;
            sample_idx_ascan := sample_idx_global mod ASCAN_LEN;

            -- Deterministic test pattern:
            -- varies with both scan number and sample number
            re_val := (ascan_idx + 1) * 1000 + sample_idx_ascan - 512;
            im_val := ((ascan_idx + 1) * 200) - sample_idx_ascan;

            re_in        <= to_signed(re_val, 32);
            im_in        <= to_signed(im_val, 32);
            in_valid     <= '1';

            if sample_idx_ascan = 0 then
                start_of_ascan <= '1';
            else
                start_of_ascan <= '0';
            end if;

            wait until rising_edge(clk);
        end loop;

        ----------------------------------------------------------------
        -- Stop driving valid after final input sample
        ----------------------------------------------------------------
        re_in          <= (others => '0');
        im_in          <= (others => '0');
        in_valid       <= '0';
        start_of_ascan <= '0';

        -- Let the pipeline drain
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        report "tb_mag_calc completed" severity note;
        wait;
    end process;

    --------------------------------------------------------------------
    -- Self-checking monitor
    --------------------------------------------------------------------
    check_proc : process
        variable in_count            : integer := 0;
        variable out_count           : integer := 0;

        variable exp_ascan_idx       : integer;
        variable exp_sample_idx      : integer;
        variable exp_re_val          : integer;
        variable exp_im_val          : integer;

        variable exp_mag_sq_int      : integer;
        variable exp_mag_sq_unsigned : unsigned(64 downto 0);

        variable exp_soa             : std_logic;
    begin
        wait until rising_edge(clk);

        if rst = '1' then
            in_count  := 0;
            out_count := 0;

        else
            ----------------------------------------------------------------
            -- Count accepted input samples
            ----------------------------------------------------------------
            if in_valid = '1' then
                in_count := in_count + 1;
            end if;

            ----------------------------------------------------------------
            -- Check each output sample as it appears
            ----------------------------------------------------------------
            if out_valid = '1' then
                if out_count >= TOTAL_SAMPLES then
                    assert false
                        report "FAIL: More output samples than expected"
                        severity error;
                end if;

                exp_ascan_idx  := out_count / ASCAN_LEN;
                exp_sample_idx := out_count mod ASCAN_LEN;

                -- Recreate the exact same stimulus pattern
                exp_re_val := (exp_ascan_idx + 1) * 1000 + exp_sample_idx - 512;
                exp_im_val := ((exp_ascan_idx + 1) * 200) - exp_sample_idx;

                exp_mag_sq_int := exp_re_val * exp_re_val +
                                  exp_im_val * exp_im_val;

                exp_mag_sq_unsigned := to_unsigned(exp_mag_sq_int, 65);

                if exp_sample_idx = 0 then
                    exp_soa := '1';
                else
                    exp_soa := '0';
                end if;

                assert mag_sq_out = exp_mag_sq_unsigned
                    report "FAIL: mag_sq mismatch at output sample " &
                           integer'image(out_count) &
                           " (ascan " & integer'image(exp_ascan_idx) &
                           ", sample " & integer'image(exp_sample_idx) & ")"
                    severity error;

                assert start_of_ascan_out = exp_soa
                    report "FAIL: start_of_ascan_out mismatch at output sample " &
                           integer'image(out_count) &
                           " (ascan " & integer'image(exp_ascan_idx) &
                           ", sample " & integer'image(exp_sample_idx) & ")" &
                           " expected=" & std_logic'image(exp_soa) &
                           " got=" & std_logic'image(start_of_ascan_out)
                    severity error;

                out_count := out_count + 1;
            end if;

            ----------------------------------------------------------------
            -- Once pipeline fills, out_valid should keep pace with stream
            -- while input is continuously valid.
            --
            -- We do not hard-fail cycle-by-cycle here during the initial
            -- fill/drain, but at the end we do ensure the exact total count.
            ----------------------------------------------------------------
            if (in_valid = '0') and (out_count = TOTAL_SAMPLES) then
                report "PASS: All " & integer'image(TOTAL_SAMPLES) &
                       " output samples matched expected values and SOA alignment"
                    severity note;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Final output count check
    --------------------------------------------------------------------
    final_check_proc : process
        variable observed_outputs : integer := 0;
    begin
        wait until rst = '0';

        while true loop
            wait until rising_edge(clk);

            if out_valid = '1' then
                observed_outputs := observed_outputs + 1;
            end if;

            if observed_outputs = TOTAL_SAMPLES then
                -- Wait a couple extra clocks to ensure no extra outputs appear
                wait until rising_edge(clk);
                assert out_valid = '0'
                    report "FAIL: Unexpected extra output after expected stream end"
                    severity error;

                wait until rising_edge(clk);
                assert out_valid = '0'
                    report "FAIL: Unexpected extra output after expected stream end"
                    severity error;

                report "PASS: Output count exactly matched expected total of " &
                       integer'image(TOTAL_SAMPLES)
                    severity note;
                wait;
            end if;
        end loop;
    end process;

end sim;