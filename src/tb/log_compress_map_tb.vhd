library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity log_compress_map_tb is
end entity;

architecture tb of log_compress_map_tb is

  --------------------------------------------------------------------------
  -- DUT configuration
  --------------------------------------------------------------------------
  constant IN_W             : natural := 32;
  constant SEG_BITS         : natural := 6;
  constant FRAC_BITS        : natural := 6;
  constant LUT_W            : natural := 18;

  constant MAP_FLOOR_Q      : natural := 0;
  constant MAP_GAIN_Q       : natural := 8192;
  constant MAP_GAIN_FRAC    : natural := 8;
  constant GAIN_W           : natural := 16;

  constant ASCAN_LEN        : natural := 1024;
  constant NUM_ASCANS       : natural := 3;

  -- Current block latency is about 5 clocks
  constant DUT_LATENCY      : natural := 5;

  --------------------------------------------------------------------------
  -- Clock/reset
  --------------------------------------------------------------------------
  constant CLK_PERIOD : time := 10 ns;

  signal clk                 : std_logic := '0';
  signal rst                 : std_logic := '1';
  signal sim_done            : std_logic := '0';

  --------------------------------------------------------------------------
  -- DUT I/O
  --------------------------------------------------------------------------
  signal in_valid            : std_logic := '0';
  signal start_of_ascan      : std_logic := '0';
  signal mag2_in             : std_logic_vector(IN_W-1 downto 0) := (others => '0');

  signal pix_valid           : std_logic;
  signal start_of_ascan_out  : std_logic;
  signal pix_out             : std_logic_vector(7 downto 0);

  --------------------------------------------------------------------------
  -- Scoreboard / counters
  --------------------------------------------------------------------------
  signal in_count            : natural := 0;
  signal out_count           : natural := 0;
  signal in_ascan_count      : natural := 0;
  signal out_ascan_count     : natural := 0;

begin

  --------------------------------------------------------------------------
  -- Clock generation
  --------------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD/2 when sim_done = '0' else '0';

  --------------------------------------------------------------------------
  -- DUT
  --------------------------------------------------------------------------
  uut : entity work.log_compress_map
    generic map (
      IN_W             => IN_W,
      SEG_BITS         => SEG_BITS,
      FRAC_BITS        => FRAC_BITS,
      LUT_W            => LUT_W,
      MAP_FLOOR_Q      => MAP_FLOOR_Q,
      MAP_GAIN_Q       => MAP_GAIN_Q,
      MAP_GAIN_FRAC    => MAP_GAIN_FRAC,
      GAIN_W           => GAIN_W
    )
    port map (
      clk                 => clk,
      rst                 => rst,
      in_valid            => in_valid,
      start_of_ascan      => start_of_ascan,
      mag2_in             => mag2_in,
      pix_valid           => pix_valid,
      start_of_ascan_out  => start_of_ascan_out,
      pix_out             => pix_out
    );

  --------------------------------------------------------------------------
  -- Input-side counting
  --------------------------------------------------------------------------
  input_monitor_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        in_count       <= 0;
        in_ascan_count <= 0;
      else
        if in_valid = '1' then
          in_count <= in_count + 1;

          if start_of_ascan = '1' then
            in_ascan_count <= in_ascan_count + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Output-side checking / counting
  --------------------------------------------------------------------------
  output_monitor_proc : process(clk)
    variable expected_out_ascan_index : natural;
    variable expected_out_sample_idx  : natural;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        out_count       <= 0;
        out_ascan_count <= 0;
      else
        if pix_valid = '1' then
          -- Count outputs
          out_count <= out_count + 1;

          -- Figure out where we are in the output stream
          expected_out_ascan_index := out_count / ASCAN_LEN;
          expected_out_sample_idx  := out_count mod ASCAN_LEN;

          -- Check start_of_ascan_out alignment
          if expected_out_sample_idx = 0 then
            assert start_of_ascan_out = '1'
              report "ERROR: start_of_ascan_out missing on first sample of output A-scan "
                     & integer'image(expected_out_ascan_index)
              severity failure;
          else
            assert start_of_ascan_out = '0'
              report "ERROR: start_of_ascan_out asserted on non-first output sample. "
                     & "Output sample index within A-scan = "
                     & integer'image(expected_out_sample_idx)
              severity failure;
          end if;

          if start_of_ascan_out = '1' then
            out_ascan_count <= out_ascan_count + 1;
          end if;

          -- Optional logging at boundaries
          if expected_out_sample_idx = 0 then
            report "OUTPUT A-scan start detected. ascan="
                   & integer'image(expected_out_ascan_index)
                   & " pix_out=" & integer'image(to_integer(unsigned(pix_out)));
          end if;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Main stimulus
  --------------------------------------------------------------------------
  stim_proc : process
    variable sample_val : natural;
  begin
    ------------------------------------------------------------------------
    -- Reset
    ------------------------------------------------------------------------
    in_valid       <= '0';
    start_of_ascan <= '0';
    mag2_in        <= (others => '0');

    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    report "======================================================";
    report "Starting continuous-stream test";
    report "ASCAN_LEN  = " & integer'image(ASCAN_LEN);
    report "NUM_ASCANS = " & integer'image(NUM_ASCANS);
    report "======================================================";

    ------------------------------------------------------------------------
    -- Stream multiple A-scans back-to-back, 1 sample/clock
    ------------------------------------------------------------------------
    for a in 0 to NUM_ASCANS-1 loop
      for i in 0 to ASCAN_LEN-1 loop
        in_valid <= '1';

        if i = 0 then
          start_of_ascan <= '1';
        else
          start_of_ascan <= '0';
        end if;

        -- Use a deterministic positive pattern with variation.
        -- Keep away from zero most of the time so the log path is exercised.
        sample_val := 1 + ((a * ASCAN_LEN + i) mod 5000);

        mag2_in <= std_logic_vector(to_unsigned(sample_val, IN_W));

        wait until rising_edge(clk);
      end loop;
    end loop;

    ------------------------------------------------------------------------
    -- Stop inputs, flush pipeline
    ------------------------------------------------------------------------
    in_valid       <= '0';
    start_of_ascan <= '0';
    mag2_in        <= (others => '0');

    for k in 0 to DUT_LATENCY + 4 loop
      wait until rising_edge(clk);
    end loop;

    report "======================================================";
    report "Input count      = " & integer'image(in_count);
    report "Output count     = " & integer'image(out_count);
    report "Input A-scan cnt = " & integer'image(in_ascan_count);
    report "Output A-scan cnt= " & integer'image(out_ascan_count);
    report "======================================================";

    ------------------------------------------------------------------------
    -- Final checks
    ------------------------------------------------------------------------
    assert in_count = ASCAN_LEN * NUM_ASCANS
      report "ERROR: Input count mismatch."
      severity failure;

    assert out_count = ASCAN_LEN * NUM_ASCANS
      report "ERROR: Output count mismatch. Expected "
             & integer'image(ASCAN_LEN * NUM_ASCANS)
             & ", got " & integer'image(out_count)
      severity failure;

    assert in_ascan_count = NUM_ASCANS
      report "ERROR: Input start_of_ascan count mismatch."
      severity failure;

    assert out_ascan_count = NUM_ASCANS
      report "ERROR: Output start_of_ascan_out count mismatch."
      severity failure;

    report "======================================================";
    report "PASS: Continuous 1-sample/clock streaming test completed";
    report "======================================================";

    sim_done <= '1';
    wait;
  end process;

end architecture;