----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/06/2026 10:40:14 PM
-- Design Name: 
-- Module Name: fft_dummy - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

entity fft_dummy is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;  -- active-high synchronous reset

        ----------------------------------------------------------------
        -- Valid-only upstream interface (from dispersion compensation)
        ----------------------------------------------------------------
        in_real         : in  signed(31 downto 0);
        in_imag         : in  signed(31 downto 0);
        in_valid        : in  std_logic;
        start_of_ascan  : in  std_logic;
        end_of_ascan    : in  std_logic;

        ----------------------------------------------------------------
        -- Valid-only downstream interface (to magnitude-squared block)
        ----------------------------------------------------------------
        out_real            : out signed(31 downto 0);
        out_imag            : out signed(31 downto 0);
        out_valid           : out std_logic;
        start_of_ascan_out  : out std_logic;

        ----------------------------------------------------------------
        -- Debug outputs from FFT IP
        ----------------------------------------------------------------
        dbg_event_frame_started         : out std_logic;
        dbg_event_tlast_unexpected      : out std_logic;
        dbg_event_tlast_missing         : out std_logic;
        dbg_event_status_channel_halt   : out std_logic;
        dbg_event_data_in_channel_halt  : out std_logic;
        dbg_event_data_out_channel_halt : out std_logic;
        dbg_cfg_done : out std_logic;

        ----------------------------------------------------------------
        -- Debug: asserted if upstream presented valid data while FFT
        -- input was not ready. This should NEVER happen in your intended
        -- operating mode.
        ----------------------------------------------------------------
        dbg_input_backpressure_violation : out std_logic
    );
end entity fft_dummy;

architecture rtl of fft_dummy is

    -- Fixed dummy latency for integration / logging tests
    constant DUMMY_LAT : natural := 3;

    type signed_pipe_t is array (0 to DUMMY_LAT-1) of signed(31 downto 0);
    type logic_pipe_t  is array (0 to DUMMY_LAT-1) of std_logic;

    signal re_pipe   : signed_pipe_t := (others => (others => '0'));
    signal im_pipe   : signed_pipe_t := (others => (others => '0'));
    signal v_pipe    : logic_pipe_t  := (others => '0');
    signal soa_pipe  : logic_pipe_t  := (others => '0');
    signal eoa_pipe  : logic_pipe_t  := (others => '0');

    signal frame_active : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                re_pipe      <= (others => (others => '0'));
                im_pipe      <= (others => (others => '0'));
                v_pipe       <= (others => '0');
                soa_pipe     <= (others => '0');
                eoa_pipe     <= (others => '0');
                frame_active <= '0';

                out_real           <= (others => '0');
                out_imag           <= (others => '0');
                out_valid          <= '0';
                start_of_ascan_out <= '0';

                dbg_event_frame_started         <= '0';
                dbg_event_tlast_unexpected      <= '0';
                dbg_event_tlast_missing         <= '0';
                dbg_event_status_channel_halt   <= '0';
                dbg_event_data_in_channel_halt  <= '0';
                dbg_event_data_out_channel_halt <= '0';
                dbg_cfg_done                    <= '0';
                dbg_input_backpressure_violation<= '0';

            else
                -- Defaults: pulse-style debug outputs deassert unless triggered
                dbg_event_frame_started         <= '0';
                dbg_event_tlast_unexpected      <= '0';
                dbg_event_tlast_missing         <= '0';
                dbg_event_status_channel_halt   <= '0';
                dbg_event_data_in_channel_halt  <= '0';
                dbg_event_data_out_channel_halt <= '0';
                dbg_input_backpressure_violation<= '0';
                dbg_cfg_done                    <= '1';

                -- Simple protocol checking for debug visibility
                if (in_valid = '1') and (start_of_ascan = '1') then
                    dbg_event_frame_started <= '1';

                    if frame_active = '1' then
                        dbg_event_tlast_missing <= '1';
                    end if;

                    frame_active <= '1';
                end if;

                if (in_valid = '1') and (end_of_ascan = '1') then
                    if frame_active = '0' then
                        dbg_event_tlast_unexpected <= '1';
                    end if;

                    frame_active <= '0';
                end if;

                -- Stage 0 capture
                re_pipe(0)  <= in_real;
                im_pipe(0)  <= in_imag;
                v_pipe(0)   <= in_valid;
                soa_pipe(0) <= start_of_ascan and in_valid;
                eoa_pipe(0) <= end_of_ascan and in_valid;

                -- Shift through fixed dummy latency
                if DUMMY_LAT > 1 then
                    for i in 1 to DUMMY_LAT-1 loop
                        re_pipe(i)  <= re_pipe(i-1);
                        im_pipe(i)  <= im_pipe(i-1);
                        v_pipe(i)   <= v_pipe(i-1);
                        soa_pipe(i) <= soa_pipe(i-1);
                        eoa_pipe(i) <= eoa_pipe(i-1);
                    end loop;
                end if;

                -- Dummy passthrough output after fixed latency
                out_real           <= re_pipe(DUMMY_LAT-1);
                out_imag           <= im_pipe(DUMMY_LAT-1);
                out_valid          <= v_pipe(DUMMY_LAT-1);
                start_of_ascan_out <= soa_pipe(DUMMY_LAT-1);
            end if;
        end if;
    end process;

end architecture;

