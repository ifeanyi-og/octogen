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
  constant SCALE_Q16 : integer := 2**FRAC_BITS;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal str_in         : std_logic_vector(31 downto 0) := (others => '0');
  signal str_in_valid   : std_logic := '0';
  signal start_of_ascan : std_logic := '0';

  signal str_out            : std_logic_vector(31 downto 0);
  signal str_out_valid      : std_logic;
  signal start_of_ascan_out : std_logic;

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

  signal overflow : std_logic;

  signal exp_frame_idx      : integer := 0;
  signal exp_sample_idx     : integer := 0;
  signal total_outputs_seen : integer := 0;
  signal start_pulse_count  : integer := 0;

begin

  clk <= not clk after CLK_PER/2;

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
      str_in         <= std_logic_vector(to_signed(frame_offset, 32));
      wait for CLK_PER;

      start_of_ascan <= '0';

      for i in 1 to ASCAN_LEN-1 loop
        str_in <= std_logic_vector(to_signed(frame_offset + i, 32));
        wait for CLK_PER;
      end loop;
    end procedure;

    variable c0_q, c1_q, c2_q, c3_q : integer;
  begin
    clear_cal_writes;
    cal_ready       <= '0';
    str_in_valid    <= '0';
    start_of_ascan  <= '0';
    str_in          <= (others => '0');

    rst <= '1';
    wait for 5*CLK_PER;
    rst <= '0';
    wait for 2*CLK_PER;

    report "Writing all-coefficient varying tables..." severity note;

    -- base[m] = m
    for i in 0 to ASCAN_LEN-1 loop
      write_base(i, i);
    end loop;

    -- c0[m] = 6554 + 4*m
    for i in 0 to ASCAN_LEN-1 loop
      c0_q := 6554 + 4*i;
      write_c0(i, c0_q);
    end loop;

    -- c1[m] = 45875 + 2*m
    for i in 0 to ASCAN_LEN-1 loop
      c1_q := 45875 + 2*i;
      write_c1(i, c1_q);
    end loop;

    -- c2[m] = 9830 + i
    for i in 0 to ASCAN_LEN-1 loop
      c2_q := 9830 + i;
      write_c2(i, c2_q);
    end loop;

    -- c3[m] = 3277
    for i in 0 to ASCAN_LEN-1 loop
      c3_q := 3277;
      write_c3(i, c3_q);
    end loop;

    cal_ready <= '1';
    wait for 4*CLK_PER;

    report "Sending frame 0..." severity note;
    send_frame(0);

    report "Sending frame 1 immediately..." severity note;
    send_frame(10000);

    report "Sending frame 2 immediately..." severity note;
    send_frame(20000);

    str_in_valid <= '0';
    start_of_ascan <= '0';
    str_in <= (others => '0');

    wait for 18000*CLK_PER;

    if total_outputs_seen < 3*ASCAN_LEN then
      assert false report "ERROR: Did not observe all outputs for 3 frames."
        severity failure;
    end if;

    if start_pulse_count < 3 then
      assert false report "ERROR: Did not observe 3 start_of_ascan_out pulses."
        severity failure;
    end if;

    if overflow = '1' then
      report "WARNING: overflow asserted during all-coefficient timing test."
        severity warning;
    end if;

    report "All-coefficient varying timing test completed." severity note;
    assert false report "End of simulation." severity failure;
  end process;

  check_proc : process(clk)
    variable y, expected : integer;
    variable base_i      : integer;
    variable x0, x1, x2, x3 : integer;
    variable frame_offset : integer;

    variable c0_q, c1_q, c2_q, c3_q : integer;

    variable x0_64, x1_64, x2_64, x3_64 : signed(63 downto 0);
    variable c0_64, c1_64, c2_64, c3_64 : signed(63 downto 0);
    variable p0_64, p1_64, p2_64, p3_64 : signed(63 downto 0);
    variable sum_64 : signed(63 downto 0);
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

          case exp_frame_idx is
            when 0 => frame_offset := 0;
            when 1 => frame_offset := 10000;
            when 2 => frame_offset := 20000;
            when others => frame_offset := 0;
          end case;

          base_i := exp_sample_idx;

          -- edge-clamped taps
          if base_i-1 < 0 then
            x0 := frame_offset + 0;
          else
            x0 := frame_offset + (base_i-1);
          end if;

          x1 := frame_offset + base_i;

          if base_i+1 > ASCAN_LEN-1 then
            x2 := frame_offset + (ASCAN_LEN-1);
          else
            x2 := frame_offset + (base_i+1);
          end if;

          if base_i+2 > ASCAN_LEN-1 then
            x3 := frame_offset + (ASCAN_LEN-1);
          else
            x3 := frame_offset + (base_i+2);
          end if;

          c0_q := 6554 + 4*exp_sample_idx;
          c1_q := 45875 + 2*exp_sample_idx;
          c2_q := 9830 + exp_sample_idx;
          c3_q := 3277;

          x0_64 := to_signed(x0, 64);
          x1_64 := to_signed(x1, 64);
          x2_64 := to_signed(x2, 64);
          x3_64 := to_signed(x3, 64);

          c0_64 := to_signed(c0_q, 64);
          c1_64 := to_signed(c1_q, 64);
          c2_64 := to_signed(c2_q, 64);
          c3_64 := to_signed(c3_q, 64);

          p0_64 := resize(shift_right(x0_64 * c0_64, FRAC_BITS), 64);
          p1_64 := resize(shift_right(x1_64 * c1_64, FRAC_BITS), 64);
          p2_64 := resize(shift_right(x2_64 * c2_64, FRAC_BITS), 64);
          p3_64 := resize(shift_right(x3_64 * c3_64, FRAC_BITS), 64);

          sum_64 := p0_64 + p1_64 + p2_64 + p3_64;
          expected := to_integer(sum_64);

          if y /= expected then
            report "Mismatch at frame=" & integer'image(exp_frame_idx) &
                   " sample=" & integer'image(exp_sample_idx) &
                   " got=" & integer'image(y) &
                   " expected=" & integer'image(expected)
              severity error;
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