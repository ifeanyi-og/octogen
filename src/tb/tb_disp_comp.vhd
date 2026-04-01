library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_disp_comp is
end entity;

architecture sim of tb_disp_comp is

  -- ==========================================================================
  -- DUT configuration
  -- ==========================================================================
  constant ASCAN_LEN : natural := 1024;
  constant N_FRAMES  : natural := 3;
  constant TOTAL_SAMPLES : natural := ASCAN_LEN * N_FRAMES;

  constant ADDR_W    : natural := 10;
  constant IN_W      : natural := 32;
  constant X_W       : natural := 24;
  constant LUT_W     : natural := 18;
  constant LUT_FRAC  : natural := 17;
  constant SHIFT_IN  : natural := 8;
  constant RAM_LAT   : natural := 1;

  constant LAT_EXPECTED : natural := RAM_LAT + 3;

  constant CLK_PERIOD : time := 10 ns;

  subtype s32 is signed(IN_W-1 downto 0);

  -- ==========================================================================
  -- Per-frame amplitudes
  -- ==========================================================================
  type frame_amp_arr_t is array (0 to N_FRAMES-1) of integer;
  constant FRAME_AMPS : frame_amp_arr_t := (
    2000000,   -- frame 0
    1000000,   -- frame 1
   -1500000    -- frame 2
  );

  -- ==========================================================================
  -- Signals
  -- ==========================================================================
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal in_x           : std_logic_vector(IN_W-1 downto 0) := (others => '0');
  signal in_valid       : std_logic := '0';
  signal start_of_ascan : std_logic := '0';

  signal lut_wr_en   : std_logic := '0';
  signal lut_wr_addr : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal lut_cos_din : std_logic_vector(LUT_W-1 downto 0) := (others => '0');
  signal lut_sin_din : std_logic_vector(LUT_W-1 downto 0) := (others => '0');

  signal out_re             : std_logic_vector(IN_W-1 downto 0);
  signal out_im             : std_logic_vector(IN_W-1 downto 0);
  signal out_valid          : std_logic;
  signal start_of_ascan_out : std_logic;
  signal end_of_ascan_out   : std_logic;

  -- ==========================================================================
  -- Expected FIFO / queue
  -- ==========================================================================
  constant FIFO_DEPTH : natural := TOTAL_SAMPLES + 128;

  type fifo_s32_t is array (0 to FIFO_DEPTH-1) of s32;
  type fifo_nat_t is array (0 to FIFO_DEPTH-1) of natural;
  type fifo_sl_t  is array (0 to FIFO_DEPTH-1) of std_logic;

  signal exp_re_fifo  : fifo_s32_t := (others => (others => '0'));
  signal exp_im_fifo  : fifo_s32_t := (others => (others => '0'));
  signal exp_soa_fifo : fifo_sl_t  := (others => '0');
  signal exp_eoa_fifo : fifo_sl_t  := (others => '0');
  signal t_in_fifo    : fifo_nat_t := (others => 0);

  signal wr_ptr : natural range 0 to FIFO_DEPTH-1 := 0;
  signal rd_ptr : natural range 0 to FIFO_DEPTH-1 := 0;
  signal count  : natural range 0 to FIFO_DEPTH   := 0;

  signal cycle_count : natural := 0;

  signal tb_frame_idx  : natural range 0 to N_FRAMES := 0;
  signal tb_sample_idx : natural range 0 to ASCAN_LEN := 0;

  -- ==========================================================================
  -- Helper functions
  -- ==========================================================================
  function round_shift_signed(x : signed; SHIFT : natural) return signed is
    variable xv   : signed(x'length-1 downto 0) := x;
    variable bias : signed(x'length-1 downto 0) := (others => '0');
    variable yv   : signed(x'length-1 downto 0);
  begin
    if SHIFT = 0 then
      return xv;
    end if;

    bias(SHIFT-1) := '1';

    if xv(xv'high) = '0' then
      yv := xv + bias;
    else
      yv := xv - bias;
    end if;

    return shift_right(yv, SHIFT);
  end function;

  function q17(x : real) return integer is
    variable v : integer;
    constant MAXPOS : integer :=  2**(LUT_W-1) - 1;
    constant MINNEG : integer := -2**(LUT_W-1);
  begin
    v := integer(round(x * real(2**LUT_FRAC)));
    if v > MAXPOS then
      v := MAXPOS;
    elsif v < MINNEG then
      v := MINNEG;
    end if;
    return v;
  end function;

  function cos32(idx : natural) return integer is
    variable phase : real;
  begin
    phase := 2.0 * math_pi * real(idx mod 32) / 32.0;
    return q17(cos(phase));
  end function;

  function sin32(idx : natural) return integer is
    variable phase : real;
  begin
    phase := 2.0 * math_pi * real(idx mod 32) / 32.0;
    return q17(sin(phase));
  end function;

begin

  -- ==========================================================================
  -- Clock
  -- ==========================================================================
  clk <= not clk after CLK_PERIOD/2;

  -- ==========================================================================
  -- DUT
  -- ==========================================================================
  dut : entity work.disp_comp
    generic map (
      ASCAN_LEN => ASCAN_LEN,
      ADDR_W    => ADDR_W,
      IN_W      => IN_W,
      X_W       => X_W,
      LUT_W     => LUT_W,
      LUT_FRAC  => LUT_FRAC,
      SHIFT_IN  => SHIFT_IN,
      RAM_LAT   => RAM_LAT
    )
    port map (
      clk   => clk,
      rst   => rst,

      in_x           => in_x,
      in_valid       => in_valid,
      start_of_ascan => start_of_ascan,

      lut_wr_en   => lut_wr_en,
      lut_wr_addr => lut_wr_addr,
      lut_cos_din => lut_cos_din,
      lut_sin_din => lut_sin_din,

      out_re             => out_re,
      out_im             => out_im,
      out_valid          => out_valid,
      start_of_ascan_out => start_of_ascan_out,
      end_of_ascan_out   => end_of_ascan_out
    );

  -- ==========================================================================
  -- Global cycle counter
  -- ==========================================================================
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cycle_count <= 0;
      else
        cycle_count <= cycle_count + 1;
      end if;
    end if;
  end process;

  -- ==========================================================================
  -- MAIN STIMULUS
  -- ==========================================================================
  process
    variable x32 : s32;
  begin
    ---------------------------------------------------------------------------
    -- STAGE 1: RESET
    ---------------------------------------------------------------------------
    report "TB Stage 1: Applying reset" severity note;

    rst <= '1';
    in_valid <= '0';
    start_of_ascan <= '0';
    in_x <= (others => '0');

    lut_wr_en <= '0';
    lut_wr_addr <= (others => '0');
    lut_cos_din <= (others => '0');
    lut_sin_din <= (others => '0');

    tb_frame_idx <= 0;
    tb_sample_idx <= 0;

    wait for 100 ns;
    wait until rising_edge(clk);
    rst <= '0';

    ---------------------------------------------------------------------------
    -- STAGE 2: WRITE ROTATING PHASOR LUT
    ---------------------------------------------------------------------------
    report "TB Stage 2: Writing rotating phasor LUT into BRAM" severity note;

    for i in 0 to ASCAN_LEN-1 loop
      wait until rising_edge(clk);
      lut_wr_en   <= '1';
      lut_wr_addr <= std_logic_vector(to_unsigned(i, ADDR_W));
      lut_cos_din <= std_logic_vector(to_signed(cos32(i), LUT_W));
      lut_sin_din <= std_logic_vector(to_signed(sin32(i), LUT_W));
    end loop;

    wait until rising_edge(clk);
    lut_wr_en   <= '0';
    lut_wr_addr <= (others => '0');
    lut_cos_din <= (others => '0');
    lut_sin_din <= (others => '0');

    ---------------------------------------------------------------------------
    -- STAGE 3: WAIT AFTER WRITE PHASE
    ---------------------------------------------------------------------------
    report "TB Stage 3: Waiting after LUT writes before streaming begins" severity note;

    wait until rising_edge(clk);
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- STAGE 4: DRIVE 3 BACK-TO-BACK A-SCANS WITH DIFFERENT AMPLITUDES
    ---------------------------------------------------------------------------
    report "TB Stage 4: Driving 3 back-to-back A-scans with varying amplitudes" severity note;
    report "  -> Frame 0 amplitude = 2000000" severity note;
    report "  -> Frame 1 amplitude = 1000000" severity note;
    report "  -> Frame 2 amplitude = -1500000" severity note;

    for f in 0 to N_FRAMES-1 loop
      report "  -> Starting frame " & integer'image(f) severity note;
      x32 := to_signed(FRAME_AMPS(f), IN_W);

      for n in 0 to ASCAN_LEN-1 loop
        wait until rising_edge(clk);

        in_valid <= '1';
        in_x <= std_logic_vector(x32);

        tb_frame_idx <= f;
        tb_sample_idx <= n;

        if n = 0 then
          start_of_ascan <= '1';
        else
          start_of_ascan <= '0';
        end if;
      end loop;
    end loop;

    ---------------------------------------------------------------------------
    -- STAGE 5: STOP INPUT AND DRAIN PIPELINE
    ---------------------------------------------------------------------------
    report "TB Stage 5: Stopping input stream and draining pipeline" severity note;

    wait until rising_edge(clk);
    in_valid <= '0';
    start_of_ascan <= '0';
    in_x <= (others => '0');
    tb_frame_idx <= 0;
    tb_sample_idx <= 0;

    wait for 2500 ns;

    report "TB completed successfully" severity note;
    assert false report "TB completed successfully" severity failure;
  end process;

  -- ==========================================================================
  -- QUEUE MANAGER
  -- ==========================================================================
  process(clk)
    variable x32       : s32;
    variable x24       : signed(X_W-1 downto 0);
    variable cosv      : signed(LUT_W-1 downto 0);
    variable sinv      : signed(LUT_W-1 downto 0);
    variable prod_re   : signed(X_W+LUT_W-1 downto 0);
    variable prod_im   : signed(X_W+LUT_W-1 downto 0);
    variable re_rs     : signed(X_W+LUT_W-1 downto 0);
    variable im_rs     : signed(X_W+LUT_W-1 downto 0);
    variable re32      : s32;
    variable im32      : s32;

    variable wr_next    : natural;
    variable rd_next    : natural;
    variable count_next : natural;
    variable lat        : natural;
    variable idx_mod32  : natural;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wr_ptr <= 0;
        rd_ptr <= 0;
        count  <= 0;
      else
        wr_next    := wr_ptr;
        rd_next    := rd_ptr;
        count_next := count;

        -----------------------------------------------------------------------
        -- ENQUEUE EXPECTED SAMPLE
        -----------------------------------------------------------------------
        if in_valid = '1' then
          assert count_next < FIFO_DEPTH
            report "Expected FIFO overflow" severity failure;

          x32 := signed(in_x);
          x24 := resize(shift_right(x32, SHIFT_IN), X_W);

          idx_mod32 := tb_sample_idx mod 32;
          cosv := to_signed(cos32(idx_mod32), LUT_W);
          sinv := to_signed(sin32(idx_mod32), LUT_W);

          prod_re := resize(x24 * cosv, prod_re'length);
          prod_im := resize(-(x24 * sinv), prod_im'length);

          re_rs := round_shift_signed(prod_re, LUT_FRAC);
          im_rs := round_shift_signed(prod_im, LUT_FRAC);

          re32 := resize(resize(re_rs, X_W), IN_W);
          im32 := resize(resize(im_rs, X_W), IN_W);

          exp_re_fifo(wr_ptr) <= re32;
          exp_im_fifo(wr_ptr) <= im32;

          if tb_sample_idx = 0 then
            exp_soa_fifo(wr_ptr) <= '1';
          else
            exp_soa_fifo(wr_ptr) <= '0';
          end if;

          if tb_sample_idx = ASCAN_LEN-1 then
            exp_eoa_fifo(wr_ptr) <= '1';
          else
            exp_eoa_fifo(wr_ptr) <= '0';
          end if;

          t_in_fifo(wr_ptr) <= cycle_count;

          if wr_ptr = FIFO_DEPTH-1 then
            wr_next := 0;
          else
            wr_next := wr_ptr + 1;
          end if;

          count_next := count_next + 1;
        end if;

        -----------------------------------------------------------------------
        -- DEQUEUE AND CHECK OUTPUT
        -----------------------------------------------------------------------
        if out_valid = '1' then
          assert count_next > 0
            report "Expected FIFO underflow" severity failure;

          assert signed(out_re) = exp_re_fifo(rd_ptr)
            report "Mismatch RE" severity error;

          assert signed(out_im) = exp_im_fifo(rd_ptr)
            report "Mismatch IM" severity error;

          assert start_of_ascan_out = exp_soa_fifo(rd_ptr)
            report "Mismatch start_of_ascan_out" severity error;

          assert end_of_ascan_out = exp_eoa_fifo(rd_ptr)
            report "Mismatch end_of_ascan_out" severity error;

          lat := cycle_count - t_in_fifo(rd_ptr);
          assert lat = LAT_EXPECTED
            report "Latency mismatch: expected " & integer'image(LAT_EXPECTED) &
                   " got " & integer'image(lat)
            severity error;

          if rd_ptr = FIFO_DEPTH-1 then
            rd_next := 0;
          else
            rd_next := rd_ptr + 1;
          end if;

          count_next := count_next - 1;
        end if;

        wr_ptr <= wr_next;
        rd_ptr <= rd_next;
        count  <= count_next;
      end if;
    end if;
  end process;

  -- ==========================================================================
  -- THROUGHPUT CHECK
  -- ==========================================================================
  process(clk)
    variable seen_first_out : boolean := false;
    variable out_count      : natural := 0;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        seen_first_out := false;
        out_count := 0;
      else
        if out_valid = '1' then
          if not seen_first_out then
            report "TB Throughput Check: first valid output observed" severity note;
          end if;

          seen_first_out := true;
          out_count := out_count + 1;

        elsif seen_first_out and out_count < TOTAL_SAMPLES then
          assert false
            report "Gap detected in out_valid during continuous multi-frame output stream"
            severity error;
        end if;
      end if;
    end if;
  end process;

end architecture;