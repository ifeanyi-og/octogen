library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_k_lin is
end entity;

architecture sim of tb_k_lin is

  constant CLK_PER   : time := 10 ns;
  constant ASCAN_LEN : integer := 1024;
  constant ADDR_W    : integer := 10;
  constant COEF_W    : integer := 18;
  constant FRAC_BITS : integer := 16;
  constant ONE_Q16   : integer := 2**FRAC_BITS;  -- 65536

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  -- Streaming input
  signal str_in         : std_logic_vector(31 downto 0) := (others => '0');
  signal str_in_valid   : std_logic := '0';
  signal start_of_ascan : std_logic := '0';

  -- Streaming output
  signal str_out            : std_logic_vector(31 downto 0);
  signal str_out_valid      : std_logic;
  signal start_of_ascan_out : std_logic;

  -- Calibration interface
  signal cal_ready           : std_logic := '0';
  signal cal_write_addr      : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');

  signal cal_base_write_en   : std_logic := '0';
  signal cal_base_write_data : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');

  signal cal_c0_write_en     : std_logic := '0';
  signal cal_c0_write_data   : std_logic_vector(COEF_W-1 downto 0) := (others => '0');

  signal cal_c1_write_en     : std_logic := '0';
  signal cal_c1_write_data   : std_logic_vector(COEF_W-1 downto 0) := (others => '0');

  signal cal_c2_write_en     : std_logic := '0';
  signal cal_c2_write_data   : std_logic_vector(COEF_W-1 downto 0) := (others => '0');

  signal cal_c3_write_en     : std_logic := '0';
  signal cal_c3_write_data   : std_logic_vector(COEF_W-1 downto 0) := (others => '0');

  -- Status
  signal overflow : std_logic;

  -- Scoreboard
  signal exp_frame_idx      : integer := 0;
  signal exp_sample_idx     : integer := 0;
  signal total_outputs_seen : integer := 0;
  signal start_pulse_count  : integer := 0;
  signal overflow_seen      : std_logic := '0';

begin

  --------------------------------------------------------------------------
  -- Clock
  --------------------------------------------------------------------------
  clk <= not clk after CLK_PER/2;

  --------------------------------------------------------------------------
  -- DUT
  --------------------------------------------------------------------------
  dut : entity work.k_lin
    generic map (
      ASCAN_LEN => ASCAN_LEN,
      ADDR_W    => ADDR_W,
      COEF_W    => COEF_W,
      FRAC_BITS => FRAC_BITS,
      COEF_LAT  => 2,
      SAMP_LAT  => 2
    )
    port map (
      clk => clk,
      rst => rst,

      str_in => str_in,
      str_in_valid => str_in_valid,
      start_of_ascan => start_of_ascan,

      str_out => str_out,
      str_out_valid => str_out_valid,
      start_of_ascan_out => start_of_ascan_out,

      cal_ready => cal_ready,
      cal_write_addr => cal_write_addr,

      cal_base_write_en => cal_base_write_en,
      cal_base_write_data => cal_base_write_data,

      cal_c0_write_en => cal_c0_write_en,
      cal_c0_write_data => cal_c0_write_data,

      cal_c1_write_en => cal_c1_write_en,
      cal_c1_write_data => cal_c1_write_data,

      cal_c2_write_en => cal_c2_write_en,
      cal_c2_write_data => cal_c2_write_data,

      cal_c3_write_en => cal_c3_write_en,
      cal_c3_write_data => cal_c3_write_data,

      overflow => overflow
    );

  --------------------------------------------------------------------------
  -- Stimulus
  --------------------------------------------------------------------------
  stim_proc : process
    procedure clear_cal_writes is
    begin
      cal_base_write_en <= '0';
      cal_c0_write_en   <= '0';
      cal_c1_write_en   <= '0';
      cal_c2_write_en   <= '0';
      cal_c3_write_en   <= '0';
    end procedure;

    procedure write_base(addr_i : integer; data_i : integer) is
    begin
      cal_write_addr       <= std_logic_vector(to_unsigned(addr_i, ADDR_W));
      cal_base_write_data  <= std_logic_vector(to_unsigned(data_i, ADDR_W));
      cal_base_write_en    <= '1';
      wait for CLK_PER;
      cal_base_write_en    <= '0';
      wait for CLK_PER;
    end procedure;

    procedure write_c0(addr_i : integer; data_i : integer) is
    begin
      cal_write_addr      <= std_logic_vector(to_unsigned(addr_i, ADDR_W));
      cal_c0_write_data   <= std_logic_vector(to_signed(data_i, COEF_W));
      cal_c0_write_en     <= '1';
      wait for CLK_PER;
      cal_c0_write_en     <= '0';
      wait for CLK_PER;
    end procedure;

    procedure write_c1(addr_i : integer; data_i : integer) is
    begin
      cal_write_addr      <= std_logic_vector(to_unsigned(addr_i, ADDR_W));
      cal_c1_write_data   <= std_logic_vector(to_signed(data_i, COEF_W));
      cal_c1_write_en     <= '1';
      wait for CLK_PER;
      cal_c1_write_en     <= '0';
      wait for CLK_PER;
    end procedure;

    procedure write_c2(addr_i : integer; data_i : integer) is
    begin
      cal_write_addr      <= std_logic_vector(to_unsigned(addr_i, ADDR_W));
      cal_c2_write_data   <= std_logic_vector(to_signed(data_i, COEF_W));
      cal_c2_write_en     <= '1';
      wait for CLK_PER;
      cal_c2_write_en     <= '0';
      wait for CLK_PER;
    end procedure;

    procedure write_c3(addr_i : integer; data_i : integer) is
    begin
      cal_write_addr      <= std_logic_vector(to_unsigned(addr_i, ADDR_W));
      cal_c3_write_data   <= std_logic_vector(to_signed(data_i, COEF_W));
      cal_c3_write_en     <= '1';
      wait for CLK_PER;
      cal_c3_write_en     <= '0';
      wait for CLK_PER;
    end procedure;

    procedure send_frame(frame_offset : integer) is
    begin
      str_in_valid   <= '1';
      start_of_ascan <= '1';
      str_in         <= std_logic_vector(to_signed(frame_offset + 0, 32));
      wait for CLK_PER;

      start_of_ascan <= '0';

      for i in 1 to ASCAN_LEN-1 loop
        str_in <= std_logic_vector(to_signed(frame_offset + i, 32));
        wait for CLK_PER;
      end loop;
    end procedure;

  begin
    ------------------------------------------------------------------------
    -- Initial defaults
    ------------------------------------------------------------------------
    clear_cal_writes;
    cal_ready       <= '0';
    str_in_valid    <= '0';
    start_of_ascan  <= '0';
    str_in          <= (others => '0');

    ------------------------------------------------------------------------
    -- Reset
    ------------------------------------------------------------------------
    rst <= '1';
    wait for 5*CLK_PER;
    rst <= '0';
    wait for 2*CLK_PER;

    ------------------------------------------------------------------------
    -- Upload identity calibration
    ------------------------------------------------------------------------
    report "Writing calibration tables..." severity note;

    for i in 0 to ASCAN_LEN-1 loop
      write_base(i, i);
    end loop;

    for i in 0 to ASCAN_LEN-1 loop
      write_c0(i, 0);
    end loop;

    for i in 0 to ASCAN_LEN-1 loop
      write_c1(i, ONE_Q16);
    end loop;

    for i in 0 to ASCAN_LEN-1 loop
      write_c2(i, 0);
    end loop;

    for i in 0 to ASCAN_LEN-1 loop
      write_c3(i, 0);
    end loop;

    cal_ready <= '1';
    wait for 4*CLK_PER;

    ------------------------------------------------------------------------
    -- Five full frames with zero inter-frame gap
    ------------------------------------------------------------------------
    report "Sending frame 0..." severity note;
    send_frame(0);

    report "Sending frame 1 immediately..." severity note;
    send_frame(10000);

    report "Sending frame 2 immediately..." severity note;
    send_frame(20000);

    report "Sending frame 3 immediately..." severity note;
    send_frame(30000);

    report "Sending frame 4 immediately..." severity note;
    send_frame(40000);

    -- End input stream
    str_in_valid <= '0';
    start_of_ascan <= '0';
    str_in <= (others => '0');

    ------------------------------------------------------------------------
    -- Let outputs flush
    ------------------------------------------------------------------------
    wait for 20000*CLK_PER;

    if total_outputs_seen < 3*ASCAN_LEN then
      assert false report "ERROR: Did not observe all outputs for first three frames."
        severity failure;
    end if;

    if start_pulse_count < 3 then
      assert false report "ERROR: Did not observe three start_of_ascan_out pulses."
        severity failure;
    end if;

    if overflow_seen = '0' then
      report "WARNING: overflow never asserted under five-frame zero-gap stress."
        severity warning;
    else
      report "Overflow asserted under five-frame zero-gap stress."
        severity note;
    end if;

    report "Five-frame zero-gap stress simulation completed." severity note;
    assert false report "End of simulation." severity failure;
  end process;

  --------------------------------------------------------------------------
  -- Overflow tracker
  --------------------------------------------------------------------------
  overflow_track_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        overflow_seen <= '0';
      else
        if overflow = '1' then
          overflow_seen <= '1';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Output checker
  --------------------------------------------------------------------------
  check_proc : process(clk)
    variable y        : integer;
    variable expected : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        exp_frame_idx      <= 0;
        exp_sample_idx     <= 0;
        total_outputs_seen <= 0;
        start_pulse_count  <= 0;
      else
        if str_out_valid = '1' then
          y := to_integer(signed(str_out));

          -- Strictly score first 3 frames
          case exp_frame_idx is
            when 0 => expected := exp_sample_idx;
            when 1 => expected := 10000 + exp_sample_idx;
            when 2 => expected := 20000 + exp_sample_idx;
            when others => expected := y;
          end case;

          if exp_frame_idx < 3 then
            if y /= expected then
              report "Mismatch at frame=" & integer'image(exp_frame_idx) &
                     " sample=" & integer'image(exp_sample_idx) &
                     " got=" & integer'image(y) &
                     " expected=" & integer'image(expected)
                severity error;
            end if;
          end if;

          if exp_sample_idx = 0 then
            if start_of_ascan_out /= '1' then
              report "ERROR: start_of_ascan_out not asserted on first output sample of frame "
                     & integer'image(exp_frame_idx)
                severity error;
            else
              start_pulse_count <= start_pulse_count + 1;
            end if;
          else
            if start_of_ascan_out /= '0' then
              report "ERROR: start_of_ascan_out asserted mid-frame at frame="
                     & integer'image(exp_frame_idx) &
                     " sample=" & integer'image(exp_sample_idx)
                severity error;
            end if;
          end if;

          total_outputs_seen <= total_outputs_seen + 1;

          if exp_sample_idx = ASCAN_LEN-1 then
            exp_sample_idx <= 0;
            exp_frame_idx  <= exp_frame_idx + 1;
          else
            exp_sample_idx <= exp_sample_idx + 1;
          end if;

        else
          if start_of_ascan_out = '1' then
            report "ERROR: start_of_ascan_out asserted when str_out_valid = 0."
              severity error;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture;