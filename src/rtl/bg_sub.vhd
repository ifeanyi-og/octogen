library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
library xil_defaultlib;

entity bg_sub is
    generic (
        ASCAN_LEN : natural := 1024;
        ADDR_W    : natural := 10
    );
    Port (
        clk                : in  STD_LOGIC;
        rst                : in  STD_LOGIC;

        -- streaming sample input
        str_in             : in  STD_LOGIC_VECTOR (31 downto 0);
        str_in_valid       : in  std_logic;
        start_of_ascan     : in  std_logic;

        -- background BRAM write interface (Port A)
        bg_wr_en           : in  std_logic;
        bg_wr_we           : in  std_logic_vector(0 downto 0);
        bg_wr_addr         : in  std_logic_vector(ADDR_W-1 downto 0);
        bg_wr_data         : in  std_logic_vector(31 downto 0);

        -- streaming output
        str_out            : out STD_LOGIC_VECTOR (31 downto 0);
        str_out_valid      : out std_logic;
        start_of_ascan_out : out std_logic
    );
end bg_sub;

architecture Behavioral of bg_sub is

    -- Address counter for BRAM read side (Port B)
    signal rd_addr : unsigned(ADDR_W-1 downto 0) := (others => '0');

    -- BRAM output (background value)
    signal bg_dout : std_logic_vector(31 downto 0) := (others => '0');

    -- Effective measured latency through BRAM path
    constant BRAM_LAT : natural := 3;

    -- Pipelines to align data/valid/start pulse with BRAM output
    type signed_pipe_t is array (0 to BRAM_LAT-1) of signed(31 downto 0);
    type logic_pipe_t  is array (0 to BRAM_LAT-1) of std_logic;

    signal x_pipe    : signed_pipe_t := (others => (others => '0'));
    signal v_pipe    : logic_pipe_t  := (others => '0');
    signal soas_pipe : logic_pipe_t  := (others => '0');

    signal y : signed(31 downto 0);

    component bgsub_blk_mem_gen is
        port (
            clka  : in  std_logic;
            ena   : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(9 downto 0);
            dina  : in  std_logic_vector(31 downto 0);

            clkb  : in  std_logic;
            enb   : in  std_logic;
            addrb : in  std_logic_vector(9 downto 0);
            doutb : out std_logic_vector(31 downto 0)
        );
    end component;

begin

    --------------------------------------------------------------------
    -- BRAM instance
    --   Port A: runtime write port for background loading
    --   Port B: runtime read port for streaming subtraction
    --------------------------------------------------------------------
    u_bg_bram : bgsub_blk_mem_gen
        port map (
            -- Port A: exposed write side
            clka  => clk,
            ena   => bg_wr_en,
            wea   => bg_wr_we,
            addra => bg_wr_addr,
            dina  => bg_wr_data,

            -- Port B: internal read side
            clkb  => clk,
            enb   => str_in_valid,
            addrb => std_logic_vector(rd_addr),
            doutb => bg_dout
        );

    --------------------------------------------------------------------
    -- Read-side datapath
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rd_addr   <= (others => '0');
                x_pipe    <= (others => (others => '0'));
                v_pipe    <= (others => '0');
                soas_pipe <= (others => '0');

            else
                -- Reset BRAM read index at start of each A-scan
                if start_of_ascan = '1' then
                    rd_addr <= (others => '0');
                elsif str_in_valid = '1' then
                    if rd_addr = to_unsigned(ASCAN_LEN - 1, ADDR_W) then
                        rd_addr <= (others => '0');
                    else
                        rd_addr <= rd_addr + 1;
                    end if;
                end if;

                -- stage 0 capture
                if str_in_valid = '1' then
                    x_pipe(0) <= signed(str_in);
                end if;
                v_pipe(0)    <= str_in_valid;
                soas_pipe(0) <= start_of_ascan;

                -- shift alignment pipelines
                if BRAM_LAT > 1 then
                    for k in 1 to BRAM_LAT-1 loop
                        x_pipe(k)    <= x_pipe(k-1);
                        v_pipe(k)    <= v_pipe(k-1);
                        soas_pipe(k) <= soas_pipe(k-1);
                    end loop;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Output datapath
    --------------------------------------------------------------------
    y <= x_pipe(BRAM_LAT-1) - signed(bg_dout);

    str_out            <= std_logic_vector(y);
    str_out_valid      <= v_pipe(BRAM_LAT-1);
    start_of_ascan_out <= soas_pipe(BRAM_LAT-1) and v_pipe(BRAM_LAT-1);

end Behavioral;