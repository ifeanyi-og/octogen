library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mag_calc is
    Port (
        clk        : in  std_logic;
        rst        : in  std_logic;

        re_in      : in  signed(31 downto 0);
        im_in      : in  signed(31 downto 0);
        in_valid   : in  std_logic;

        mag_sq_out : out unsigned(64 downto 0);
        out_valid  : out std_logic
    );
end mag_calc;

architecture rtl of mag_calc is

    -- Stage 0: register inputs
    signal re_s0      : signed(31 downto 0) := (others => '0');
    signal im_s0      : signed(31 downto 0) := (others => '0');
    signal valid_s0   : std_logic := '0';

    -- Stage 1: squared terms
    signal re_sq_s1   : signed(63 downto 0) := (others => '0');
    signal im_sq_s1   : signed(63 downto 0) := (others => '0');
    signal valid_s1   : std_logic := '0';

    -- Stage 2: sum of squares
    signal mag_sq_s2  : unsigned(64 downto 0) := (others => '0');
    signal valid_s2   : std_logic := '0';

begin

    process(clk)
        variable re_sq_v : signed(63 downto 0);
        variable im_sq_v : signed(63 downto 0);
        variable sum_v   : unsigned(64 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                re_s0      <= (others => '0');
                im_s0      <= (others => '0');
                valid_s0   <= '0';

                re_sq_s1   <= (others => '0');
                im_sq_s1   <= (others => '0');
                valid_s1   <= '0';

                mag_sq_s2  <= (others => '0');
                valid_s2   <= '0';

            else
                ----------------------------------------------------------------
                -- Stage 0: register inputs
                ----------------------------------------------------------------
                re_s0    <= re_in;
                im_s0    <= im_in;
                valid_s0 <= in_valid;

                ----------------------------------------------------------------
                -- Stage 1: square real and imaginary parts
                ----------------------------------------------------------------
                re_sq_v := re_s0 * re_s0;
                im_sq_v := im_s0 * im_s0;

                re_sq_s1 <= re_sq_v;
                im_sq_s1 <= im_sq_v;
                valid_s1 <= valid_s0;

                ----------------------------------------------------------------
                -- Stage 2: add squares
                ----------------------------------------------------------------
                sum_v := resize(unsigned(re_sq_s1), 65) + resize(unsigned(im_sq_s1), 65);

                mag_sq_s2 <= sum_v;
                valid_s2  <= valid_s1;
            end if;
        end if;
    end process;

    mag_sq_out <= mag_sq_s2;
    out_valid  <= valid_s2;

end rtl;
