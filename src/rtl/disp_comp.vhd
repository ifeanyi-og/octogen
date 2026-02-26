library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Dispersion compensation:
--   input real x[n] (32-bit signed) from k-linearization
--   LUTs provide cos(phi[n]) and sin(phi[n]) (signed, Q1.(LUT_FRAC))
--   output complex:
--     Re = x * cos(phi)
--     Im = -x * sin(phi)
--
-- Notes:
-- - Uses 24-bit internal x_s (down-shifted from 32-bit for DSP efficiency)
-- - LUT width default 18-bit signed, Q1.17
-- - ROM latency is parameterized (Block Memory Generator commonly 2 cycles with output reg enabled)
-- - Adds 2 pipeline stages after ROM: (1) multiply regs, (2) round/shift/output regs

entity disp_comp is
  generic (
    ASCAN_LEN : natural := 512;
    ADDR_W    : natural := 9;   -- log2(512)=9
    IN_W      : natural := 32;  -- k-lin output width
    X_W       : natural := 24;  -- internal data width for multiply
    LUT_W     : natural := 18;  -- cos/sin LUT width
    LUT_FRAC  : natural := 17;  -- fractional bits in LUT (Q1.17)
    SHIFT_IN  : natural := 8;   -- x_s = x_in >>> SHIFT_IN (tune based on k-lin dynamic range)
    ROM_LAT   : natural := 2    -- cycles from addra to douta valid (per your BRAM IP config)
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;

    start_of_ascan : in  std_logic;

    in_x       : in  std_logic_vector(IN_W-1 downto 0);
    in_valid   : in  std_logic;

    out_re     : out std_logic_vector(IN_W-1 downto 0); -- 32-bit signed to FFT
    out_im     : out std_logic_vector(IN_W-1 downto 0); -- 32-bit signed to FFT
    out_valid  : out std_logic
  );
end entity;

architecture rtl of disp_comp is

  -- ============
  -- BRAM ROM IPs
  -- ============
  -- These components should match your Block Memory Generator module names/ports.
  component disp_cos_rom is
    port (
      clka  : in  std_logic;
      ena   : in std_logic;
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      douta : out std_logic_vector(LUT_W-1 downto 0)
    );
  end component;

  component disp_sin_rom is
    port (
      clka  : in  std_logic;
      ena   : in std_logic;
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      douta : out std_logic_vector(LUT_W-1 downto 0)
    );
  end component;

  -- ============
  -- Local types
  -- ============
  subtype s_in_t  is signed(IN_W-1 downto 0);
  subtype s_x_t   is signed(X_W-1 downto 0);
  subtype s_lut_t is signed(LUT_W-1 downto 0);

  -- 24x18 => 42-bit product
  constant PROD_W : natural := X_W + LUT_W;
  subtype s_prod_t is signed(PROD_W-1 downto 0);

  -- ============
  -- Signals
  -- ============
  signal addr_cnt   : unsigned(ADDR_W-1 downto 0) := (others => '0');
  signal rom_addr   : std_logic_vector(ADDR_W-1 downto 0);

  signal cos_raw    : std_logic_vector(LUT_W-1 downto 0);
  signal sin_raw    : std_logic_vector(LUT_W-1 downto 0);
  signal cos_s      : s_lut_t;
  signal sin_s      : s_lut_t;

  -- Pipeline alignment for x_s and valid through ROM_LAT
  type x_pipe_t is array (0 to ROM_LAT) of s_x_t;
  signal x_pipe     : x_pipe_t;

  type v_pipe_t is array (0 to ROM_LAT) of std_logic;
  signal v_pipe     : v_pipe_t;

  -- Multiply stage regs
  signal re_prod_r  : s_prod_t := (others => '0');
  signal im_prod_r  : s_prod_t := (others => '0');
  signal v_mul_r    : std_logic := '0';

  -- Output stage regs
  signal re_out_r   : s_in_t := (others => '0');
  signal im_out_r   : s_in_t := (others => '0');
  signal v_out_r    : std_logic := '0';

  -- ============
  -- Helpers
  -- ============
  -- Signed round-right-shift by SHIFT bits:
  --   y = round(x / 2^SHIFT)
  -- Works by adding +2^(SHIFT-1) for x>=0, -2^(SHIFT-1) for x<0.
  function round_shift_signed(x : signed; SHIFT : natural) return signed is
    variable xv   : signed(x'length-1 downto 0) := x;
    variable bias : signed(x'length-1 downto 0) := (others => '0');
    variable yv   : signed(x'length-1 downto 0);
  begin
    if SHIFT = 0 then
      return xv;
    end if;

    bias := (others => '0');
    bias(SHIFT-1) := '1'; -- 2^(SHIFT-1)

    if xv(xv'high) = '0' then
      yv := xv + bias;
    else
      yv := xv - bias;
    end if;

    return shift_right(yv, SHIFT);
  end function;

  -- Saturate/resize helper to IN_W
  function sat_resize_to_inw(x : signed) return s_in_t is
    variable y : s_in_t;
  begin
    -- For simplicity: just take the lower IN_W bits with sign resize.
    -- If you want true saturation, we can add it (usually not required if SHIFT_IN + FFT scaling are sane).
    y := resize(x, IN_W);
    return y;
  end function;

begin

  -- ============
  -- Addressing
  -- ============
  rom_addr <= std_logic_vector(addr_cnt);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        addr_cnt <= (others => '0');
      else
        if start_of_ascan = '1' then
          addr_cnt <= (others => '0');
        elsif in_valid = '1' then
          if addr_cnt = to_unsigned(ASCAN_LEN-1, ADDR_W) then
            addr_cnt <= (others => '0'); -- wrap (optional)
          else
            addr_cnt <= addr_cnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ============
  -- ROM instantiation
  -- ============
  u_cos : disp_cos_rom
    port map (
      clka  => clk,
      ena => '1',
      addra => rom_addr,
      douta => cos_raw
    );

  u_sin : disp_sin_rom
    port map (
      clka  => clk,
      ena => '1',
      addra => rom_addr,
      douta => sin_raw
    );

  cos_s <= signed(cos_raw);
  sin_s <= signed(sin_raw);

  -- ============
  -- Stage 0..ROM_LAT: align x_s with ROM outputs
  -- ============
  process(clk)
    variable x_in_s : s_in_t;
    variable x_s    : s_x_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        for i in 0 to ROM_LAT loop
          x_pipe(i) <= (others => '0');
          v_pipe(i) <= '0';
        end loop;
      else
        -- stage 0 capture when in_valid
        x_in_s := signed(in_x);

        -- Downshift 32->24 for DSP efficiency & headroom control.
        -- NOTE: SHIFT_IN is the knob you tune based on measured k-lin amplitude.
        x_s := resize(shift_right(x_in_s, SHIFT_IN), X_W);

        x_pipe(0) <= x_s;
        v_pipe(0) <= in_valid;

        for i in 1 to ROM_LAT loop
          x_pipe(i) <= x_pipe(i-1);
          v_pipe(i) <= v_pipe(i-1);
        end loop;
      end if;
    end if;
  end process;

  -- ============
  -- Multiply stage (registered)
  -- ============
  process(clk)
    variable x_al  : s_x_t;
    variable re_p  : s_prod_t;
    variable im_p  : s_prod_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        re_prod_r <= (others => '0');
        im_prod_r <= (others => '0');
        v_mul_r   <= '0';
      else
        x_al := x_pipe(ROM_LAT);

        -- Re = x * cos
        re_p := resize(x_al * cos_s, PROD_W);

        -- Im = -x * sin
        im_p := resize(-(x_al * sin_s), PROD_W);

        re_prod_r <= re_p;
        im_prod_r <= im_p;
        v_mul_r   <= v_pipe(ROM_LAT);
      end if;
    end if;
  end process;

  -- ============
  -- Output stage: round & shift back by LUT_FRAC, then resize to 32-bit complex for FFT
  -- ============
  process(clk)
    variable re_rs : signed(PROD_W-1 downto 0);
    variable im_rs : signed(PROD_W-1 downto 0);
    variable re_x  : signed(PROD_W-1 downto 0);
    variable im_x  : signed(PROD_W-1 downto 0);
    variable re_24 : signed(X_W-1 downto 0);
    variable im_24 : signed(X_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        re_out_r <= (others => '0');
        im_out_r <= (others => '0');
        v_out_r  <= '0';
      else
        -- Undo LUT fractional scaling (Q1.LUT_FRAC)
        re_rs := round_shift_signed(re_prod_r, LUT_FRAC);
        im_rs := round_shift_signed(im_prod_r, LUT_FRAC);

        -- Bring back to ~X_W dynamic range (truncate/resize)
        re_24 := resize(re_rs, X_W);
        im_24 := resize(im_rs, X_W);

        -- Expand to 32-bit for FFT (sign-extend)
        re_out_r <= resize(re_24, IN_W);
        im_out_r <= resize(im_24, IN_W);

        v_out_r  <= v_mul_r;
      end if;
    end if;
  end process;

  out_re    <= std_logic_vector(re_out_r);
  out_im    <= std_logic_vector(im_out_r);
  out_valid <= v_out_r;

end architecture;
