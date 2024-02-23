----------------------------------------------------------------------------------
-- axis_video_pattern_generator_wrapper.vhdl
--
-- Description: wraps axis_video_pattern_generator (VHDL 2008) to form a VHDL 93 file 
-- to be included from Vivado IP integrator
--
-- Inputs:
--   - clk_i: works at rising_edge
--   - rst_i: synchronous high-level reset
--
-- Outputs:
--   - m_axis_video (tready, tvalid, tdata 24b, tlast, tuser 1b): carries pixel data
--   in an AXI stream interface
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity axis_video_pattern_generator_wrapper is
    generic (
        NUM_COLS                : positive := 1920;
        NUM_ROWS                : positive := 1080;
        NUM_COMPS_PER_PIXEL     : positive := 3;
        AXIS_DATA_WIDTH         : positive := 24
    );
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;

        m_axis_video_tready : in  std_logic;
        m_axis_video_tvalid : out std_logic;
        m_axis_video_tdata  : out std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        m_axis_video_tlast  : out std_logic;
        m_axis_video_tuser  : out std_logic
    );
end axis_video_pattern_generator_wrapper;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioral of axis_video_pattern_generator_wrapper is


begin

    axis_video_pattern_generator_inst : entity work.axis_video_pattern_generator
    generic map (
        NUM_COLS            => NUM_COLS,
        NUM_ROWS            => NUM_ROWS,
        NUM_COMPS_PER_PIXEL => NUM_COMPS_PER_PIXEL,
        AXIS_DATA_WIDTH     => AXIS_DATA_WIDTH
    )
    port map (
        clk_i               => clk_i,
        rst_i               => rst_i,
        m_axis_video_tready => m_axis_video_tready,
        m_axis_video_tvalid => m_axis_video_tvalid,
        m_axis_video_tdata  => m_axis_video_tdata,
        m_axis_video_tlast  => m_axis_video_tlast,
        m_axis_video_tuser  => m_axis_video_tuser
    );
  
end behavioral;
