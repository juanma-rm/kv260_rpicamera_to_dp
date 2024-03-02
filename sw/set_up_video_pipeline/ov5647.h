#ifndef SRC_OV5647_H_
#define SRC_OV5647_H_

#define I2C_BUS_FREQ 400000 // in Hz

#define OV5647_ENABLE_GPIO_PIN 37
#define OV5647_I2C_SLAVE_ADDR_W  0x36
#define OV5647_I2C_SLAVE_ADDR_R  0x37

#define KV260_I2C_EXPANDER_SLAVE_ADDR	0x74
#define KV260_I2C_EXPANDER_RPI_BIT_MASK	0b00000100

#define BIT(n) (1 << (n))
#define MIPI_CTRL00_CLOCK_LANE_GATE		BIT(5)
#define MIPI_CTRL00_LINE_SYNC_ENABLE	BIT(4)
#define MIPI_CTRL00_BUS_IDLE			BIT(2)
#define MIPI_CTRL00_CLOCK_LANE_DISABLE	BIT(0)

/* OV5647 registers */
#define OV5647_REG_SW_STANDBY		            0x0100 // Software sleep via SCCB (sleep when 0)
#define OV5647_REG_SW_RESET			            0x0103 // Reset via SCCB (reset when 1)
#define OV5647_REG_CMMN_PAD_OEN0                0x3000
#define OV5647_REG_CMMN_PAD_OEN1                0x3001
#define OV5647_REG_CMMN_PAD_OEN2                0x3002
#define OV5647_REG_CMMN_MIPI_PHY_1              0x3016
#define OV5647_REG_CMMN_MIPI_PHY_2              0x3017
#define OV5647_REG_CMMN_MIPI_SC_CTRL            0x3018
#define OV5647_REG_SC_CMMN_PLL_CTRL0            0x3034
#define OV5647_REG_CHIPID_H		                0x300a // Default: 0x56
#define OV5647_REG_CHIPID_L		                0x300b // Default: 0x47
#define OV5640_REG_PAD_OUT		                0x300d
#define OV5647_REG_0x301C                       0x301c
#define OV5647_REG_0x301D                       0x301d
#define OV5647_REG_CMMN_PLL_CTRL1               0x3035
#define OV5647_REG_CMMN_PLL_MULT                0x3036
#define OV5647_REG_CMMN_PLLS_CTRL2              0x303c
#define OV5647_REG_SRB_CTRL                     0x3106
#define OV5647_REG_EXP_HI		                0x3500 // Exposure[19:16]
#define OV5647_REG_EXP_MID		                0x3501 // Exposure[15:08]
#define OV5647_REG_EXP_LO		                0x3502 // Exposure[07:00]
#define OV5647_REG_AEC_AGC		                0x3503 // Manual control. [5:4]: gain latch timing delay, [2]: VTS manual, [1]: AGC manual, [0]: AEC manual
#define OV5647_REG_GAIN_HI		                0x350a // Gain [9:8]
#define OV5647_REG_GAIN_LO		                0x350b // Gain [7:0]
#define OV5647_REG_0x3600                       0x3600
#define OV5647_REG_0x3612                       0x3612
#define OV5647_REG_0x3618                       0x3618
#define OV5647_REG_0x3620                       0x3620
#define OV5647_REG_0x3621                       0x3621
#define OV5647_REG_0x3630                       0x3630
#define OV5647_REG_0x3632                       0x3632
#define OV5647_REG_0x3633                       0x3633
#define OV5647_REG_0x3634                       0x3634
#define OV5647_REG_0x3636                       0x3636
#define OV5647_REG_0x3704                       0x3704
#define OV5647_REG_0x3703                       0x3703
#define OV5647_REG_0x3715                       0x3715
#define OV5647_REG_0x3717                       0x3717
#define OV5647_REG_0x3731                       0x3731
#define OV5647_REG_0x370B                       0x370b
#define OV5647_REG_0x3705                       0x3705
#define OV5647_REG_0x3708                       0x3708
#define OV5647_REG_0x3709                       0x3709
#define OV5647_REG_0x370C                       0x370c
#define OV5647_REG_TIMING_X_ADDR_START_H        0x3800
#define OV5647_REG_TIMING_X_ADDR_START_L        0x3801
#define OV5647_REG_TIMING_Y_ADDR_START_H        0x3802
#define OV5647_REG_TIMING_Y_ADDR_START_L        0x3803
#define OV5647_REG_TIMING_X_ADDR_END_H          0x3804
#define OV5647_REG_TIMING_X_ADDR_END_L          0x3805
#define OV5647_REG_TIMING_Y_ADDR_END_H          0x3806
#define OV5647_REG_TIMING_Y_ADDR_END_L          0x3807
#define OV5647_REG_TIMING_X_OUTPUT_SIZE_H       0x3808
#define OV5647_REG_TIMING_X_OUTPUT_SIZE_L       0x3809
#define OV5647_REG_TIMING_Y_OUTPUT_SIZE_H       0x380a
#define OV5647_REG_TIMING_Y_OUTPUT_SIZE_L       0x380b
#define OV5647_REG_TIMING_HTS_H                 0x380c
#define OV5647_REG_TIMING_HTS_L                 0x380d
#define OV5647_REG_TIMING_ISP_X_WIN             0x3811
#define OV5647_REG_TIMING_ISP_Y_WIN             0x3813
#define OV5647_REG_TIMING_X_INC                 0x3814
#define OV5647_REG_TIMING_Y_INC                 0x3815
#define OV5647_REG_TIMING_TC_REG20              0x3820 // vertical binning
#define OV5647_REG_TIMING_TC_REG21              0x3821 // horizontal binning
#define OV5647_REG_DEBUG_MODE_27                0x3827
#define OV5647_REG_VTS_HI		                0x380e // Total vertical size [9:8]
#define OV5647_REG_VTS_LO		                0x380f // Total vertical size [7:0]
#define OV5647_REG_B50_SETP_H                   0x3a08
#define OV5647_REG_B50_STEP_L                   0x3a09
#define OV5647_REG_B60_STEP_H                   0x3a0a
#define OV5647_REG_B60_STEP_L                   0x3a0b
#define OV5647_REG_B60_MAX                      0x3a0d
#define OV5647_REG_B50_MAX                      0x3a0e
#define OV5647_REG_WPT                          0x3a0f
#define OV5647_REG_BPT                          0x3a10
#define OV5647_REG_HIGH_VPT                     0x3a11
#define OV5647_REG_AEC_GAIN_CEILING_H           0x3a18
#define OV5647_REG_AEC_GAIN_CEILING_L           0x3a19
#define OV5647_REG_WPT2                         0x3a1b
#define OV5647_REG_BPT2                         0x3a1e
#define OV5647_REG_LOW_VPT                      0x3a1f
#define OV5647_REG_STROBE_FREX_MODE_SEL         0x3b07
#define OV5647_REG_50_60_HZ_DETECTION_CTRL01    0x3c01
#define OV5647_REG_0x3F01                       0x3f01
#define OV5647_REG_0x3F05                       0x3f05
#define OV5647_REG_0x3F06                       0x3f06
#define OV5647_REG_BLC_CTRL00                   0x4000
#define OV5647_REG_BLC_CTRL01                   0x4001
#define OV5647_REG_BLC_CTRL04                   0x4004
#define OV5647_REG_FRAME_OFF_NUMBER	            0x4202 // Frame control 2 (frame number)
#define OV5647_REG_MIPI_CTRL00		            0x4800
#define OV5647_REG_MIPI_CTRL14		            0x4814 
#define OV5647_REG_PCLK_PERIOD                  0x4837
#define OV5647_REG_ISP_CTRL00                   0x5000 // lenc_en
#define OV5647_REG_ISP_CTRL02                   0x5002 // win_en, opt_en, awb_gain_en
#define OV5647_REG_AWB			                0x5001 // awb_en
#define OV5647_REG_ISP_CTRL03                   0x5003 // buf_en, bin_man_set, bin_auto_en
#define OV5647_REG_ISPCTRL3D		            0x503d // test pattern, rolling_bar, bar_style
#define OV5647_REG_DIGC_CTRL0                   0x5a00

/* OV5647 native and active pixel array size */
#define OV5647_NATIVE_WIDTH		    2624U
#define OV5647_NATIVE_HEIGHT		1956U

#define OV5647_PIXEL_ARRAY_LEFT		16U
#define OV5647_PIXEL_ARRAY_TOP		16U
#define OV5647_PIXEL_ARRAY_WIDTH	2592U
#define OV5647_PIXEL_ARRAY_HEIGHT	1944U

#define OV5647_VBLANK_MIN		    4
#define OV5647_VTS_MAX			    32767

#define OV5647_EXPOSURE_MIN		    4
#define OV5647_EXPOSURE_STEP		1
#define OV5647_EXPOSURE_DEFAULT		1000
#define OV5647_EXPOSURE_MAX		    65535

#define OV5647_ID_H                 0x56
#define OV5647_ID_L                 0x47

#define MANUAL_GAIN                 50 // Value that worked for me
#define MANUAL_EXPOSURE             2500 // Value that worked for me

static u32 sensor_oe_disable_regs[][2] = {
	{OV5647_REG_CMMN_PAD_OEN0, 0x00},
	{OV5647_REG_CMMN_PAD_OEN1, 0x00},
	{OV5647_REG_CMMN_PAD_OEN2, 0x00},
};

static u32 sensor_oe_enable_regs[][2] = {
	{OV5647_REG_CMMN_PAD_OEN0, 0x0f},
	{OV5647_REG_CMMN_PAD_OEN1, 0xff},
	{OV5647_REG_CMMN_PAD_OEN2, 0xe4},
};

static u32 ov5647_1080p30_10bpp[][2] = {
    {OV5647_REG_SW_STANDBY                  , 0x00},
    {OV5647_REG_SW_RESET                    , 0x01},
    {OV5647_REG_SC_CMMN_PLL_CTRL0           , 0x1a},
    {OV5647_REG_CMMN_PLL_CTRL1              , 0x21},
    {OV5647_REG_CMMN_PLL_MULT               , 0x62},
    {OV5647_REG_CMMN_PLLS_CTRL2             , 0x11},
    {OV5647_REG_SRB_CTRL                    , 0xf5},
    {OV5647_REG_TIMING_TC_REG21             , 0x06},
    {OV5647_REG_TIMING_TC_REG20             , 0x00},
    {OV5647_REG_DEBUG_MODE_27               , 0xec},
    {OV5647_REG_0x370C                      , 0x03},
    {OV5647_REG_0x3612                      , 0x5b},
    {OV5647_REG_0x3618                      , 0x04},
    {OV5647_REG_ISP_CTRL00                  , 0x06},
    {OV5647_REG_ISP_CTRL02                  , 0x41},
    {OV5647_REG_ISP_CTRL03                  , 0x08},
    {OV5647_REG_DIGC_CTRL0			        , 0x08},
    {OV5647_REG_CMMN_PAD_OEN0               , 0x00},
    {OV5647_REG_CMMN_PAD_OEN1               , 0x00},
    {OV5647_REG_CMMN_PAD_OEN2               , 0x00},
    {OV5647_REG_CMMN_MIPI_PHY_1             , 0x08},
    {OV5647_REG_CMMN_MIPI_PHY_2             , 0xe0},
    {OV5647_REG_CMMN_MIPI_SC_CTRL           , 0x44},
    {OV5647_REG_0x301C                      , 0xf8},
    {OV5647_REG_0x301D                      , 0xf0},
    {OV5647_REG_AEC_GAIN_CEILING_H          , 0x00},
    {OV5647_REG_AEC_GAIN_CEILING_L          , 0xf8},
    {OV5647_REG_50_60_HZ_DETECTION_CTRL01   , 0x80},
    {OV5647_REG_STROBE_FREX_MODE_SEL        , 0x0c},
    {OV5647_REG_TIMING_HTS_H                , 0x09},
    {OV5647_REG_TIMING_HTS_L                , 0x70},
    {OV5647_REG_TIMING_X_INC                , 0x11},
    {OV5647_REG_TIMING_Y_INC                , 0x11},
    {OV5647_REG_0x3708                      , 0x64},
    {OV5647_REG_0x3709                      , 0x12},
    {OV5647_REG_TIMING_X_OUTPUT_SIZE_H      , 0x07},
    {OV5647_REG_TIMING_X_OUTPUT_SIZE_L      , 0x80},
    {OV5647_REG_TIMING_Y_OUTPUT_SIZE_H      , 0x04},
    {OV5647_REG_TIMING_Y_OUTPUT_SIZE_L      , 0x38},
    {OV5647_REG_TIMING_X_ADDR_START_H       , 0x01},
    {OV5647_REG_TIMING_X_ADDR_START_L       , 0x5c},
    {OV5647_REG_TIMING_Y_ADDR_START_H       , 0x01},
    {OV5647_REG_TIMING_Y_ADDR_START_L       , 0xb2},
    {OV5647_REG_TIMING_X_ADDR_END_H         , 0x08},
    {OV5647_REG_TIMING_X_ADDR_END_L         , 0xe3},
    {OV5647_REG_TIMING_Y_ADDR_END_H         , 0x05},
    {OV5647_REG_TIMING_Y_ADDR_END_L         , 0xf1},
    {OV5647_REG_TIMING_ISP_X_WIN            , 0x04},
    {OV5647_REG_TIMING_ISP_Y_WIN            , 0x02},
    {OV5647_REG_0x3630                      , 0x2e},
    {OV5647_REG_0x3632                      , 0xe2},
    {OV5647_REG_0x3633                      , 0x23},
    {OV5647_REG_0x3634                      , 0x44},
    {OV5647_REG_0x3636                      , 0x06},
    {OV5647_REG_0x3620                      , 0x64},
    {OV5647_REG_0x3621                      , 0xe0},
    {OV5647_REG_0x3600                      , 0x37},
    {OV5647_REG_0x3704                      , 0xa0},
    {OV5647_REG_0x3703                      , 0x5a},
    {OV5647_REG_0x3715                      , 0x78},
    {OV5647_REG_0x3717                      , 0x01},
    {OV5647_REG_0x3731                      , 0x02},
    {OV5647_REG_0x370B                      , 0x60},
    {OV5647_REG_0x3705                      , 0x1a},
    {OV5647_REG_0x3F05                      , 0x02},
    {OV5647_REG_0x3F06                      , 0x10},
    {OV5647_REG_0x3F01                      , 0x0a},
    {OV5647_REG_B50_SETP_H                  , 0x01},
    {OV5647_REG_B50_STEP_L                  , 0x4b},
    {OV5647_REG_B60_STEP_H                  , 0x01},
    {OV5647_REG_B60_STEP_L                  , 0x13},
    {OV5647_REG_B60_MAX                     , 0x04},
    {OV5647_REG_B50_MAX                     , 0x03},
    {OV5647_REG_WPT                         , 0x58},
    {OV5647_REG_BPT                         , 0x50},
    {OV5647_REG_WPT2                        , 0x58},
    {OV5647_REG_BPT2                        , 0x50},
    {OV5647_REG_HIGH_VPT                    , 0x60},
    {OV5647_REG_LOW_VPT                     , 0x28},
    {OV5647_REG_BLC_CTRL01                  , 0x02},
    {OV5647_REG_BLC_CTRL04                  , 0x04},
    {OV5647_REG_BLC_CTRL00                  , 0x09},
	{OV5647_REG_PCLK_PERIOD                 , 0x19},
    {OV5647_REG_MIPI_CTRL00		            , 0x34},
    {OV5647_REG_AEC_AGC		                , 0x03},
    {OV5647_REG_SW_STANDBY                  , 0x01},
};

static u32 ov5647_640x480_10bpp[][2] = {
    {OV5647_REG_SW_STANDBY                  , 0x00},
	{OV5647_REG_SW_RESET                    , 0x01},
	{OV5647_REG_CMMN_PLL_CTRL1              , 0x11},
	{OV5647_REG_CMMN_PLL_MULT               , 0x46},
	{OV5647_REG_CMMN_PLLS_CTRL2             , 0x11},
	{OV5647_REG_TIMING_TC_REG21             , 0x07},
	{OV5647_REG_TIMING_TC_REG20             , 0x41},
	{OV5647_REG_0x370C                      , 0x03},
	{OV5647_REG_0x3612                      , 0x59},
	{OV5647_REG_0x3618                      , 0x00},
	{OV5647_REG_ISP_CTRL00                  , 0x06},
	{OV5647_REG_ISP_CTRL03                  , 0x08},
	{OV5647_REG_DIGC_CTRL0                  , 0x08},
	{OV5647_REG_TIMING_X_ADDR_START_H       , 0xff},
	{OV5647_REG_TIMING_X_ADDR_START_L       , 0xff},
	{OV5647_REG_TIMING_Y_ADDR_START_H       , 0xff},
	{OV5647_REG_TIMING_Y_ADDR_START_L       , 0xf0},
	{OV5647_REG_AEC_GAIN_CEILING_H          , 0x00},
	{OV5647_REG_AEC_GAIN_CEILING_L          , 0xf8},
	{OV5647_REG_50_60_HZ_DETECTION_CTRL01   , 0x80},
	{OV5647_REG_STROBE_FREX_MODE_SEL        , 0x0c},
	{OV5647_REG_TIMING_HTS_H                , 0x07},
	{OV5647_REG_TIMING_HTS_L                , 0x3c},
	{OV5647_REG_TIMING_HTS_L                , 0x35},
	{OV5647_REG_TIMING_Y_INC                , 0x35},
	{OV5647_REG_0x3708                      , 0x64},
	{OV5647_REG_0x3709                      , 0x52},
	{OV5647_REG_TIMING_X_OUTPUT_SIZE_H      , 0x02},
	{OV5647_REG_TIMING_X_OUTPUT_SIZE_L      , 0x80},
	{OV5647_REG_TIMING_Y_OUTPUT_SIZE_H      , 0x01},
	{OV5647_REG_TIMING_Y_OUTPUT_SIZE_L      , 0xe0},
	{OV5647_REG_TIMING_X_ADDR_END_H         , 0x00},
	{OV5647_REG_TIMING_X_ADDR_END_L         , 0x10},
	{OV5647_REG_TIMING_Y_ADDR_END_H         , 0x00},
	{OV5647_REG_TIMING_Y_ADDR_END_L         , 0x00},
	{OV5647_REG_TIMING_HTS_H                , 0x0a},
	{OV5647_REG_TIMING_HTS_L                , 0x2f},
	{OV5647_REG_TIMING_ISP_X_WIN            , 0x07},
	{OV5647_REG_TIMING_ISP_Y_WIN            , 0x9f},
	{OV5647_REG_0x3630                      , 0x2e},
	{OV5647_REG_0x3632                      , 0xe2},
	{OV5647_REG_0x3633                      , 0x23},
	{OV5647_REG_0x3634                      , 0x44},
	{OV5647_REG_0x3620                      , 0x64},
	{OV5647_REG_0x3621                      , 0xe0},
	{OV5647_REG_0x3600                      , 0x37},
	{OV5647_REG_0x3704                      , 0xa0},
	{OV5647_REG_0x3703                      , 0x5a},
	{OV5647_REG_0x3715                      , 0x78},
	{OV5647_REG_0x3717                      , 0x01},
	{OV5647_REG_0x3731                      , 0x02},
	{OV5647_REG_0x370B                      , 0x60},
	{OV5647_REG_0x3705                      , 0x1a},
	{OV5647_REG_0x3F05                      , 0x02},
	{OV5647_REG_0x3F06                      , 0x10},
	{OV5647_REG_0x3F01                      , 0x0a},
	{OV5647_REG_B50_SETP_H                  , 0x01},
	{OV5647_REG_B50_STEP_L                  , 0x2e},
	{OV5647_REG_B60_STEP_H                  , 0x00},
	{OV5647_REG_B60_STEP_L                  , 0xfb},
	{OV5647_REG_B60_MAX                     , 0x02},
	{OV5647_REG_B50_MAX                     , 0x01},
    {OV5647_REG_WPT                         , 0x58},
    {OV5647_REG_BPT                         , 0x50},
    {OV5647_REG_WPT2                        , 0x58},
    {OV5647_REG_BPT2                        , 0x50},
	{OV5647_REG_HIGH_VPT                    , 0x60},
	{OV5647_REG_LOW_VPT                     , 0x28},
	{OV5647_REG_BLC_CTRL01                  , 0x02},
	{OV5647_REG_BLC_CTRL04                  , 0x02},
	{OV5647_REG_BLC_CTRL00                  , 0x09},
	{OV5647_REG_CMMN_PAD_OEN0               , 0x00},
	{OV5647_REG_CMMN_PAD_OEN1               , 0x00},
	{OV5647_REG_CMMN_PAD_OEN2               , 0x00},
	{OV5647_REG_CMMN_MIPI_PHY_2             , 0xe0},
	{OV5647_REG_0x301C                      , 0xfc},
	{OV5647_REG_0x3636                      , 0x06},
	{OV5647_REG_CMMN_MIPI_PHY_1             , 0x08},
	{OV5647_REG_DEBUG_MODE_27               , 0xec},
	{OV5647_REG_CMMN_MIPI_SC_CTRL           , 0x44},
	{OV5647_REG_CMMN_PLL_CTRL1              , 0x21},
	{OV5647_REG_SRB_CTRL                    , 0xf5},
	{OV5647_REG_SC_CMMN_PLL_CTRL0           , 0x1a},
	{OV5647_REG_0x301C                      , 0xf8},
	{OV5647_REG_MIPI_CTRL00                 , 0x34},
	{OV5647_REG_AEC_AGC                     , 0x03},
	{OV5647_REG_SW_STANDBY                  , 0x01},
};


int ov5647_init();
int ov5647_write(u16 addr, u8 data);
int ov5647_read(u16 addr, u8 *data);

#endif /* SRC_OV5647_H_ */
