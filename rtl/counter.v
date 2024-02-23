/*********************************************************************************
* counter.v
* 
* Description: simple up-counter
* 
* Inputs:
*   - clk_i: works at rising_edge
*   - rst_i: synchronous high-level reset
*
* Outputs:
*   - count_o[31:0]
*********************************************************************************/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/**********************************************************************************
 * Includes
**********************************************************************************/

`include "utils.v"

/**********************************************************************************
 * Module declaration
**********************************************************************************/

module counter #( 
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk_i  ,
    input  wire                   rst_i  ,
    output reg [DATA_WIDTH-1:0]   count_o
);

/**********************************************************************************
 * Module implementation
**********************************************************************************/

always @(posedge clk_i) begin
    if (rst_i) begin
        count_o <= 0;  // Reset the counter to 0
    end else begin
        count_o <= count_o + 1;  // Increment the counter on each clock edge
    end
end

endmodule
