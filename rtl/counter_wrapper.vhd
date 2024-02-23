----------------------------------------------------------------------------------
-- counter_wrapper.vhdl
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

entity counter_wrapper is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;
        pmod_o  : out std_logic_vector(7 downto 0)
    );
end counter_wrapper;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioral of counter_wrapper is

    component counter
        port (
          clk_i   : in  std_logic;
          rst_i   : in  std_logic;
          count_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    signal count : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    counter_inst : counter
        port map (
            clk_i   => clk_i,
            rst_i   => rst_i,
            count_o => count
        );
    
    pmod_o <= count(31 downto 24);

end behavioral;
