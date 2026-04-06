library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity disp_comp is
  generic (
    ASCAN_LEN : natural := 1024;
    ADDR_W    : natural := 10;
    IN_W      : natural := 32;
    X_W       : natural := 24;
    LUT_W     : natural := 18;
    LUT_FRAC  : natural := 17;
    SHIFT_IN  : natural := 8;
    RAM_LAT   : natural := 1
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;

    -- streaming input
    in_x            : in  std_logic_vector(IN_W-1 downto 0);
    in_valid        : in  std_logic;
    start_of_ascan  : in  std_logic;

    -- LUT write interface
    lut_wr_en    : in  std_logic;
    lut_wr_addr  : in  std_logic_vector(ADDR_W-1 downto 0);
    lut_cos_din  : in  std_logic_vector(LUT_W-1 downto 0);
    lut_sin_din  : in  std_logic_vector(LUT_W-1 downto 0);

    -- streaming output
    out_re             : out std_logic_vector(IN_W-1 downto 0);
    out_im             : out std_logic_vector(IN_W-1 downto 0);
    out_valid          : out std_logic;
    start_of_ascan_out : out std_logic;
    end_of_ascan_out   : out std_logic
  );
end entity;

architecture rtl of disp_comp is

  component disp_cos_rom is
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      dina  : in  std_logic_vector(LUT_W-1 downto 0);
      wea   : in  std_logic_vector(0 downto 0);

      clkb  : in  std_logic;
      enb   : in  std_logic;
      addrb : in  std_logic_vector(ADDR_W-1 downto 0);
      doutb : out std_logic_vector(LUT_W-1 downto 0)
    );
  end component;

  component disp_sin_rom is
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      dina  : in  std_logic_vector(LUT_W-1 downto 0);
      wea   : in  std_logic_vector(0 downto 0);

      clkb  : in  std_logic;
      enb   : in  std_logic;
      addrb : in  std_logic_vector(ADDR_W-1 downto 0);
      doutb : out std_logic_vector(LUT_W-1 downto 0)
    );
  end component;

  subtype s_in_t  is signed(IN_W-1 downto 0);
  subtype s_x_t   is signed(X_W-1 downto 0);
  subtype s_lut_t is signed(LUT_W-1 downto 0);

  constant PROD_W : natural := X_W + LUT_W;
  subtype s_prod_t is signed(PROD_W-1 downto 0);

  type x_pipe_t is array (0 to RAM_LAT) of s_x_t;
  type v_pipe_t is array (0 to RAM_LAT) of std_logic;

  signal sample_idx : unsigned(ADDR_W-1 downto 0) := (others => '0');
  signal ram_raddr  : std_logic_vector(ADDR_W-1 downto 0);

  signal cos_raw    : std_logic_vector(LUT_W-1 downto 0);
  signal sin_raw    : std_logic_vector(LUT_W-1 downto 0);
  signal cos_s      : s_lut_t;
  signal sin_s      : s_lut_t;

  signal x_pipe     : x_pipe_t;
  signal v_pipe     : v_pipe_t;
  signal soa_pipe   : v_pipe_t;
  signal eoa_pipe   : v_pipe_t;

  signal re_prod_r  : s_prod_t := (others => '0');
  signal im_prod_r  : s_prod_t := (others => '0');
  signal v_mul_r    : std_logic := '0';
  signal soa_mul_r  : std_logic := '0';
  signal eoa_mul_r  : std_logic := '0';

  signal re_out_r   : s_in_t := (others => '0');
  signal im_out_r   : s_in_t := (others => '0');
  signal v_out_r    : std_logic := '0';
  signal soa_out_r  : std_logic := '0';
  signal eoa_out_r  : std_logic := '0';

  signal lut_we     : std_logic_vector(0 downto 0);
  
  signal lut_re_en : std_logic;
  
  signal curr_idx : unsigned (ADDR_W-1 downto 0);

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

begin

  lut_we(0) <= lut_wr_en;
  curr_idx  <= (others => '0') when (in_valid = '1' and start_of_ascan = '1') else sample_idx;
  ram_raddr <= std_logic_vector(curr_idx);

  process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          sample_idx <= (others => '0');
        else
          if in_valid = '1' then
            if start_of_ascan = '1' then
              -- current sample uses address 0, so next sample should use 1
              sample_idx <= to_unsigned(1, ADDR_W);
            elsif curr_idx = to_unsigned(ASCAN_LEN-1, ADDR_W) then
              sample_idx <= (others => '0');
            else
              sample_idx <= curr_idx + 1;
            end if;
          end if;
        end if;
      end if;
   end process;
lut_re_en <= not lut_wr_en;

  u_cos : disp_cos_rom
    port map (
      -- Port A: write
      clka  => clk,
      ena   => '1',
      addra => lut_wr_addr,
      dina  => lut_cos_din,
      wea   => lut_we,

      -- Port B: read
      clkb  => clk,
      enb   => lut_re_en,
      addrb => ram_raddr,
      doutb => cos_raw
    );

  u_sin : disp_sin_rom
    port map (
      -- Port A: write
      clka  => clk,
      ena   => '1',
      addra => lut_wr_addr,
      dina  => lut_sin_din,
      wea   => lut_we,

      -- Port B: read
      clkb  => clk,
      enb   => lut_re_en,
      addrb => ram_raddr,
      doutb => sin_raw
    );

  cos_s <= signed(cos_raw);
  sin_s <= signed(sin_raw);

  process(clk)
    variable x_in_s  : s_in_t;
    variable x_s     : s_x_t;
    variable eoa_now : std_logic;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        for i in 0 to RAM_LAT loop
          x_pipe(i)   <= (others => '0');
          v_pipe(i)   <= '0';
          soa_pipe(i) <= '0';
          eoa_pipe(i) <= '0';
        end loop;
      else
        x_in_s := signed(in_x);
        x_s    := resize(shift_right(x_in_s, SHIFT_IN), X_W);

        if (in_valid = '1') and (curr_idx = to_unsigned(ASCAN_LEN-1, ADDR_W)) then
          eoa_now := '1';
        else
          eoa_now := '0';
        end if;

        x_pipe(0)   <= x_s;
        v_pipe(0)   <= in_valid;
        soa_pipe(0) <= start_of_ascan and in_valid;
        eoa_pipe(0) <= eoa_now;

        for i in 1 to RAM_LAT loop
          x_pipe(i)   <= x_pipe(i-1);
          v_pipe(i)   <= v_pipe(i-1);
          soa_pipe(i) <= soa_pipe(i-1);
          eoa_pipe(i) <= eoa_pipe(i-1);
        end loop;
      end if;
    end if;
  end process;

  process(clk)
    variable x_al : s_x_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        re_prod_r <= (others => '0');
        im_prod_r <= (others => '0');
        v_mul_r   <= '0';
        soa_mul_r <= '0';
        eoa_mul_r <= '0';
      else
        x_al := x_pipe(RAM_LAT);

        re_prod_r <= resize(x_al * cos_s, PROD_W);
        im_prod_r <= resize(-(x_al * sin_s), PROD_W);

        v_mul_r   <= v_pipe(RAM_LAT);
        soa_mul_r <= soa_pipe(RAM_LAT);
        eoa_mul_r <= eoa_pipe(RAM_LAT);
      end if;
    end if;
  end process;

  process(clk)
    variable re_rs : signed(PROD_W-1 downto 0);
    variable im_rs : signed(PROD_W-1 downto 0);
    variable re_24 : signed(X_W-1 downto 0);
    variable im_24 : signed(X_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        re_out_r  <= (others => '0');
        im_out_r  <= (others => '0');
        v_out_r   <= '0';
        soa_out_r <= '0';
        eoa_out_r <= '0';
      else
        re_rs := round_shift_signed(re_prod_r, LUT_FRAC);
        im_rs := round_shift_signed(im_prod_r, LUT_FRAC);

        re_24 := resize(re_rs, X_W);
        im_24 := resize(im_rs, X_W);

        re_out_r  <= resize(re_24, IN_W);
        im_out_r  <= resize(im_24, IN_W);
        v_out_r   <= v_mul_r;
        soa_out_r <= soa_mul_r;
        eoa_out_r <= eoa_mul_r;
      end if;
    end if;
  end process;

  out_re             <= std_logic_vector(re_out_r);
  out_im             <= std_logic_vector(im_out_r);
  out_valid          <= v_out_r;
  start_of_ascan_out <= soa_out_r;
  end_of_ascan_out   <= eoa_out_r;

end architecture;