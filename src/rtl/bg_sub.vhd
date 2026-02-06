library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
library xil_defaultlib;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity bg_sub is
    generic (
        ASCAN_LEN : natural := 496;
        ADDR_W    : natural := 9
    );
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           
           str_in : in STD_LOGIC_VECTOR (31 downto 0);
           str_in_valid : in std_logic ;
           start_of_ascan : in std_logic;
           
           str_out : out STD_LOGIC_VECTOR (31 downto 0);
           str_out_valid : out std_logic
    );
end bg_sub;

architecture Behavioral of bg_sub is

-- Address counter (0..ASCAN_LEN-1, wraps)
  signal rd_addr  : unsigned(ADDR_W-1 downto 0) := (others => '0');

  -- BRAM output (background value)
  signal bg_dout  : std_logic_vector(31 downto 0) := (others => '0');

  constant BRAM_LAT : natural := 3; --2 clock delay on BRAM block
  -- Pipeline regs to align with synchronous BRAM read latency (1 cycle)
  type signed_pipe_t is array (0 to BRAM_LAT-1) of signed(31 downto 0);
  type logic_pipe_t  is array (0 to BRAM_LAT-1) of std_logic;

  signal x_pipe : signed_pipe_t := (others => (others => '0'));
  signal v_pipe : logic_pipe_t  := (others => '0');

  -- Subtraction result
  signal y        : signed(31 downto 0);
    

component bgsub_blk_mem_gen is
  port (
    clka  : in  std_logic;
    ena   : in  std_logic;
    wea   : in  std_logic_vector(0 downto 0);
    addra : in  std_logic_vector(8 downto 0);
    dina  : in  std_logic_vector(31 downto 0);

    clkb  : in  std_logic;
    enb   : in  std_logic;
    addrb : in  std_logic_vector(8 downto 0);
    doutb : out std_logic_vector(31 downto 0)
  );
end component;

--for u_bg_bram : bgsub_blk_mem_gen
--    use entity xil_defaultlib.bgsub_blk_mem_gen;
begin

-- BRAM IP (Block Memory Generator) instance
-- Using BRAM_PORTB for synchronous read:
--   addrb -> background sample index
--   doutb -> background value (valid 1 clk later)

u_bg_bram : bgsub_blk_mem_gen
    port map(
        -------------------------------------------------------------------
        -- BRAM_PORTA (unused write/read port) - disable
        -------------------------------------------------------------------
        --addra  => (others => '0'),
        addra => (others => '0'),
        clka   => clk,
        dina  => (others => '0'),
        ena    => '0',
        wea => (others => '0'),
    
        -------------------------------------------------------------------
        -- BRAM_PORTB (READ port) - this is what bg_sub uses
        -------------------------------------------------------------------
        addrb  => std_logic_vector(rd_addr),  -- 9-bit address
        clkb   => clk,
        doutb  => bg_dout,                    -- 32-bit background output
        enb    => '1'
    );

process (clk)
begin
  if rising_edge(clk) then
    if rst = '1' then
      rd_addr <= (others => '0');
      x_pipe  <= (others => (others => '0'));
      v_pipe  <= (others => '0');

    else
      -- Address counter: sample index used for the *current* input
      if start_of_ascan = '1' then
        rd_addr <= (others => '0');
      elsif str_in_valid = '1' then
        if rd_addr = to_unsigned(ASCAN_LEN-1, ADDR_W) then
          rd_addr <= (others => '0');
        else
          rd_addr <= rd_addr + 1;
        end if;
      end if;

      -- Pipeline stage 0 capture
      if str_in_valid = '1' then
        x_pipe(0) <= signed(str_in);
      end if;
      v_pipe(0) <= str_in_valid;

      -- Shift the pipeline to match BRAM_LAT
      if BRAM_LAT > 1 then
        for k in 1 to BRAM_LAT-1 loop
          x_pipe(k) <= x_pipe(k-1);
          v_pipe(k) <= v_pipe(k-1);
        end loop;
      end if;

    end if;
  end if;
end process;

--signed subtraction
y <= x_pipe(BRAM_LAT-1) - signed(bg_dout);

str_out_valid <= v_pipe(BRAM_LAT-1);
str_out <= std_logic_vector(y);

end Behavioral;
