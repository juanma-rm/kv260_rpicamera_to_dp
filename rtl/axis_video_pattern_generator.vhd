----------------------------------------------------------------------------------
-- axis_video_pattern_generator.vhdl
--
-- Description: generates a video pattern consisting in three horizontal bars (red, green, blue)
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

use work.utils_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity axis_video_pattern_generator is
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
end axis_video_pattern_generator;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioral of axis_video_pattern_generator is

    signal m_axis_consumed : std_logic;
    signal count_col_reg   : unsigned(log2_ceil(NUM_COLS)-1 downto 0);
    signal count_row_reg   : unsigned(log2_ceil(NUM_ROWS)-1 downto 0);
    constant COUNT_FRAME_MAX : positive := 64*1024;
    signal count_frame_reg : unsigned(log2_ceil(COUNT_FRAME_MAX)-1 downto 0);
    signal eol : std_logic;
    signal eof : std_logic;

    constant COLOUR_BLUE  : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0) := x"FF" & x"00" & x"00";
    constant COLOUR_RED   : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0) := x"00" & x"FF" & x"00";
    constant COLOUR_GREEN : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0) := x"00" & x"00" & x"FF";
    constant COLOUR_BLACK : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0) := x"00" & x"00" & x"00";
    constant COLOUR_WHITE : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0) := x"FF" & x"FF" & x"FF";
    signal pixel_current : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);

    signal vertical_bar_posX : unsigned(log2_ceil(NUM_COLS)-1 downto 0);
    constant VERTICAL_BAR_WIDTH : positive := 5;

begin

    -- Count columns and EOL
    eol <= '1' when (count_col_reg = NUM_COLS-1) else '0';
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                count_col_reg <= (others => '0');  -- Reset the counter to 0 at reset
            elsif (m_axis_consumed = '1' and eol = '1') then
                count_col_reg <= (others => '0');  -- Reset the counter to 0 at EOL
            elsif (m_axis_consumed = '1') then
                count_col_reg <= count_col_reg + 1;  -- Increment the counter after consuming current pixel
            end if;
        end if;
    end process;

    -- Count rows and EOF
    eof <= '1' when (eol = '1' and count_row_reg = NUM_ROWS-1) else '0';
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                count_row_reg <= (others => '0');  -- Reset the counter to 0 at reset
            elsif (m_axis_consumed = '1' and eof = '1') then
                count_row_reg <= (others => '0');  -- Reset the counter to 0 at EOF
            elsif (m_axis_consumed = '1' and m_axis_video_tlast = '1') then
                count_row_reg <= count_row_reg + 1;  -- Increment the counter after consuming current line
            end if;
        end if;
    end process;

    -- Count frames
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                count_frame_reg <= (others => '0');  -- Reset the counter to 0 at reset
            elsif (m_axis_consumed = '1' and eof = '1') then
                count_frame_reg <= count_frame_reg + 1;  -- Increment the counter after current frame
            end if;
        end if;
    end process; 

    -- Handle vertical bar position
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                vertical_bar_posX <= (others => '0');  -- Reset the counter to 0 at reset
            elsif (m_axis_consumed = '1' and eof = '1') then
                vertical_bar_posX <= vertical_bar_posX + 1;  -- Increment by one column after each frame
            end if;
        end if;
    end process; 

    -- Control pixel value
    process(all)
    begin
        if (count_col_reg >= vertical_bar_posX and count_col_reg < vertical_bar_posX + VERTICAL_BAR_WIDTH) then
            pixel_current <= COLOUR_BLACK;
        elsif count_row_reg < to_unsigned(NUM_ROWS*1/3, count_row_reg'length) then
            pixel_current <= COLOUR_RED;
        elsif count_row_reg < to_unsigned(NUM_ROWS*2/3, count_row_reg'length) then
            pixel_current <= COLOUR_GREEN;
        elsif count_row_reg < to_unsigned(NUM_ROWS*3/3, count_row_reg'length) then
            pixel_current <= COLOUR_BLUE;
        else
            pixel_current <= COLOUR_WHITE;
        end if;
    end process;

    -- Handle m_axis interface signals
    m_axis_consumed     <= m_axis_video_tready and m_axis_video_tvalid;
    m_axis_video_tdata  <= pixel_current;
    m_axis_video_tvalid <= '1';
    m_axis_video_tlast  <= '1' when (m_axis_consumed = '1' and eol = '1') else '0';
    m_axis_video_tuser  <= '1' when (m_axis_consumed = '1' and count_col_reg = 0 and count_row_reg = 0) else '0';

end behavioral;
