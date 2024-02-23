/*********************************************************************************
* utils.v
* 
* Description: defines some common macros and functions
*********************************************************************************/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

`ifndef UTILS_GUARD
`define UTILS_GUARD

/*********************************************************************************
 * Constants
*********************************************************************************/



/*********************************************************************************
 * Function definitions
*********************************************************************************/

// log2 (floor rounding; returns 0 for {0,1}, 1 for {2,3}, 2 for {4,5,6,7}, etc.)
function integer log2 (input integer num);
begin
    log2 = 0;
    while (num > 1) begin
        num = num / 2;
        log2 = log2 + 1;
    end
end
endfunction

`endif // UTILS_GUARD