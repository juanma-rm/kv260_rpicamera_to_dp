----------------------------------------------------------------------------------
-- counter.vhdl
--
-- Description: simple up-counter
--
-- Inputs:
--   - clk_i: works at rising_edge
--   - rst_i: synchronous high-level reset
--
-- Outputs:
--   - count_o(31 downto 0)
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity counter is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;
        count_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end counter;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioral of counter is

    signal count_reg : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                count_reg <= (others => '0');  -- Reset the counter to 0
            else
                count_reg <= count_reg + 1;  -- Increment the counter on each clock edge
            end if;
        end if;
    end process;

    count_o <= std_logic_vector(count_reg);

end behavioral;
