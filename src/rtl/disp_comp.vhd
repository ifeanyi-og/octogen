----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/30/2026 01:38:32 PM
-- Design Name: 
-- Module Name: disp_comp - Behavioral
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

entity disp_comp is
    Port ( clk : in STD_LOGIC;
           str_in : in STD_LOGIC_VECTOR (31 downto 0);
           str_out : out STD_LOGIC_VECTOR (31 downto 0));
end disp_comp;

architecture Behavioral of disp_comp is

begin


end Behavioral;
