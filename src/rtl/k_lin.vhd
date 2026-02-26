library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity k_lin is
  generic (
    ASCAN_LEN : natural := 512;
    ADDR_W    : natural := 9;
    COEF_W    : natural := 18;
    FRAC_BITS : natural := 16;   -- if coeffs are Q?.FRAC_BITS (e.g., Q2.16)
    COEF_LAT  : natural := 2;    -- ROM read latency in cycles (you said 2)
    SAMP_LAT  : natural := 3     -- sample BRAM read latency (adjust as needed)
  );
  port (
    clk : in  std_logic;
    rst : in  std_logic;

    str_in         : in  std_logic_vector(31 downto 0);
    str_in_valid   : in  std_logic;
    start_of_ascan : in  std_logic;

    str_out       : out std_logic_vector(31 downto 0);
    str_out_valid : out std_logic
  );
end entity;

architecture rtl of k_lin is
  --state/control
  type state_t is (
    IDLE,
    CAPTURE,
    COEF_REQ,
    COEF_WAIT,
    COEF_LATCH,
    SAMP_REQ,
    SAMP_WAIT,
    SAMP_LATCH,
    OUT_PULSE
  );
  signal st : state_t := IDLE;

  signal cap_cnt  : unsigned(ADDR_W-1 downto 0) := (others => '0'); -- 0..511
  signal out_idx  : unsigned(ADDR_W-1 downto 0) := (others => '0'); -- 0..511

  signal wait_cnt : natural range 0 to 31 := 0;
  signal tap_idx  : natural range 0 to 3 := 0;
  
  --BRAM interface signals
  -- Sample BRAM (TDP): Port A write, Port B read
  signal samp_wea   : std_logic_vector(0 downto 0) := (others => '0');
  signal samp_addra : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal samp_dina  : std_logic_vector(31 downto 0) := (others => '0');
  signal samp_douta : std_logic_vector(31 downto 0); -- unused
  signal samp_addrb0, samp_addrb1, samp_addrb2, samp_addrb3 : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal samp_doutb0, samp_doutb1, samp_doutb2, samp_doutb3 : std_logic_vector(31 downto 0);
  -- optional debug/latch regs (not strictly required, but nice)
  signal x0, x1, x2, x3 : signed(31 downto 0) := (others => '0');
  
  -- ROMs share same address (coef_addr = out_idx)
  signal coef_addr  : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal base_dout  : std_logic_vector(ADDR_W-1 downto 0);
  signal c0_dout    : std_logic_vector(COEF_W-1 downto 0);
  signal c1_dout    : std_logic_vector(COEF_W-1 downto 0);
  signal c2_dout    : std_logic_vector(COEF_W-1 downto 0);
  signal c3_dout    : std_logic_vector(COEF_W-1 downto 0);
  
  -- Latched coef/base for current output sample
  signal base_u     : unsigned(ADDR_W-1 downto 0) := (others => '0');
  signal c0, c1, c2, c3 : signed(COEF_W-1 downto 0) := (others => '0');
  
      
  -- Accumulator
  signal acc        : signed(63 downto 0) := (others => '0');
  
  signal samp_enb : std_logic := '0';
  signal samp_ena : std_logic := '1';
  
  signal samp_addr_req : unsigned (ADDR_W-1 downto 0) := (others => '0');
  
  --helper fxns
  function clamp_addr(a : integer) return unsigned is
    variable r : integer := a;
  begin
    if r < 0 then
      r := 0;
    elsif r > integer(ASCAN_LEN-1) then
      r := integer(ASCAN_LEN-1);
    end if;
    return to_unsigned(r, ADDR_W);
  end function;
  
  function sat32(x : signed(63 downto 0)) return std_logic_vector is
      -- 32-bit signed limits represented in 64-bit signed
      constant MAX32_64 : signed(63 downto 0) := to_signed( 2147483647, 64);  -- 0x7FFFFFFF
      constant MIN32_64 : signed(63 downto 0) := to_signed(-2147483648, 64);  -- 0x80000000
      variable y : signed(31 downto 0);
    begin
      if x > MAX32_64 then
        y := to_signed( 2147483647, 32);
      elsif x < MIN32_64 then
        y := to_signed(-2147483648, 32);
      else
        y := resize(x, 32);
      end if;
      return std_logic_vector(y);
    end function;
  
  function coef_sel(t : natural; c0i,c1i,c2i,c3i : signed(COEF_W-1 downto 0)) return signed is
  begin
    case t is
      when 0 => return c0i;
      when 1 => return c1i;
      when 2 => return c2i;
      when others => return c3i;
    end case;
  end function;
  
  --ip component instantiations
  component klin_sample_bram is
  port(
    clka : in std_logic;
    ena : in std_logic;
    wea : in std_logic_vector (0 downto 0);
    addra : in std_logic_vector (8 downto 0);
    dina : in std_logic_vector (31 downto 0);
    douta : out std_logic_vector (31 downto 0);
    
    clkb : in std_logic;
    enb : in std_logic;
    web : in std_logic_vector (0 downto 0);
    addrb : in std_logic_vector (8 downto 0);
    dinb : in std_logic_vector (31 downto 0);
    doutb : out std_logic_vector (31 downto 0)
  );
  end component;
  
  component klin_base_rom is
  port (
    clka : in std_logic;
    ena : in std_logic;
    addra : in std_logic_vector (ADDR_W-1 downto 0);
    douta : out std_logic_vector (ADDR_W-1 downto 0)
  );
  end component;
  
  component klin_c0_rom is
  port (
    clka : in std_logic;
    ena : in std_logic;
    addra : in std_logic_vector (ADDR_W-1 downto 0);
    douta : out std_logic_vector (COEF_W-1 downto 0)
  );
  end component;
  
  component klin_c1_rom is
  port (
    clka : in std_logic;
    ena : in std_logic;
    addra : in std_logic_vector (ADDR_W-1 downto 0);
    douta : out std_logic_vector (COEF_W-1 downto 0)
  );
  end component;
  
  component klin_c2_rom is
  port (
    clka : in std_logic;
    ena : in std_logic;
    addra : in std_logic_vector (ADDR_W-1 downto 0);
    douta : out std_logic_vector (COEF_W-1 downto 0)
  );
  end component;
  
  component klin_c3_rom is
  port (
    clka : in std_logic;
    ena : in std_logic;
    addra : in std_logic_vector (ADDR_W-1 downto 0);
    douta : out std_logic_vector (COEF_W-1 downto 0)
  );
  end component;
begin

  -- ip instantiations
  u_sample_bram_1 : klin_sample_bram
    port map (
      clka   => clk,
      ena    => samp_ena,
      wea    => samp_wea,
      addra  => samp_addra,
      dina   => samp_dina,
      douta  => samp_douta,

      clkb   => clk,
      enb    => samp_enb,
      web    => (others => '0'),
      addrb  => samp_addrb0,
      dinb   => (others => '0'),
      doutb  => samp_doutb0
    );
    
    u_sample_bram_2 : klin_sample_bram
    port map (
      clka   => clk,
      ena    => samp_ena,
      wea    => samp_wea,
      addra  => samp_addra,
      dina   => samp_dina,
      douta  => samp_douta,

      clkb   => clk,
      enb    => samp_enb,
      web    => (others => '0'),
      addrb  => samp_addrb1,
      dinb   => (others => '0'),
      doutb  => samp_doutb1
    );
    
    u_sample_bram_3 : klin_sample_bram
    port map (
      clka   => clk,
      ena    => samp_ena,
      wea    => samp_wea,
      addra  => samp_addra,
      dina   => samp_dina,
      douta  => samp_douta,

      clkb   => clk,
      enb    => samp_enb,
      web    => (others => '0'),
      addrb  => samp_addrb2,
      dinb   => (others => '0'),
      doutb  => samp_doutb2
    );
    
    u_sample_bram_4 : klin_sample_bram
    port map (
      clka   => clk,
      ena    => samp_ena,
      wea    => samp_wea,
      addra  => samp_addra,
      dina   => samp_dina,
      douta  => samp_douta,

      clkb   => clk,
      enb    => samp_enb,
      web    => (others => '0'),
      addrb  => samp_addrb3,
      dinb   => (others => '0'),
      doutb  => samp_doutb3
    );
    
    u_base_rom : klin_base_rom
    port map (
      clka  => clk,
      ena   => '1',
      addra => coef_addr,
      douta => base_dout
    );

  u_c0_rom : klin_c0_rom
    port map (
      clka  => clk,
      ena   => '1',
      addra => coef_addr,
      douta => c0_dout
    );

  u_c1_rom : klin_c1_rom
    port map (
      clka  => clk,
      ena   => '1',
      addra => coef_addr,
      douta => c1_dout
    );

  u_c2_rom : klin_c2_rom
    port map (
      clka  => clk,
      ena   => '1',
      addra => coef_addr,
      douta => c2_dout
    );

  u_c3_rom : klin_c3_rom
    port map (
      clka  => clk,
      ena   => '1',
      addra => coef_addr,
      douta => c3_dout
    );
    
  --main FSM
  process(clk)
    variable x32   : signed(31 downto 0);
    variable coefv : signed(COEF_W-1 downto 0);
    variable p0, p1, p2, p3  : signed(63 downto 0);
    variable addr_i: integer;
    variable acc_next : signed (63 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st <= IDLE;
        cap_cnt <= (others => '0');
        out_idx <= (others => '0');
        wait_cnt <= 0;
        tap_idx <= 0;

        samp_wea   <= (others => '0');
        samp_addra <= (others => '0');
        samp_dina  <= (others => '0');
        samp_addrb0 <= (others => '0');
        samp_addrb1 <= (others => '0');
        samp_addrb2 <= (others => '0');
        samp_addrb3 <= (others => '0');
        coef_addr  <= (others => '0');

        base_u <= (others => '0');
        c0 <= (others => '0'); c1 <= (others => '0'); c2 <= (others => '0'); c3 <= (others => '0');
        acc <= (others => '0');

        str_out <= (others => '0');
        str_out_valid <= '0';

      else
        -- defaults each cycle
        str_out_valid <= '0';
        samp_wea <= (others => '0');
        if (st = CAPTURE) or (st = IDLE) then
            samp_enb <= '0';
        else
            samp_enb <='1';
        end if;
        case st is

          when IDLE =>
            if start_of_ascan = '1' then
              cap_cnt <= (others => '0');
              st <= CAPTURE;
            end if;

          when CAPTURE =>
            -- Write incoming samples into sample BRAM
            if str_in_valid = '1' then
              samp_wea(0)   <= '1';
              samp_addra    <= std_logic_vector(cap_cnt);
              samp_dina     <= str_in;

              if cap_cnt = to_unsigned(ASCAN_LEN-1, ADDR_W) then
                out_idx <= (others => '0');
                st <= COEF_REQ;
              else
                cap_cnt <= cap_cnt + 1;
              end if;
            end if;

          when COEF_REQ =>
            -- Request base/coeffs for this output index
            coef_addr <= std_logic_vector(out_idx);
            if COEF_LAT = 0 then
                wait_cnt <= 0;
            else
                wait_cnt <= COEF_LAT-1;
            end if;
            st        <= COEF_WAIT;

          when COEF_WAIT =>
            if wait_cnt = 0 then
              st <= COEF_LATCH;
            else
              wait_cnt <= wait_cnt - 1;
            end if;
          when COEF_LATCH =>
            -- now base_dout/c*_dout are stable *from the previous edge*
            base_u <= unsigned(base_dout);
            c0 <= signed(c0_dout);
            c1 <= signed(c1_dout);
            c2 <= signed(c2_dout);
            c3 <= signed(c3_dout);
            acc <= (others => '0');
            tap_idx <= 0;
            st <= SAMP_REQ;
          when SAMP_REQ =>
             -- taps are base-1, base, base+1, base+2
            samp_addrb0 <= std_logic_vector(clamp_addr(to_integer(base_u) - 1));
            samp_addrb1 <= std_logic_vector(clamp_addr(to_integer(base_u)));
            samp_addrb2 <= std_logic_vector(clamp_addr(to_integer(base_u) + 1));
            samp_addrb3 <= std_logic_vector(clamp_addr(to_integer(base_u) + 2));
            
            -- wait for BRAM latency (use SAMP_LAT, not -1, since we latch after wait)
            if SAMP_LAT = 0 then
              wait_cnt <= 0;
            else
              wait_cnt <= SAMP_LAT;
            end if;
            
            st <= SAMP_WAIT;
          when SAMP_WAIT =>
            if wait_cnt = 0 then
              st <= SAMP_LATCH;          -- <-- new stage
            else
              wait_cnt <= wait_cnt - 1;
            end if;
          when SAMP_LATCH =>
            --latch for debug visibility
            x0 <= signed(samp_doutb0);
            x1 <= signed(samp_doutb1);
            x2 <= signed(samp_doutb2);
            x3 <= signed(samp_doutb3);
            -- compute sum-of-products (scaled) p_i = (x_i * c_i) >> FRAC_BITS
            p0 := resize(shift_right(resize(signed(samp_doutb0),128) * resize(c0,128), FRAC_BITS), 64);
            p1 := resize(shift_right(resize(signed(samp_doutb1),128) * resize(c1,128), FRAC_BITS), 64);
            p2 := resize(shift_right(resize(signed(samp_doutb2),128) * resize(c2,128), FRAC_BITS), 64);
            p3 := resize(shift_right(resize(signed(samp_doutb3),128) * resize(c3,128), FRAC_BITS), 64);
            
            acc_next := p0 + p1 + p2 + p3;
            
            str_out <= sat32 (acc_next);
            str_out_valid <= '1';
            
            st <= OUT_PULSE;
          when OUT_PULSE =>
            if out_idx = to_unsigned(ASCAN_LEN-1, ADDR_W) then
              st <= IDLE;
            else
              out_idx <= out_idx + 1;
              st <= COEF_REQ;
            end if;

          when others =>
            st <= IDLE;

        end case;

      end if;
    end if;
  end process;
end architecture;