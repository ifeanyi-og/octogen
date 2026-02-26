
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_k_lin is
end entity;

architecture sim of tb_k_lin is
  constant CLK_PER : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal str_in         : std_logic_vector(31 downto 0) := (others => '0');
  signal str_in_valid   : std_logic := '0';
  signal start_of_ascan : std_logic := '0';

  signal str_out       : std_logic_vector(31 downto 0);
  signal str_out_valid : std_logic;

  signal exp_idx : integer := 0;
begin
  -- clock
  clk <= not clk after CLK_PER/2;

  -- DUT
  dut : entity work.k_lin
    generic map (
      ASCAN_LEN => 512,
      ADDR_W    => 9,
      COEF_W    => 18,
      FRAC_BITS => 16,
      COEF_LAT  => 2,   -- match your IP latency settings
      SAMP_LAT  => 1    -- match your BRAM read latency setting
    )
    port map (
      clk => clk,
      rst => rst,
      str_in => str_in,
      str_in_valid => str_in_valid,
      start_of_ascan => start_of_ascan,
      str_out => str_out,
      str_out_valid => str_out_valid
    );

  -- stimulus
  process
  begin
    -- reset
    rst <= '1';
    str_in_valid <= '0';
    start_of_ascan <= '0';
    wait for 5*CLK_PER;
    rst <= '0';
    wait for 2*CLK_PER;

    -- start pulse
    start_of_ascan <= '1';
    wait for CLK_PER;
    start_of_ascan <= '0';

    -- drive ramp: x[n] = n
    for n in 0 to 511 loop
      str_in <= std_logic_vector(to_signed(n, 32));
      str_in_valid <= '1';
      wait for CLK_PER;
    end loop;

    str_in_valid <= '0';
    str_in <= (others => '0');

    -- let outputs finish
    wait for 10000*CLK_PER;

    assert false report "Simulation finished." severity failure;
  end process;

  -- checker (identity mapping expected)
  process(clk)
    variable y : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        exp_idx <= 0;
      else
        if str_out_valid = '1' then
          y := to_integer(signed(str_out));

          if y /= exp_idx then
            report "Mismatch at out_idx=" & integer'image(exp_idx) &
                   " got=" & integer'image(y) severity error;
          else
            report "Matching out_idx=" & integer'image(exp_idx) & " expected=" & integer'image(y) severity note;
          end if;

          exp_idx <= exp_idx + 1;
        end if;
      end if;
    end if;
  end process;

end architecture;
