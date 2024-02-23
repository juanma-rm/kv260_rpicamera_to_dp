----------------------------------------------------------------------------------
-- utils_pkg.vhdl
--
-- Description: defines some common macros and functions
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

----------------------------------------------------------------------------------
-- Package header
----------------------------------------------------------------------------------

package utils_pkg is

    pure function log2_ceil(i : positive) return natural; 
    pure function max(a : positive; b : positive) return positive;

end package utils_pkg;

----------------------------------------------------------------------------------
-- Package body
----------------------------------------------------------------------------------

package body utils_pkg is

    pure function log2_ceil(i : positive) return natural is
        variable ret_val : integer;
	begin
        ret_val := integer(ceil(ieee.math_real.log2(real(i))));
		return ret_val;
	end function;

    pure function max(a : positive; b : positive) return positive is
    begin
		if (a > b) then return a;
		else            return b;
        end if;
    end function;    

end utils_pkg;