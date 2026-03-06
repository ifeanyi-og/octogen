
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_magnitude_sq is
end tb_magnitude_sq;

architecture Behavioral of tb_magnitude_sq is
    --------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------
    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';

    signal re_in      : signed(31 downto 0) := (others => '0');
    signal im_in      : signed(31 downto 0) := (others => '0');
    signal in_valid   : std_logic := '0';

    signal mag_sq_out : unsigned(64 downto 0);
    signal out_valid  : std_logic;

    constant CLK_PER  : time := 10 ns;
begin
    --------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------
    clk <= not clk after CLK_PER/2;

    --------------------------------------------------------------------
    -- DUT instantiation
    --------------------------------------------------------------------
    uut: entity work.mag_calc
        port map (
            clk        => clk,
            rst        => rst,
            re_in      => re_in,
            im_in      => im_in,
            in_valid   => in_valid,
            mag_sq_out => mag_sq_out,
            out_valid  => out_valid
        );

    --------------------------------------------------------------------
    -- Stimulus + checking
    --------------------------------------------------------------------
    stim_proc: process

        ----------------------------------------------------------------
        -- Helper procedure:
        -- drives one input for one cycle
        ----------------------------------------------------------------
        procedure send_sample (
            constant re_val : integer;
            constant im_val : integer
        ) is
        begin
            re_in    <= to_signed(re_val, 32);
            im_in    <= to_signed(im_val, 32);
            in_valid <= '1';
            wait until rising_edge(clk);

            re_in    <= (others => '0');
            im_in    <= (others => '0');
            in_valid <= '0';
        end procedure;

        ----------------------------------------------------------------
        -- Helper procedure:
        -- waits for valid output and checks exact value
        ----------------------------------------------------------------
        procedure expect_output (
            constant expected_val : integer;
            constant test_name    : string
        ) is
        begin
            -- Wait until DUT says output is valid
            loop
                wait until rising_edge(clk);
                exit when out_valid = '1';
            end loop;

            assert mag_sq_out = to_unsigned(expected_val, 65)
                report "FAIL: " & test_name &
                       " | expected " & integer'image(expected_val) &
                       " | got different result"
                severity error;

            report "PASS: " & test_name &
                   " | output = " & integer'image(expected_val)
                severity note;
        end procedure;

    begin
        ----------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------
        rst <= '1';
        re_in <= (others => '0');
        im_in <= (others => '0');
        in_valid <= '0';

        wait for 30 ns;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        ----------------------------------------------------------------
        -- Test 1: 3^2 + 4^2 = 25
        ----------------------------------------------------------------
        send_sample(3, 4);
        expect_output(25, "Test 1: (3,4)");

        ----------------------------------------------------------------
        -- Test 2: 5^2 + 12^2 = 169
        ----------------------------------------------------------------
        send_sample(5, 12);
        expect_output(169, "Test 2: (5,12)");

        ----------------------------------------------------------------
        -- Test 3: (-7)^2 + 24^2 = 49 + 576 = 625
        ----------------------------------------------------------------
        send_sample(-7, 24);
        expect_output(625, "Test 3: (-7,24)");

        ----------------------------------------------------------------
        -- Test 4: 0^2 + 0^2 = 0
        ----------------------------------------------------------------
        send_sample(0, 0);
        expect_output(0, "Test 4: (0,0)");

        ----------------------------------------------------------------
        -- Test 5: (-1)^2 + (-1)^2 = 2
        ----------------------------------------------------------------
        send_sample(-1, -1);
        expect_output(2, "Test 5: (-1,-1)");

        ----------------------------------------------------------------
        -- Test 6: back-to-back samples
        ----------------------------------------------------------------
        re_in    <= to_signed(8, 32);
        im_in    <= to_signed(6, 32);
        in_valid <= '1';
        wait until rising_edge(clk);

        re_in    <= to_signed(1, 32);
        im_in    <= to_signed(2, 32);
        in_valid <= '1';
        wait until rising_edge(clk);

        re_in    <= (others => '0');
        im_in    <= (others => '0');
        in_valid <= '0';

        expect_output(100, "Test 6a: (8,6)");
        expect_output(5,   "Test 6b: (1,2)");

        ----------------------------------------------------------------
        -- Done
        ----------------------------------------------------------------
        report "All tests completed." severity note;
        wait;
    end process;
end Behavioral;
