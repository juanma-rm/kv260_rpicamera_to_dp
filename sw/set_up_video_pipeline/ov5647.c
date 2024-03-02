#include "sleep.h"
#include "platform.h"
#include "xgpiops.h"
#include "xiicps.h"
#include "ov5647.h"

static XGpioPs gpio;
static XIicPs iic;

int ov5647_init() {
	XGpioPs_Config *gpio_config;
	XIicPs_Config *iic_config;
	u8 bit_mask;
	u8 i2c_expander_slave_addr;
	u8 i2c_expander_control_bitmask;
	
	/*
	 * For KV260, OV5647 power supply is enabled by FPGA pin tied high,
	 * i2c expander reset_b is tied high on board
	 */

	if ( (iic_config = XIicPs_LookupConfig(XPAR_PSU_I2C_1_DEVICE_ID)) == NULL) {
		xil_printf("XIicPs_LookupConfig() failed\r\n");
		return XST_FAILURE;
	}
	if (XIicPs_CfgInitialize(&iic, iic_config, iic_config->BaseAddress) != XST_SUCCESS) {
		xil_printf("XIicPs_CfgInitialize() failed\r\n");
		return XST_FAILURE;
	}

	if (XIicPs_SelfTest(&iic) != XST_SUCCESS) {
		xil_printf("XIicPs_SelfTest() failed\r\n");
		return XST_FAILURE;
	}

	if (XIicPs_SetSClk(&iic, I2C_BUS_FREQ) != XST_SUCCESS) {
		xil_printf("XIicPs_SetSClk failed\r\n");
		return XST_FAILURE;
	}

    i2c_expander_slave_addr = KV260_I2C_EXPANDER_SLAVE_ADDR;
    i2c_expander_control_bitmask = KV260_I2C_EXPANDER_RPI_BIT_MASK;

	// Read i2c expander chip control reg
	if (XIicPs_MasterRecvPolled(&iic, &bit_mask, 1, i2c_expander_slave_addr) != XST_SUCCESS) {
		xil_printf("i2c expander receive failed\r\n");
		return XST_FAILURE;
	}
	usleep(1000); // chip needs some delay for some reason
	bit_mask |= i2c_expander_control_bitmask;
	if (XIicPs_MasterSendPolled(&iic, &bit_mask, 1, i2c_expander_slave_addr) != XST_SUCCESS) {
		xil_printf("i2c expander send failed\r\n");
		return XST_FAILURE;
	}

    ov5647_power_on();
    xil_printf("detecting\r\n");
    ov5647_detect();
    ov5647_config_1080p();
    // ov5647_autogain_on();
    ov5647_set_analogue_gain(MANUAL_GAIN);
    // ov5647_autoexposure_on();
    ov5647_set_exposure(MANUAL_EXPOSURE);

    xil_printf("Wrote initial configuration to OV5647 sensor\r\n");
	return XST_SUCCESS;
}

// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c
void ov5647_power_on(void) {

    ov5647_write(OV5647_REG_SW_RESET, 0x01);
    usleep(30000);
    ov5647_write(OV5647_REG_SW_RESET, 0x00);
    usleep(30000);

    ov5647_write(OV5647_REG_CMMN_PAD_OEN0, 0x0f);
    ov5647_write(OV5647_REG_CMMN_PAD_OEN1, 0xff);
    ov5647_write(OV5647_REG_CMMN_PAD_OEN2, 0xe4);
}

// Stream off to coax lanes into LP-11 state
// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c
void ov5647_stream_off(void) {
    ov5647_write(OV5647_REG_MIPI_CTRL00, MIPI_CTRL00_CLOCK_LANE_GATE | MIPI_CTRL00_BUS_IDLE | MIPI_CTRL00_CLOCK_LANE_DISABLE);
    ov5647_write(OV5647_REG_FRAME_OFF_NUMBER, 0x0f);
    ov5647_write(OV5640_REG_PAD_OUT, 0x01);
}

// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c
void ov5647_stream_on(void) {
	u8 val = MIPI_CTRL00_BUS_IDLE;
	val |= MIPI_CTRL00_CLOCK_LANE_GATE | MIPI_CTRL00_LINE_SYNC_ENABLE;
    ov5647_write(OV5647_REG_MIPI_CTRL00, val);
	ov5647_write(OV5647_REG_FRAME_OFF_NUMBER, 0x00);
	ov5647_write(OV5640_REG_PAD_OUT, 0x00);
}

// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c
void ov5647_detect(void) {

    ov5647_write(OV5647_REG_SW_RESET, 0x01);
    usleep(30000);

    u8 camera_model_id[2];
    ov5647_read(OV5647_REG_CHIPID_H, &camera_model_id[1]);
    ov5647_read(OV5647_REG_CHIPID_L, &camera_model_id[0]);
    if (camera_model_id[1] != OV5647_ID_H || camera_model_id[0] != OV5647_ID_L) {
		xil_printf("could not read camera id\r\n");
        xil_printf("camera_model_id[1] = 0x%02X\n\r", camera_model_id[1]);
        xil_printf("camera_model_id[0] = 0x%02X\n\r", camera_model_id[0]);
	} else {
        xil_printf("I2C communication established with OV5647\r\n");
    }

    ov5647_write(OV5647_REG_SW_RESET, 0x00);

}

// set up to 1920x1080P48
// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c
void ov5647_config_1080p(void) {
	size_t num_cmds = sizeof(ov5647_1080p30_10bpp) / sizeof(ov5647_1080p30_10bpp[0]);
    for (int command_pos=0; command_pos<num_cmds; command_pos++) {
        ov5647_write(ov5647_1080p30_10bpp[command_pos][0], ov5647_1080p30_10bpp[command_pos][1]);
    }
}

// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c
// Autogain (Non-zero turns on AGC by clearing bit 1)
void ov5647_autogain_on(void) {
	u8 reg;
	ov5647_read(OV5647_REG_AEC_AGC, &reg);
	ov5647_write(OV5647_REG_AEC_AGC, reg | BIT(1));
}

// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c
void ov5647_set_analogue_gain(u32 val)
{
	/* 10 bits of gain, 2 in the high register. */
	ov5647_write(OV5647_REG_GAIN_HI, (val >> 8) & 3);
    ov5647_write(OV5647_REG_GAIN_LO, val & 0xff);
}

// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c
// Autoexpoure (Everything except V4L2_EXPOSURE_MANUAL turns on AEC by clearing bit 0)
void ov5647_autoexposure_on(void) {
    u8 reg;
    ov5647_read(OV5647_REG_AEC_AGC, &reg);
	ov5647_write(OV5647_REG_AEC_AGC, reg & ~BIT(0));
}

// https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5647.c
void ov5647_set_exposure(u32 val)
{
	/*
	 * Sensor has 20 bits, but the bottom 4 bits are fractions of a line
	 * which we leave as zero (and don't receive in "val").
	 */
	ov5647_write(OV5647_REG_EXP_HI, (val >> 12) & 0xf);
	ov5647_write(OV5647_REG_EXP_MID, (val >> 4) & 0xff);
}

int ov5647_write(u16 addr, u8 data) {
	u8 buf[3];

	buf[0] = addr >> 8;
	buf[1] = addr & 0xff;
	buf[2] = data;

	while (TransmitFifoFill(&iic) || XIicPs_BusIsBusy(&iic)) { //while (XIicPs_BusIsBusy(&iic)) {
		usleep(1);
		xil_printf("waiting for transmit...\r\n");
	}

	if (XIicPs_MasterSendPolled(&iic, buf, 3, OV5647_I2C_SLAVE_ADDR_W) != XST_SUCCESS) {
		xil_printf("ov5647 write failed, addr: %x\r\n", addr);
		return XST_FAILURE;
	}
	usleep(1000);

	return XST_SUCCESS;
}

int ov5647_read(u16 addr, u8 *data) {
	u8 buf[2];

	buf[0] = addr >> 8;
	buf[1] = addr & 0xff;

	if (XIicPs_MasterSendPolled(&iic, buf, 2, OV5647_I2C_SLAVE_ADDR_W) != XST_SUCCESS) {
		xil_printf("ov5647 write failed\r\n");
		return XST_FAILURE;
	}
	if (XIicPs_MasterRecvPolled(&iic, data, 1, OV5647_I2C_SLAVE_ADDR_W) != XST_SUCCESS) {
		xil_printf("ov5647 receive failed\r\n");
		return XST_FAILURE;
	}
	return XST_SUCCESS;
}