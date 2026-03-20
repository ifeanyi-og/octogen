library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity log_compress_map is
  generic (
    IN_W             : natural := 32;

    -- LUT structure
    SEG_BITS         : natural := 6;   -- 64 segments
    FRAC_BITS        : natural := 6;   -- 64 interpolation steps/segment
    LUT_W            : natural := 18;  -- Q0.18 ROM contents

    -- Grayscale mapping:
    -- gray = sat_0_255( ((log2_full - MAP_FLOOR_Q) * MAP_GAIN_Q) >> MAP_GAIN_FRAC )
    --
    -- MAP_FLOOR_Q is in the same scale as log2_full:
    --   log2_full = unsigned integer bits + LUT_W fractional bits
    --
    -- Example:
    --   if LUT_W=18, then a floor of 4.0 log2 units would be:
    --     MAP_FLOOR_Q = 4 * 2^18 = 1048576
    --
    MAP_FLOOR_Q      : natural := 0;
    MAP_GAIN_Q       : natural := 8192; -- example only; tune later
    MAP_GAIN_FRAC    : natural := 8;
    GAIN_W           : natural := 16
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    in_valid   : in  std_logic;
    mag2_in    : in  std_logic_vector(IN_W-1 downto 0);

    pix_valid  : out std_logic;
    pix_out    : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of log_compress_map is

  ------------------------------------------------------------------------------
  -- Helper functions
  ------------------------------------------------------------------------------

  function clog2(n : natural) return natural is
    variable v : natural := 1;
    variable r : natural := 0;
  begin
    while v < n loop
      v := v * 2;
      r := r + 1;
    end loop;
    return r;
  end function;

  -- Return index of highest '1' bit.
  -- If x = 0, returns 0 (caller must separately handle zero case).
  function msb_index(x : unsigned) return natural is
  begin
    for i in x'length-1 downto 0 loop
      if x(i) = '1' then
        return i;
      end if;
    end loop;
    return 0;
  end function;

  -- Extract OUT_W bits immediately below the leading 1 after normalization.
  -- Example:
  --   x = 1 . b1 b2 b3 ...
  -- returns b1 b2 b3 ...
  --
  -- If we run out of source bits near the LSB, pads with zeros.
  function get_norm_frac_bits(
    x      : unsigned;
    msb_ix : natural;
    out_w  : natural
  ) return unsigned is
    variable res     : unsigned(out_w-1 downto 0) := (others => '0');
    variable src_idx : integer;
  begin
    for i in 0 to out_w-1 loop
      src_idx := integer(msb_ix) - 1 - i;
      if src_idx >= 0 then
        res(out_w-1-i) := x(src_idx);
      else
        res(out_w-1-i) := '0';
      end if;
    end loop;
    return res;
  end function;

  ------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------

  constant EXP_W         : natural := clog2(IN_W);
  constant NORM_W        : natural := SEG_BITS + FRAC_BITS;
  constant LOG_W         : natural := EXP_W + LUT_W;
  constant MULT_W        : natural := LUT_W + FRAC_BITS;
  constant MAP_FRAC_KEEP : natural := 8;
  constant MAP_IN_W      : natural := LOG_W - LUT_W + MAP_FRAC_KEEP;
  constant MAP_MULT_W    : natural := MAP_IN_W + GAIN_W;

  ------------------------------------------------------------------------------
  -- BRAM / ROM component declarations
  ------------------------------------------------------------------------------

  component log_base_rom
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      addra : in  std_logic_vector(SEG_BITS-1 downto 0);
      douta : out std_logic_vector(LUT_W-1 downto 0)
    );
  end component;

  component log_slope_rom
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      addra : in  std_logic_vector(SEG_BITS-1 downto 0);
      douta : out std_logic_vector(LUT_W-1 downto 0)
    );
  end component;

  ------------------------------------------------------------------------------
  -- Stage 0: input decode / exponent / mantissa extraction
  ------------------------------------------------------------------------------

  signal mag2_u_s0      : unsigned(IN_W-1 downto 0) := (others => '0');
  signal zero_s0        : std_logic := '0';
  signal exp_u_s0       : unsigned(EXP_W-1 downto 0) := (others => '0');
  signal seg_idx_s0     : unsigned(SEG_BITS-1 downto 0) := (others => '0');
  signal frac_u_s0      : unsigned(FRAC_BITS-1 downto 0) := (others => '0');
  signal valid_s0       : std_logic := '0';

  ------------------------------------------------------------------------------
  -- ROM interface
  ------------------------------------------------------------------------------

  signal base_rom_addr  : std_logic_vector(SEG_BITS-1 downto 0);
  signal slope_rom_addr : std_logic_vector(SEG_BITS-1 downto 0);

  signal base_rom_dout  : std_logic_vector(LUT_W-1 downto 0);
  signal slope_rom_dout : std_logic_vector(LUT_W-1 downto 0);


  ------------------------------------------------------------------------------
  -- Stage 1: first control-path delay (ROM latency alignment)
  ------------------------------------------------------------------------------

  signal zero_s1        : std_logic := '0';
  signal exp_u_s1       : unsigned(EXP_W-1 downto 0) := (others => '0');
  signal frac_u_s1      : unsigned(FRAC_BITS-1 downto 0) := (others => '0');
  signal valid_s1       : std_logic := '0';

  ------------------------------------------------------------------------------
  -- Stage 2: second control-path delay + ROM data capture
  -- Aligns control path to 2-cycle BRAM latency
  ------------------------------------------------------------------------------

  signal zero_s2        : std_logic := '0';
  signal exp_u_s2       : unsigned(EXP_W-1 downto 0) := (others => '0');
  signal frac_u_s2      : unsigned(FRAC_BITS-1 downto 0) := (others => '0');
  signal valid_s2       : std_logic := '0';

  ------------------------------------------------------------------------------
  -- Stage 3: interpolation + exponent add
  ------------------------------------------------------------------------------

  signal mult_full_s3       : unsigned(MULT_W-1 downto 0) := (others => '0');
  signal interp_delta_u_s3  : unsigned(LUT_W-1 downto 0) := (others => '0');
  signal mant_log_u_s3      : unsigned(LUT_W-1 downto 0) := (others => '0');
  signal log2_full_u_s3     : unsigned(LOG_W-1 downto 0) := (others => '0');
  signal zero_s3            : std_logic := '0';
  signal valid_s3           : std_logic := '0';

  ------------------------------------------------------------------------------
  -- Stage 4: grayscale mapping
  ------------------------------------------------------------------------------

  signal pix_out_r      : std_logic_vector(7 downto 0) := (others => '0');
  signal pix_valid_r    : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  -- ROM address hookup
  ------------------------------------------------------------------------------

  base_rom_addr  <= std_logic_vector(seg_idx_s0);
  slope_rom_addr <= std_logic_vector(seg_idx_s0);

  ------------------------------------------------------------------------------
  -- ROM instantiations (component style)
  ------------------------------------------------------------------------------

  u_log_base_rom : log_base_rom
    port map (
      clka  => clk,
      ena   => '1',
      addra => base_rom_addr,
      douta => base_rom_dout
    );

  u_log_slope_rom : log_slope_rom
    port map (
      clka  => clk,
      ena   => '1',
      addra => slope_rom_addr,
      douta => slope_rom_dout
    );

  ------------------------------------------------------------------------------
  -- Stage 0:
  --  - register input
  --  - zero detect
  --  - find exponent (MSB index)
  --  - extract normalized mantissa bits
  ------------------------------------------------------------------------------

  process(clk)
    variable mag_v       : unsigned(IN_W-1 downto 0);
    variable msb_ix_v    : natural;
    variable norm_bits_v : unsigned(NORM_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mag2_u_s0  <= (others => '0');
        zero_s0    <= '0';
        exp_u_s0   <= (others => '0');
        seg_idx_s0 <= (others => '0');
        frac_u_s0  <= (others => '0');
        valid_s0   <= '0';
      else
        mag_v := unsigned(mag2_in);

        mag2_u_s0 <= mag_v;
        valid_s0  <= in_valid;

        if in_valid = '1' then
          if mag_v = 0 then
            zero_s0    <= '1';
            exp_u_s0   <= (others => '0');
            seg_idx_s0 <= (others => '0');
            frac_u_s0  <= (others => '0');
          else
            zero_s0 <= '0';
            msb_ix_v := msb_index(mag_v);
            exp_u_s0 <= to_unsigned(msb_ix_v, EXP_W);

            norm_bits_v := get_norm_frac_bits(mag_v, msb_ix_v, NORM_W);
            seg_idx_s0  <= norm_bits_v(NORM_W-1 downto FRAC_BITS);
            frac_u_s0   <= norm_bits_v(FRAC_BITS-1 downto 0);

            zero_s0 <= '0';
          end if;
        else
          zero_s0    <= '0';
          exp_u_s0   <= (others => '0');
          seg_idx_s0 <= (others => '0');
          frac_u_s0  <= (others => '0');
        end if;
      end if;
    end if;
  end process;

    ------------------------------------------------------------------------------
  -- Stage 1:
  --  first delay of control path to match ROM latency
  ------------------------------------------------------------------------------

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        zero_s1   <= '0';
        exp_u_s1  <= (others => '0');
        frac_u_s1 <= (others => '0');
        valid_s1  <= '0';
      else
        zero_s1   <= zero_s0;
        exp_u_s1  <= exp_u_s0;
        frac_u_s1 <= frac_u_s0;
        valid_s1  <= valid_s0;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Stage 2:
  --  second delay of control path + capture ROM outputs
  --  This matches the 2-cycle BRAM latency
  ------------------------------------------------------------------------------

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        zero_s2    <= '0';
        exp_u_s2   <= (others => '0');
        frac_u_s2  <= (others => '0');
        valid_s2   <= '0';
      else
        zero_s2   <= zero_s1;
        exp_u_s2  <= exp_u_s1;
        frac_u_s2 <= frac_u_s1;
        valid_s2  <= valid_s1;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Stage 3:
  --  mant_log = base + ((slope * frac) >> FRAC_BITS)
  --  log2_full = (exp << LUT_W) + mant_log
  ------------------------------------------------------------------------------

   process(clk)
    variable base_v         : unsigned(LUT_W-1 downto 0);
    variable slope_v        : unsigned(LUT_W-1 downto 0);
    variable mult_v         : unsigned(MULT_W-1 downto 0);
    variable interp_v       : unsigned(LUT_W-1 downto 0);
    variable mant_v         : unsigned(LUT_W-1 downto 0);
    variable log2_full_v    : unsigned(LOG_W-1 downto 0);
    variable exp_ext_v      : unsigned(LOG_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mult_full_s3      <= (others => '0');
        interp_delta_u_s3 <= (others => '0');
        mant_log_u_s3     <= (others => '0');
        log2_full_u_s3    <= (others => '0');
        zero_s3           <= '0';
        valid_s3          <= '0';
      else
        zero_s3  <= zero_s2;
        valid_s3 <= valid_s2;

        if valid_s2 = '1' then
          if zero_s2 = '1' then
            mult_full_s3      <= (others => '0');
            interp_delta_u_s3 <= (others => '0');
            mant_log_u_s3     <= (others => '0');
            log2_full_u_s3    <= (others => '0');
          else
            base_v  := unsigned(base_rom_dout);
            slope_v := unsigned(slope_rom_dout);

            mult_v   := slope_v * frac_u_s2;
            interp_v := resize(shift_right(mult_v, FRAC_BITS), LUT_W);

            mant_v := base_v + interp_v;

            exp_ext_v   := shift_left(resize(exp_u_s2, LOG_W), LUT_W);
            log2_full_v := exp_ext_v + resize(mant_v, LOG_W);

            mult_full_s3      <= mult_v;
            interp_delta_u_s3 <= interp_v;
            mant_log_u_s3     <= mant_v;
            log2_full_u_s3    <= log2_full_v;
          end if;
        else
          mult_full_s3      <= (others => '0');
          interp_delta_u_s3 <= (others => '0');
          mant_log_u_s3     <= (others => '0');
          log2_full_u_s3    <= (others => '0');
        end if;
      end if;
    end if;
  end process;

   ------------------------------------------------------------------------------
  -- Stage 4:
  --  grayscale map to 8-bit output
  --
  --  diff      = log2_full - MAP_FLOOR_Q          (still in QLUT_W format)
  --  diff_map  = diff shifted from QLUT_W to QMAP_FRAC_KEEP
  --  gray      = sat_0_255( (diff_map * MAP_GAIN_Q) >> (MAP_GAIN_FRAC + MAP_FRAC_KEEP) )
  ------------------------------------------------------------------------------
  process(clk)
    variable floor_v       : unsigned(LOG_W-1 downto 0);
    variable gain_v        : unsigned(GAIN_W-1 downto 0);
    variable diff_v        : unsigned(LOG_W-1 downto 0);
    variable diff_map_v    : unsigned(MAP_IN_W-1 downto 0);
    variable map_mult_v    : unsigned(MAP_MULT_W-1 downto 0);
    variable map_shift_v   : unsigned(MAP_MULT_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pix_out_r   <= (others => '0');
        pix_valid_r <= '0';
      else
        pix_valid_r <= valid_s3;

        floor_v := to_unsigned(MAP_FLOOR_Q, LOG_W);
        gain_v  := to_unsigned(MAP_GAIN_Q, GAIN_W);

        if valid_s3 = '1' then
          if zero_s3 = '1' then
            pix_out_r <= (others => '0');

          elsif log2_full_u_s3 <= floor_v then
            pix_out_r <= (others => '0');

          else
            -- diff is still in QLUT_W
            diff_v := log2_full_u_s3 - floor_v;

            -- Keep MAP_FRAC_KEEP fractional bits from the original QLUT_W value.
            -- Example: Q18 -> Q8 means shift right by 10.
            diff_map_v := resize(
                            shift_right(diff_v, LUT_W - MAP_FRAC_KEEP),
                            MAP_IN_W
                          );

            -- Multiply by gain
            map_mult_v := diff_map_v * gain_v;

            -- Remove both:
            --   1) gain fractional scaling
            --   2) retained log fractional scaling
            map_shift_v := shift_right(map_mult_v, MAP_GAIN_FRAC + MAP_FRAC_KEEP);

            if map_shift_v > to_unsigned(255, MAP_MULT_W) then
              pix_out_r <= (others => '1');
            else
              pix_out_r <= std_logic_vector(resize(map_shift_v, 8));
            end if;
          end if;
        else
          pix_out_r <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Outputs
  ------------------------------------------------------------------------------

  pix_out   <= pix_out_r;
  pix_valid <= pix_valid_r;

end architecture;