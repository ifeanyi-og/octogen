library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity log_compress_map_tb is
end entity;

architecture tb of log_compress_map_tb is

  --------------------------------------------------------------------------
  -- DUT generics
  --------------------------------------------------------------------------
  constant IN_W          : natural := 32;
  constant SEG_BITS      : natural := 6;
  constant FRAC_BITS     : natural := 6;
  constant LUT_W         : natural := 18;

  constant MAP_FLOOR_Q   : natural := 0;
  constant MAP_GAIN_Q    : natural := 8192;
  constant MAP_GAIN_FRAC : natural := 8;
  constant GAIN_W        : natural := 16;

  --------------------------------------------------------------------------
  -- Clock / reset
  --------------------------------------------------------------------------
  constant CLK_PERIOD : time := 10 ns;

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';

  --------------------------------------------------------------------------
  -- DUT I/O
  --------------------------------------------------------------------------
  signal in_valid  : std_logic := '0';
  signal mag2_in   : std_logic_vector(IN_W-1 downto 0) := (others => '0');

  signal pix_valid : std_logic;
  signal pix_out   : std_logic_vector(7 downto 0);

  --------------------------------------------------------------------------
  -- Optional bookkeeping
  --------------------------------------------------------------------------
  signal sim_done  : std_logic := '0';

begin

  --------------------------------------------------------------------------
  -- Clock generation
  --------------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD/2 when sim_done = '0' else '0';

  --------------------------------------------------------------------------
  -- DUT instantiation
  --------------------------------------------------------------------------
  uut : entity work.log_compress_map
    generic map (
      IN_W          => IN_W,
      SEG_BITS      => SEG_BITS,
      FRAC_BITS     => FRAC_BITS,
      LUT_W         => LUT_W,
      MAP_FLOOR_Q   => MAP_FLOOR_Q,
      MAP_GAIN_Q    => MAP_GAIN_Q,
      MAP_GAIN_FRAC => MAP_GAIN_FRAC,
      GAIN_W        => GAIN_W
    )
    port map (
      clk       => clk,
      rst       => rst,
      in_valid  => in_valid,
      mag2_in   => mag2_in,
      pix_valid => pix_valid,
      pix_out   => pix_out
    );

  --------------------------------------------------------------------------
  -- Simple monitor
  --------------------------------------------------------------------------
  monitor_proc : process(clk)
  begin
    if rising_edge(clk) then
      if pix_valid = '1' then
        report "OUTPUT  pix_out=" & integer'image(to_integer(unsigned(pix_out)));
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Stimulus
  --------------------------------------------------------------------------
  stim_proc : process

    procedure apply_sample(x : natural) is
    begin
      mag2_in  <= std_logic_vector(to_unsigned(x, IN_W));
      in_valid <= '1';
      wait until rising_edge(clk);

      in_valid <= '0';
      mag2_in  <= (others => '0');

      -- Wait long enough for pipelined output to appear.
      -- Current RTL looks roughly 4 cycles deep.
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    end procedure;

  begin
    ------------------------------------------------------------------------
    -- Reset
    ------------------------------------------------------------------------
    rst      <= '1';
    in_valid <= '0';
    mag2_in  <= (others => '0');

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    rst <= '0';
    wait until rising_edge(clk);

    report "======================================================";
    report "Starting directed tests";
    report "======================================================";

    ----------------------------------------------------------------------
    --Directed tests
    ----------------------------------------------------------------------
--    apply_sample(0);       -- should map to black
--    apply_sample(1);
--    apply_sample(2);
--    apply_sample(3);
--    apply_sample(4);
--    apply_sample(7);
--    apply_sample(8);
--    apply_sample(15);
--    apply_sample(16);
--    apply_sample(31);
--    apply_sample(32);
--    apply_sample(63);
--    apply_sample(64);
--    apply_sample(127);
--    apply_sample(128);
--    apply_sample(255);
--    apply_sample(256);
--    apply_sample(511);
--    apply_sample(512);
--    apply_sample(1023);
--    apply_sample(1024);
--    apply_sample(1900);
--    apply_sample(2000);
--    apply_sample(4096);
--    apply_sample(65535);
--    apply_sample(1000000);

    report "======================================================";
    report "Starting ramp test";
    report "======================================================";

    ------------------------------------------------------------------------
    -- Small ramp test
    ------------------------------------------------------------------------
    for i in 1 to 32 loop
      apply_sample(i);
    end loop;

    report "======================================================";
    report "Starting powers-of-two test";
    report "======================================================";

    ------------------------------------------------------------------------
    -- Powers-of-two and neighbors
    ------------------------------------------------------------------------
    apply_sample(1023);
    apply_sample(1024);
    apply_sample(1025);

    apply_sample(2047);
    apply_sample(2048);
    apply_sample(2049);

    apply_sample(4095);
    apply_sample(4096);
    apply_sample(4097);
    

    report "======================================================";
    report "Simulation finished";
    report "======================================================";

    sim_done <= '1';
    wait;
  end process;

end architecture;