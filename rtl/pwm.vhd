----------------------------------------------------------------------------------
-- pwm.vhdl
--
-- Description: basic pwm controller which allows specifying duty cycle.
-- It outputs a pwm output of frequency { clk_i freq / (100 * divider) }, what defines
-- the total PWM period. The resolution is 100 cycles per PWM period. For example, 
-- for clk_i @ 100 MHz and dividier=20, the PWM frequency is 50 KHz (20 us)
--
-- Inputs:
--   - clk_i: works at rising_edge. Tested for 100 MHz
--   - rst_i: synchronous high-level reset
--   - duty_cycle_i: duty cycle level (from 0 to 100).
--      - Maximum level (100%) if value is over 100. 
--      - Applied immediately
--
-- Outputs:
--   - pwm_o
--      - goes high during reset
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.utils_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity pwm is
    generic (
        divider : positive := 20
    );
    port (
        clk_i           : in  std_logic;
        rst_i           : in  std_logic;
        duty_cycle_in   : in  unsigned(6 downto 0);
        pwm_o           : out std_logic
    );
end pwm;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioral of pwm is

    signal count_in_freq : unsigned(log2_ceil(divider) downto 0);
    signal clk_pwm : std_logic;
    signal count_pwm_freq : unsigned(log2_ceil(100) downto 0);
    signal duty_cycle_reg : unsigned(6 downto 0);
    signal pwm_period_start : std_logic; -- For debug purpose

begin

    freq_divider_20_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if    (rst_i = '1')                 then count_in_freq <= (others => '0'); 
            elsif (count_in_freq < divider - 1) then count_in_freq <= count_in_freq + 1;
            else                                     count_in_freq <= (others => '0');
            end if;
        end if;
    end process;

    clk_pwm <= '1' when (count_in_freq < divider / 2) else '0';

    count_pwm_proc: process(clk_pwm, rst_i)
    begin
        if (rst_i = '1')             then count_pwm_freq <= (others => '0');
        elsif rising_edge(clk_pwm)   then         
            if (count_pwm_freq < 99) then count_pwm_freq <= count_pwm_freq + 1;
            else                          count_pwm_freq <= (others => '0');
            end if;
        end if;
    end process;

    duty_cycle_reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (rst_i = '1' or count_pwm_freq = 0) then duty_cycle_reg <= duty_cycle_in; end if;
        end if;
    end process;
    

    pwm_period_start <= '1' when (count_pwm_freq = 0) else '0';
    pwm_o <= '1' when (rst_i = '1' or count_pwm_freq < duty_cycle_reg) else '0';

end behavioral;
