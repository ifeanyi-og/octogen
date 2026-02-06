----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/06/2026 10:17:13 AM
-- Design Name: 
-- Module Name: tb_bg_sub - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_bg_sub is
--    Port ( clk : in STD_LOGIC;
--           rst : in STD_LOGIC;
--           str_in : in STD_LOGIC_VECTOR (31 downto 0);
--           str_in_valid : in STD_LOGIC;
--           start_of_ascan : in STD_LOGIC;
--           str_out : out STD_LOGIC_VECTOR (31 downto 0);
--           str_out_valid : out STD_LOGIC);
end tb_bg_sub;

architecture Behavioral of tb_bg_sub is
  constant CLK_PERIOD : time := 10 ns;

  signal clk            : std_logic := '0';
  signal rst            : std_logic := '1';

  signal str_in         : std_logic_vector(31 downto 0) := (others => '0');
  signal str_in_valid   : std_logic := '0';
  signal start_of_ascan : std_logic := '0';

  signal str_out        : std_logic_vector(31 downto 0);
  signal str_out_valid  : std_logic;

  -- convenience
  function to_slv32(x : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_signed(x, 32));
  end function;
begin
 -- clock
  clk <= not clk after CLK_PERIOD/2;

  -- DUT
  dut : entity work.bg_sub
    generic map (
      ASCAN_LEN => 496,
      ADDR_W    => 9
    )
    port map (
      clk            => clk,
      rst            => rst,
      str_in         => str_in,
      str_in_valid   => str_in_valid,
      start_of_ascan => start_of_ascan,
      str_out        => str_out,
      str_out_valid  => str_out_valid
    );

  -- stimulus
  stim : process
    variable i : integer;
  begin
    -- reset
    rst <= '1';
    str_in_valid <= '0';
    start_of_ascan <= '0';
    wait for 5*CLK_PERIOD;
    rst <= '0';
    wait for 2*CLK_PERIOD;

    -- pulse start_of_ascan aligned with first valid sample
    start_of_ascan <= '1';
    str_in_valid   <= '1';
    str_in         <= to_slv32(1000 + 0);
    wait for CLK_PERIOD;
    start_of_ascan <= '0';

    -- drive 496 samples: x[i] = 1000 + i
    for i in 1 to 495 loop
      str_in <= to_slv32(1000 + i);
      wait for CLK_PERIOD;
    end loop;

    -- stop driving
    str_in_valid <= '0';
    str_in <= (others => '0');
    wait for 20*CLK_PERIOD;

    assert false report "TB finished" severity failure;
  end process;

  -- checker: expect constant 1000 (with 1-cycle latency)
  check : process(clk)
    variable seen : integer := 0;
    variable y_int : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        seen := 0;
      else
        if str_out_valid = '1' then
          y_int := to_integer(signed(str_out));

          -- For bg[i]=i and x[i]=1000+i, y should be 1000 always.
          if y_int /= 1000 then
            assert false
              report "Mismatch at output sample " & integer'image(seen) &
                     " : got " & integer'image(y_int) & " expected 1000"
              severity warning;
          end if;

          seen := seen + 1;
        end if;
      end if;
    end if;
  end process;


end Behavioral;
