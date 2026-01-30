----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/30/2026 01:38:32 PM
-- Design Name: 
-- Module Name: fft_split - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fft_split is
    Port ( clk : in STD_LOGIC;
           str_in : in STD_LOGIC_VECTOR (31 downto 0);
           bus1 : out STD_LOGIC_VECTOR (31 downto 0);
           bus2 : out STD_LOGIC_VECTOR (31 downto 0);
           bus3 : out STD_LOGIC_VECTOR (31 downto 0));
end fft_split;

architecture Behavioral of fft_split is

begin


end Behavioral;
