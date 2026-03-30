library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity tb_bg_sub is
end tb_bg_sub;

architecture Behavioral of tb_bg_sub is

    constant CLK_PERIOD : time := 10 ns;
    constant ASCAN_LEN  : integer := 1024;
    constant NUM_SCANS  : integer := 3;

    signal clk                : std_logic := '0';
    signal rst                : std_logic := '1';

    -- stream input side
    signal str_in             : std_logic_vector(31 downto 0) := (others => '0');
    signal str_in_valid       : std_logic := '0';
    signal start_of_ascan     : std_logic := '0';

    -- BRAM write interface
    signal bg_wr_en           : std_logic := '0';
    signal bg_wr_we           : std_logic_vector(0 downto 0) := (others => '0');
    signal bg_wr_addr         : std_logic_vector(9 downto 0) := (others => '0');
    signal bg_wr_data         : std_logic_vector(31 downto 0) := (others => '0');

    -- outputs
    signal str_out            : std_logic_vector(31 downto 0);
    signal str_out_valid      : std_logic;
    signal start_of_ascan_out : std_logic;

    function to_slv32(x : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(x, 32));
    end function;

begin

    clk <= not clk after CLK_PERIOD/2;

    dut : entity work.bg_sub
        generic map (
            ASCAN_LEN => 1024,
            ADDR_W    => 10
        )
        port map (
            clk                => clk,
            rst                => rst,

            str_in             => str_in,
            str_in_valid       => str_in_valid,
            start_of_ascan     => start_of_ascan,

            bg_wr_en           => bg_wr_en,
            bg_wr_we           => bg_wr_we,
            bg_wr_addr         => bg_wr_addr,
            bg_wr_data         => bg_wr_data,

            str_out            => str_out,
            str_out_valid      => str_out_valid,
            start_of_ascan_out => start_of_ascan_out
        );

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim : process
        variable i : integer;
        variable s : integer;
    begin
        rst            <= '1';
        str_in         <= (others => '0');
        str_in_valid   <= '0';
        start_of_ascan <= '0';

        bg_wr_en       <= '0';
        bg_wr_we       <= "0";
        bg_wr_addr     <= (others => '0');
        bg_wr_data     <= (others => '0');

        wait for 5*CLK_PERIOD;
        rst <= '0';
        wait for 2*CLK_PERIOD;

        ----------------------------------------------------------------
        -- Write 1024 ones into BRAM
        ----------------------------------------------------------------
        bg_wr_en   <= '1';
        bg_wr_we   <= "1";
        bg_wr_data <= to_slv32(1);

        for i in 0 to ASCAN_LEN-1 loop
            bg_wr_addr <= std_logic_vector(to_unsigned(i, 10));
            wait for CLK_PERIOD;
        end loop;

        bg_wr_en   <= '0';
        bg_wr_we   <= "0";
        bg_wr_addr <= (others => '0');
        bg_wr_data <= (others => '0');

        wait for 3*CLK_PERIOD;

        ----------------------------------------------------------------
        -- Stream NUM_SCANS A-scans back-to-back, no gap between scans
        -- scan 1: 1000+i
        -- scan 2: 2000+i
        -- scan 3: 3000+i
        ----------------------------------------------------------------
        str_in_valid <= '1';

        for s in 0 to NUM_SCANS-1 loop
            for i in 0 to ASCAN_LEN-1 loop
                if i = 0 then
                    start_of_ascan <= '1';
                else
                    start_of_ascan <= '0';
                end if;

                str_in <= to_slv32((s+1)*1000 + i);
                wait for CLK_PERIOD;
            end loop;
        end loop;

        str_in_valid   <= '0';
        start_of_ascan <= '0';
        str_in         <= (others => '0');

        wait for 30*CLK_PERIOD;

        assert false report "TB finished successfully" severity failure;
    end process;

    --------------------------------------------------------------------
    -- Checker
    --------------------------------------------------------------------
    check : process(clk)
        variable out_seen_in_scan : integer := 0;
        variable scan_idx         : integer := 0;
        variable y_int            : integer;
        variable expected_y       : integer;
        variable base_val         : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                out_seen_in_scan := 0;
                scan_idx         := 0;

            else
                if str_out_valid = '1' then
                    y_int := to_integer(signed(str_out));

                    -- input base is 1000, 2000, 3000...
                    base_val   := (scan_idx + 1) * 1000;
                    expected_y := (base_val + out_seen_in_scan) - 1;

                    if y_int /= expected_y then
                        assert false
                            report "Mismatch in scan " & integer'image(scan_idx + 1) &
                                   ", output sample " & integer'image(out_seen_in_scan) &
                                   " : got " & integer'image(y_int) &
                                   " expected " & integer'image(expected_y)
                            severity failure;
                    end if;

                    if out_seen_in_scan = 0 then
                        if start_of_ascan_out /= '1' then
                            assert false
                                report "start_of_ascan_out missing on first output of scan " &
                                       integer'image(scan_idx + 1)
                                severity failure;
                        end if;
                    else
                        if start_of_ascan_out /= '0' then
                            assert false
                                report "start_of_ascan_out asserted unexpectedly in scan " &
                                       integer'image(scan_idx + 1) &
                                       " at output sample " & integer'image(out_seen_in_scan)
                                severity failure;
                        end if;
                    end if;

                    out_seen_in_scan := out_seen_in_scan + 1;

                    if out_seen_in_scan = ASCAN_LEN then
                        out_seen_in_scan := 0;
                        scan_idx := scan_idx + 1;
                    end if;

                else
                    if start_of_ascan_out = '1' then
                        assert false
                            report "start_of_ascan_out asserted while str_out_valid = 0"
                            severity failure;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;