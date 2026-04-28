library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity k_lin is
  generic (
    ASCAN_LEN : natural := 1024;
    ADDR_W    : natural := 10;
    COEF_W    : natural := 18;
    FRAC_BITS : natural := 16;
    COEF_LAT  : natural := 2;
    SAMP_LAT  : natural := 2
  );
  port (
    clk : in  std_logic;
    rst : in  std_logic;

    -- Streaming input
    str_in             : in  std_logic_vector(31 downto 0);
    str_in_valid       : in  std_logic;
    start_of_ascan     : in  std_logic;

    -- Streaming output
    str_out            : out std_logic_vector(31 downto 0);
    str_out_valid      : out std_logic;
    start_of_ascan_out : out std_logic;

    -- Calibration write interface
    cal_ready            : in  std_logic;
    cal_write_addr       : in  std_logic_vector(ADDR_W-1 downto 0);

    cal_base_write_en    : in  std_logic;
    cal_base_write_data  : in  std_logic_vector(ADDR_W-1 downto 0);

    cal_c0_write_en      : in  std_logic;
    cal_c0_write_data    : in  std_logic_vector(COEF_W-1 downto 0);

    cal_c1_write_en      : in  std_logic;
    cal_c1_write_data    : in  std_logic_vector(COEF_W-1 downto 0);

    cal_c2_write_en      : in  std_logic;
    cal_c2_write_data    : in  std_logic_vector(COEF_W-1 downto 0);

    cal_c3_write_en      : in  std_logic;
    cal_c3_write_data    : in  std_logic_vector(COEF_W-1 downto 0);

    overflow : out std_logic
  );
end entity;

architecture rtl of k_lin is

  constant N_BANKS : integer := 3;

  type bank_state_t is (EMPTY, FILLING, READY, READING);
  type bank_state_arr_t is array (0 to N_BANKS-1) of bank_state_t;

  function clamp_addr(a : integer) return unsigned is
    variable r : integer := a;
  begin
    if r < 0 then
      r := 0;
    elsif r > integer(ASCAN_LEN - 1) then
      r := integer(ASCAN_LEN - 1);
    end if;
    return to_unsigned(r, ADDR_W);
  end function;

  function sat32(x : signed(63 downto 0)) return std_logic_vector is
    constant MAX32_64 : signed(63 downto 0) := to_signed( 2147483647, 64);
    constant MIN32_64 : signed(63 downto 0) := to_signed(-2147483648, 64);
    variable y : signed(31 downto 0);
  begin
    if x > MAX32_64 then
      y := to_signed(2147483647, 32);
    elsif x < MIN32_64 then
      y := to_signed(-2147483648, 32);
    else
      y := resize(x, 32);
    end if;
    return std_logic_vector(y);
  end function;

  function mod3_inc(cur : integer; step : integer) return integer is
  begin
    return (cur + step) mod 3;
  end function;

  type slv32_arr_t     is array (0 to N_BANKS-1, 0 to 3) of std_logic_vector(31 downto 0);
  type slvaddr_arr_t   is array (0 to N_BANKS-1, 0 to 3) of std_logic_vector(ADDR_W-1 downto 0);
  type sl_arr_t        is array (0 to N_BANKS-1) of std_logic;
  type slv1_arr_t      is array (0 to N_BANKS-1) of std_logic_vector(0 downto 0);

  type bank_pipe_arr_t is array (natural range <>) of integer range 0 to N_BANKS-1;
  type idx_pipe_arr_t  is array (natural range <>) of unsigned(ADDR_W-1 downto 0);
  type sl_pipe_arr_t   is array (natural range <>) of std_logic;
  type coef_pipe_arr_t is array (natural range <>) of signed(COEF_W-1 downto 0);

  component klin_sample_bram is
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      dina  : in  std_logic_vector(31 downto 0);
      douta : out std_logic_vector(31 downto 0);

      clkb  : in  std_logic;
      enb   : in  std_logic;
      web   : in  std_logic_vector(0 downto 0);
      addrb : in  std_logic_vector(ADDR_W-1 downto 0);
      dinb  : in  std_logic_vector(31 downto 0);
      doutb : out std_logic_vector(31 downto 0)
    );
  end component;

  component klin_base_rom is
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      dina  : in  std_logic_vector(ADDR_W-1 downto 0);

      clkb  : in  std_logic;
      enb   : in  std_logic;
      addrb : in  std_logic_vector(ADDR_W-1 downto 0);
      doutb : out std_logic_vector(ADDR_W-1 downto 0)
    );
  end component;

  component klin_c0_rom is
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      dina  : in  std_logic_vector(COEF_W-1 downto 0);

      clkb  : in  std_logic;
      enb   : in  std_logic;
      addrb : in  std_logic_vector(ADDR_W-1 downto 0);
      doutb : out std_logic_vector(COEF_W-1 downto 0)
    );
  end component;

  component klin_c1_rom is
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      dina  : in  std_logic_vector(COEF_W-1 downto 0);

      clkb  : in  std_logic;
      enb   : in  std_logic;
      addrb : in  std_logic_vector(ADDR_W-1 downto 0);
      doutb : out std_logic_vector(COEF_W-1 downto 0)
    );
  end component;

  component klin_c2_rom is
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      dina  : in  std_logic_vector(COEF_W-1 downto 0);

      clkb  : in  std_logic;
      enb   : in  std_logic;
      addrb : in  std_logic_vector(ADDR_W-1 downto 0);
      doutb : out std_logic_vector(COEF_W-1 downto 0)
    );
  end component;

  component klin_c3_rom is
    port (
      clka  : in  std_logic;
      ena   : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(ADDR_W-1 downto 0);
      dina  : in  std_logic_vector(COEF_W-1 downto 0);

      clkb  : in  std_logic;
      enb   : in  std_logic;
      addrb : in  std_logic_vector(ADDR_W-1 downto 0);
      doutb : out std_logic_vector(COEF_W-1 downto 0)
    );
  end component;

  -- Bank state / capture
  signal bank_state      : bank_state_arr_t := (others => EMPTY);
  signal write_bank_hint : integer range 0 to N_BANKS-1 := 0;
  signal capture_bank    : integer range 0 to N_BANKS-1 := 0;
  signal capture_active  : std_logic := '0';
  signal capture_count   : unsigned(ADDR_W-1 downto 0) := (others => '0');
  signal overflow_int    : std_logic := '0';

  -- Issue scheduler
  signal issue_active : std_logic := '0';
  signal issue_bank   : integer range 0 to N_BANKS-1 := 0;
  signal issue_idx    : unsigned(ADDR_W-1 downto 0) := (others => '0');

  -- Sample BRAM write side
  signal sample_write_port_enable : std_logic := '1';
  signal sample_write_en          : slv1_arr_t := (others => (others => '0'));
  signal sample_write_addr        : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal sample_write_data        : std_logic_vector(31 downto 0) := (others => '0');

  -- Sample BRAM read side
  signal sample_read_enable : sl_arr_t := (others => '0');
  signal sample_read_addr   : slvaddr_arr_t := (others => (others => (others => '0')));
  signal sample_read_data   : slv32_arr_t;

  -- Calibration RAM read side
  signal cal_read_addr   : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal cal_read_enable : std_logic := '0';

  attribute mark_debug : string;

  signal base_read_data : std_logic_vector(ADDR_W-1 downto 0);
  signal c0_read_data   : std_logic_vector(COEF_W-1 downto 0);
  signal c1_read_data   : std_logic_vector(COEF_W-1 downto 0);
  signal c2_read_data   : std_logic_vector(COEF_W-1 downto 0);
  signal c3_read_data   : std_logic_vector(COEF_W-1 downto 0);
  
  attribute mark_debug of cal_read_enable : signal is "true";
  attribute mark_debug of base_read_data : signal is "true";
  attribute mark_debug of c0_read_data : signal is "true";
  attribute mark_debug of cal_read_addr : signal is "true";

  signal cal_base_we_vec : std_logic_vector(0 downto 0);
  signal cal_c0_we_vec   : std_logic_vector(0 downto 0);
  signal cal_c1_we_vec   : std_logic_vector(0 downto 0);
  signal cal_c2_we_vec   : std_logic_vector(0 downto 0);
  signal cal_c3_we_vec   : std_logic_vector(0 downto 0);

  -- Stage 0: issue tags
  signal valid_s0 : std_logic := '0';
  signal start_s0 : std_logic := '0';
  signal last_s0  : std_logic := '0';
  signal bank_s0  : integer range 0 to N_BANKS-1 := 0;
  signal idx_s0   : unsigned(ADDR_W-1 downto 0) := (others => '0');

  -- Through calibration latency
  signal valid_cal_pipe : sl_pipe_arr_t(0 to COEF_LAT) := (others => '0');
  signal start_cal_pipe : sl_pipe_arr_t(0 to COEF_LAT) := (others => '0');
  signal last_cal_pipe  : sl_pipe_arr_t(0 to COEF_LAT) := (others => '0');
  signal bank_cal_pipe  : bank_pipe_arr_t(0 to COEF_LAT) := (others => 0);
  signal idx_cal_pipe   : idx_pipe_arr_t(0 to COEF_LAT) := (others => (others => '0'));

  -- Registered sample request stage
  signal req_valid : std_logic := '0';
  signal req_start : std_logic := '0';
  signal req_last  : std_logic := '0';
  signal req_bank  : integer range 0 to N_BANKS-1 := 0;
  signal req_idx   : unsigned(ADDR_W-1 downto 0) := (others => '0');

  signal req_addr0 : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal req_addr1 : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal req_addr2 : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');
  signal req_addr3 : std_logic_vector(ADDR_W-1 downto 0) := (others => '0');

  signal req_c0, req_c1, req_c2, req_c3 : signed(COEF_W-1 downto 0) := (others => '0');

  -- Through sample BRAM latency
  signal valid_samp_pipe : sl_pipe_arr_t(0 to SAMP_LAT) := (others => '0');
  signal start_samp_pipe : sl_pipe_arr_t(0 to SAMP_LAT) := (others => '0');
  signal last_samp_pipe  : sl_pipe_arr_t(0 to SAMP_LAT) := (others => '0');
  signal bank_samp_pipe  : bank_pipe_arr_t(0 to SAMP_LAT) := (others => 0);
  signal idx_samp_pipe   : idx_pipe_arr_t(0 to SAMP_LAT) := (others => (others => '0'));

  signal c0_pipe         : coef_pipe_arr_t(0 to SAMP_LAT) := (others => (others => '0'));
  signal c1_pipe         : coef_pipe_arr_t(0 to SAMP_LAT) := (others => (others => '0'));
  signal c2_pipe         : coef_pipe_arr_t(0 to SAMP_LAT) := (others => (others => '0'));
  signal c3_pipe         : coef_pipe_arr_t(0 to SAMP_LAT) := (others => (others => '0'));

  -- Output retire stage tags
  signal valid_out : std_logic := '0';
  signal start_out : std_logic := '0';
  signal last_out  : std_logic := '0';
  signal bank_out  : integer range 0 to N_BANKS-1 := 0;
  signal idx_out   : unsigned(ADDR_W-1 downto 0) := (others => '0');

begin

  overflow <= overflow_int;

  cal_base_we_vec(0) <= cal_base_write_en;
  cal_c0_we_vec(0)   <= cal_c0_write_en;
  cal_c1_we_vec(0)   <= cal_c1_write_en;
  cal_c2_we_vec(0)   <= cal_c2_write_en;
  cal_c3_we_vec(0)   <= cal_c3_write_en;

  gen_b0 : for t in 0 to 3 generate
    u_sample_bram_b0 : klin_sample_bram
      port map (
        clka  => clk,
        ena   => sample_write_port_enable,
        wea   => sample_write_en(0),
        addra => sample_write_addr,
        dina  => sample_write_data,
        douta => open,
        clkb  => clk,
        enb   => sample_read_enable(0),
        web   => (others => '0'),
        addrb => sample_read_addr(0,t),
        dinb  => (others => '0'),
        doutb => sample_read_data(0,t)
      );
  end generate;

  gen_b1 : for t in 0 to 3 generate
    u_sample_bram_b1 : klin_sample_bram
      port map (
        clka  => clk,
        ena   => sample_write_port_enable,
        wea   => sample_write_en(1),
        addra => sample_write_addr,
        dina  => sample_write_data,
        douta => open,
        clkb  => clk,
        enb   => sample_read_enable(1),
        web   => (others => '0'),
        addrb => sample_read_addr(1,t),
        dinb  => (others => '0'),
        doutb => sample_read_data(1,t)
      );
  end generate;

  gen_b2 : for t in 0 to 3 generate
    u_sample_bram_b2 : klin_sample_bram
      port map (
        clka  => clk,
        ena   => sample_write_port_enable,
        wea   => sample_write_en(2),
        addra => sample_write_addr,
        dina  => sample_write_data,
        douta => open,
        clkb  => clk,
        enb   => sample_read_enable(2),
        web   => (others => '0'),
        addrb => sample_read_addr(2,t),
        dinb  => (others => '0'),
        doutb => sample_read_data(2,t)
      );
  end generate;

  u_base_ram : klin_base_rom
    port map (
      clka  => clk,
      ena   => '1',
      wea   => cal_base_we_vec,
      addra => cal_write_addr,
      dina  => cal_base_write_data,
      clkb  => clk,
      enb   => cal_read_enable,
      addrb => cal_read_addr,
      doutb => base_read_data
    );

  u_c0_ram : klin_c0_rom
    port map (
      clka  => clk,
      ena   => '1',
      wea   => cal_c0_we_vec,
      addra => cal_write_addr,
      dina  => cal_c0_write_data,
      clkb  => clk,
      enb   => cal_read_enable,
      addrb => cal_read_addr,
      doutb => c0_read_data
    );

  u_c1_ram : klin_c1_rom
    port map (
      clka  => clk,
      ena   => '1',
      wea   => cal_c1_we_vec,
      addra => cal_write_addr,
      dina  => cal_c1_write_data,
      clkb  => clk,
      enb   => cal_read_enable,
      addrb => cal_read_addr,
      doutb => c1_read_data
    );

  u_c2_ram : klin_c2_rom
    port map (
      clka  => clk,
      ena   => '1',
      wea   => cal_c2_we_vec,
      addra => cal_write_addr,
      dina  => cal_c2_write_data,
      clkb  => clk,
      enb   => cal_read_enable,
      addrb => cal_read_addr,
      doutb => c2_read_data
    );

  u_c3_ram : klin_c3_rom
    port map (
      clka  => clk,
      ena   => '1',
      wea   => cal_c3_we_vec,
      addra => cal_write_addr,
      dina  => cal_c3_write_data,
      clkb  => clk,
      enb   => cal_read_enable,
      addrb => cal_read_addr,
      doutb => c3_read_data
    );

  process(clk)
    variable p0, p1, p2, p3 : signed(63 downto 0);
    variable sum_next       : signed(63 downto 0);

    variable selected_bank_valid : std_logic;
    variable selected_bank       : integer range 0 to N_BANKS-1;
    variable candidate_bank      : integer range 0 to N_BANKS-1;

    variable found_ready         : std_logic;
    variable ready_bank          : integer range 0 to N_BANKS-1;

    variable next_issue_active   : std_logic;
    variable next_issue_bank     : integer range 0 to N_BANKS-1;
    variable next_issue_idx      : unsigned(ADDR_W-1 downto 0);

    variable bs_next             : bank_state_arr_t;

    variable issue_valid_now : std_logic;
    variable issue_start_now : std_logic;
    variable issue_last_now  : std_logic;
    variable issue_bank_now  : integer range 0 to N_BANKS-1;
    variable issue_idx_now   : unsigned(ADDR_W-1 downto 0);

    variable cal_keepalive_now : std_logic;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bank_state      <= (others => EMPTY);
        write_bank_hint <= 0;
        capture_bank    <= 0;
        capture_active  <= '0';
        capture_count   <= (others => '0');

        issue_active    <= '0';
        issue_bank      <= 0;
        issue_idx       <= (others => '0');

        sample_write_en   <= (others => (others => '0'));
        sample_write_addr <= (others => '0');
        sample_write_data <= (others => '0');

        for b in 0 to N_BANKS-1 loop
          sample_read_enable(b) <= '0';
          for t in 0 to 3 loop
            sample_read_addr(b,t) <= (others => '0');
          end loop;
        end loop;

        cal_read_enable <= '0';
        cal_read_addr   <= (others => '0');

        valid_s0 <= '0';
        start_s0 <= '0';
        last_s0  <= '0';
        bank_s0  <= 0;
        idx_s0   <= (others => '0');

        for i in 0 to COEF_LAT loop
          valid_cal_pipe(i) <= '0';
          start_cal_pipe(i) <= '0';
          last_cal_pipe(i)  <= '0';
          bank_cal_pipe(i)  <= 0;
          idx_cal_pipe(i)   <= (others => '0');
        end loop;

        req_valid <= '0';
        req_start <= '0';
        req_last  <= '0';
        req_bank  <= 0;
        req_idx   <= (others => '0');
        req_addr0 <= (others => '0');
        req_addr1 <= (others => '0');
        req_addr2 <= (others => '0');
        req_addr3 <= (others => '0');
        req_c0    <= (others => '0');
        req_c1    <= (others => '0');
        req_c2    <= (others => '0');
        req_c3    <= (others => '0');

        for i in 0 to SAMP_LAT loop
          valid_samp_pipe(i) <= '0';
          start_samp_pipe(i) <= '0';
          last_samp_pipe(i)  <= '0';
          bank_samp_pipe(i)  <= 0;
          idx_samp_pipe(i)   <= (others => '0');
          c0_pipe(i)         <= (others => '0');
          c1_pipe(i)         <= (others => '0');
          c2_pipe(i)         <= (others => '0');
          c3_pipe(i)         <= (others => '0');
        end loop;

        valid_out <= '0';
        start_out <= '0';
        last_out  <= '0';
        bank_out  <= 0;
        idx_out   <= (others => '0');

        overflow_int <= '0';

        str_out <= (others => '0');
        str_out_valid <= '0';
        start_of_ascan_out <= '0';

      else
        str_out_valid <= '0';
        start_of_ascan_out <= '0';

        for b in 0 to N_BANKS-1 loop
          sample_write_en(b) <= (others => '0');

          if bank_state(b) = READING then
            sample_read_enable(b) <= '1';
          else
            sample_read_enable(b) <= '0';
          end if;
        end loop;

        valid_s0 <= '0';
        start_s0 <= '0';
        last_s0  <= '0';

        issue_valid_now := '0';
        issue_start_now := '0';
        issue_last_now  := '0';
        issue_bank_now  := 0;
        issue_idx_now   := (others => '0');

        cal_keepalive_now := '0';
        bs_next := bank_state;

        --------------------------------------------------------------------
        -- Capture engine
        --------------------------------------------------------------------
        if capture_active = '0' then
          if (start_of_ascan = '1') and (cal_ready = '1') then
            selected_bank_valid := '0';
            selected_bank := write_bank_hint;

            for step in 0 to N_BANKS-1 loop
              candidate_bank := mod3_inc(write_bank_hint, step);
              if (bank_state(candidate_bank) = EMPTY) and (selected_bank_valid = '0') then
                selected_bank_valid := '1';
                selected_bank := candidate_bank;
              end if;
            end loop;

            if selected_bank_valid = '1' then
              capture_bank <= selected_bank;
              capture_active <= '1';
              capture_count <= (others => '0');
              bs_next(selected_bank) := FILLING;
              bank_state <= bs_next;
              overflow_int <= '0';

              if str_in_valid = '1' then
                sample_write_addr <= (others => '0');
                sample_write_data <= str_in;
                sample_write_en(selected_bank)(0) <= '1';

                if ASCAN_LEN = 1 then
                  capture_active <= '0';
                  bs_next(selected_bank) := READY;
                  bank_state <= bs_next;
                  write_bank_hint <= mod3_inc(selected_bank, 1);
                else
                  capture_count <= to_unsigned(1, ADDR_W);
                end if;
              end if;
            else
              overflow_int <= '1';
            end if;
          end if;

        else
          if str_in_valid = '1' then
            sample_write_addr <= std_logic_vector(capture_count);
            sample_write_data <= str_in;
            sample_write_en(capture_bank)(0) <= '1';

            if capture_count = to_unsigned(ASCAN_LEN-1, ADDR_W) then
              capture_active <= '0';
              bs_next(capture_bank) := READY;
              bank_state <= bs_next;
              write_bank_hint <= mod3_inc(capture_bank, 1);
            else
              capture_count <= capture_count + 1;
            end if;
          end if;
        end if;

        --------------------------------------------------------------------
        -- Issue scheduler
        --------------------------------------------------------------------
        next_issue_active := issue_active;
        next_issue_bank   := issue_bank;
        next_issue_idx    := issue_idx;

        if issue_active = '0' then
          found_ready := '0';
          ready_bank := 0;

          for step in 0 to N_BANKS-1 loop
            candidate_bank := mod3_inc(write_bank_hint, step);
            if (bank_state(candidate_bank) = READY) and (found_ready = '0') then
              found_ready := '1';
              ready_bank := candidate_bank;
            end if;
          end loop;

          if found_ready = '1' then
            next_issue_active := '1';
            next_issue_bank   := ready_bank;
            next_issue_idx    := (others => '0');

            bs_next := bank_state;
            bs_next(ready_bank) := READING;
            bank_state <= bs_next;
          end if;
        end if;

        if next_issue_active = '1' then
          issue_valid_now := '1';
          issue_bank_now  := next_issue_bank;
          issue_idx_now   := next_issue_idx;

          if next_issue_idx = to_unsigned(0, ADDR_W) then
            issue_start_now := '1';
          else
            issue_start_now := '0';
          end if;

          if next_issue_idx = to_unsigned(ASCAN_LEN-1, ADDR_W) then
            issue_last_now := '1';
          else
            issue_last_now := '0';
          end if;

          valid_s0 <= issue_valid_now;
          start_s0 <= issue_start_now;
          last_s0  <= issue_last_now;
          bank_s0  <= issue_bank_now;
          idx_s0   <= issue_idx_now;

          cal_read_addr <= std_logic_vector(issue_idx_now);

          if next_issue_idx = to_unsigned(ASCAN_LEN-1, ADDR_W) then
            found_ready := '0';
            ready_bank := next_issue_bank;

            for step in 1 to N_BANKS loop
              candidate_bank := mod3_inc(next_issue_bank, step);
              if (bank_state(candidate_bank) = READY) and (found_ready = '0') then
                found_ready := '1';
                ready_bank := candidate_bank;
              end if;
            end loop;

            if found_ready = '1' then
              next_issue_active := '1';
              next_issue_bank   := ready_bank;
              next_issue_idx    := (others => '0');

              bs_next := bank_state;
              bs_next(ready_bank) := READING;
              bank_state <= bs_next;
            else
              next_issue_active := '0';
            end if;
          else
            next_issue_idx := next_issue_idx + 1;
          end if;
        end if;

        issue_active <= next_issue_active;
        issue_bank   <= next_issue_bank;
        issue_idx    <= next_issue_idx;

        --------------------------------------------------------------------
        -- Calibration keepalive enable
        --------------------------------------------------------------------
        if issue_valid_now = '1' then
          cal_keepalive_now := '1';
        end if;

        for i in 0 to COEF_LAT-1 loop
          if valid_cal_pipe(i) = '1' then
            cal_keepalive_now := '1';
          end if;
        end loop;

        cal_read_enable <= cal_keepalive_now;

        --------------------------------------------------------------------
        -- Pipeline through calibration latency
        --------------------------------------------------------------------
        for i in COEF_LAT downto 1 loop
          valid_cal_pipe(i) <= valid_cal_pipe(i-1);
          start_cal_pipe(i) <= start_cal_pipe(i-1);
          last_cal_pipe(i)  <= last_cal_pipe(i-1);
          bank_cal_pipe(i)  <= bank_cal_pipe(i-1);
          idx_cal_pipe(i)   <= idx_cal_pipe(i-1);
        end loop;

        valid_cal_pipe(0) <= issue_valid_now;
        start_cal_pipe(0) <= issue_start_now;
        last_cal_pipe(0)  <= issue_last_now;
        bank_cal_pipe(0)  <= issue_bank_now;
        idx_cal_pipe(0)   <= issue_idx_now;

        --------------------------------------------------------------------
        -- Registered sample request stage
        --------------------------------------------------------------------
        req_valid <= '0';
        if valid_cal_pipe(COEF_LAT) = '1' then
          req_valid <= '1';
          req_start <= start_cal_pipe(COEF_LAT);
          req_last  <= last_cal_pipe(COEF_LAT);
          req_bank  <= bank_cal_pipe(COEF_LAT);
          req_idx   <= idx_cal_pipe(COEF_LAT);

          req_addr0 <= std_logic_vector(clamp_addr(to_integer(unsigned(base_read_data)) - 1));
          req_addr1 <= std_logic_vector(clamp_addr(to_integer(unsigned(base_read_data))));
          req_addr2 <= std_logic_vector(clamp_addr(to_integer(unsigned(base_read_data)) + 1));
          req_addr3 <= std_logic_vector(clamp_addr(to_integer(unsigned(base_read_data)) + 2));

          req_c0 <= signed(c0_read_data);
          req_c1 <= signed(c1_read_data);
          req_c2 <= signed(c2_read_data);
          req_c3 <= signed(c3_read_data);
        end if;

        --------------------------------------------------------------------
        -- Launch sample read from request stage
        --------------------------------------------------------------------
        valid_samp_pipe(0) <= '0';
        if req_valid = '1' then
          sample_read_addr(req_bank,0) <= req_addr0;
          sample_read_addr(req_bank,1) <= req_addr1;
          sample_read_addr(req_bank,2) <= req_addr2;
          sample_read_addr(req_bank,3) <= req_addr3;

          valid_samp_pipe(0) <= '1';
          start_samp_pipe(0) <= req_start;
          last_samp_pipe(0)  <= req_last;
          bank_samp_pipe(0)  <= req_bank;
          idx_samp_pipe(0)   <= req_idx;

          c0_pipe(0) <= req_c0;
          c1_pipe(0) <= req_c1;
          c2_pipe(0) <= req_c2;
          c3_pipe(0) <= req_c3;
        end if;

        --------------------------------------------------------------------
        -- Pipeline through sample BRAM latency
        --------------------------------------------------------------------
        for i in SAMP_LAT downto 1 loop
          valid_samp_pipe(i) <= valid_samp_pipe(i-1);
          start_samp_pipe(i) <= start_samp_pipe(i-1);
          last_samp_pipe(i)  <= last_samp_pipe(i-1);
          bank_samp_pipe(i)  <= bank_samp_pipe(i-1);
          idx_samp_pipe(i)   <= idx_samp_pipe(i-1);

          c0_pipe(i) <= c0_pipe(i-1);
          c1_pipe(i) <= c1_pipe(i-1);
          c2_pipe(i) <= c2_pipe(i-1);
          c3_pipe(i) <= c3_pipe(i-1);
        end loop;

        --------------------------------------------------------------------
        -- Output / retire stage
        --------------------------------------------------------------------
        valid_out <= '0';
        if valid_samp_pipe(SAMP_LAT) = '1' then
          p0 := resize(shift_right(resize(signed(sample_read_data(bank_samp_pipe(SAMP_LAT),0)), 128) * resize(c0_pipe(SAMP_LAT), 128), FRAC_BITS), 64);
          p1 := resize(shift_right(resize(signed(sample_read_data(bank_samp_pipe(SAMP_LAT),1)), 128) * resize(c1_pipe(SAMP_LAT), 128), FRAC_BITS), 64);
          p2 := resize(shift_right(resize(signed(sample_read_data(bank_samp_pipe(SAMP_LAT),2)), 128) * resize(c2_pipe(SAMP_LAT), 128), FRAC_BITS), 64);
          p3 := resize(shift_right(resize(signed(sample_read_data(bank_samp_pipe(SAMP_LAT),3)), 128) * resize(c3_pipe(SAMP_LAT), 128), FRAC_BITS), 64);

          sum_next := p0 + p1 + p2 + p3;

          str_out <= sat32(sum_next);
          str_out_valid <= '1';
          start_of_ascan_out <= start_samp_pipe(SAMP_LAT);

          valid_out <= '1';
          start_out <= start_samp_pipe(SAMP_LAT);
          last_out  <= last_samp_pipe(SAMP_LAT);
          bank_out  <= bank_samp_pipe(SAMP_LAT);
          idx_out   <= idx_samp_pipe(SAMP_LAT);
        end if;

        if valid_out = '1' and last_out = '1' then
          bs_next := bank_state;
          bs_next(bank_out) := EMPTY;
          bank_state <= bs_next;
        end if;
      end if;
    end if;
  end process;

end architecture;