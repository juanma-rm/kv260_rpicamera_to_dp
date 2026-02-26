#!/bin/bash

# =============================================================================
# KV260 OV5647 Camera + VCU Encoder UDP Streaming Setup Script
# =============================================================================
# 
# This script configures the camera pipeline for hardware VCU encoding
# and UDP streaming. It uses the VCU hardware encoder to compress video
# to H.264/H.265 and streams it over UDP/IP.
#
# sudo apt install gstreamer-xilinx1.0-omx-zynqmp
#
# =============================================================================

# Device Constants
readonly SENSOR_ENTITY="ov5647 6-0036"
readonly MIPI_CSI_ENTITY="a0000000.mipi_csi2_rx_subsystem"
readonly DEMOSAIC_ENTITY="a0010000.v_demosaic"
readonly GAMMA_ENTITY="a0020000.v_gamma_lut"
readonly CSC_ENTITY="a0030000.v_proc_ss"
readonly SCALER_ENTITY="a0080000.v_proc_ss"
readonly VIDEO_DEVICE="/dev/video0"

# Format Constants
readonly SENSOR_FORMAT="SBGGR10_1X10"
readonly RGB_FORMAT="RBG888_1X24"
readonly STREAM_YUV_FORMAT="VYYUYY8_1X24"
readonly RESOLUTION_SENSOR="1920x1080"
readonly RESOLUTION_ENCODE="1920x1080"
readonly FIELD_SETTING="field:none"

# Network Constants
readonly TARGET_IP="192.168.0.22"  # Update this to your receiver IP
readonly TARGET_PORT="5000"
readonly BITRATE="6000" # 6 Mbps for 1080p with low GOP (Unit is Kbps for omxh264enc/omxh265enc)

# Ultra-Low-Latency Encoder Settings
readonly GOP_LENGTH="3"            # 100ms at 30fps (ultra-low latency)
readonly IDR_PERIOD="3"            # Match GOP for frequent keyframes
readonly NUM_SLICES="8"            # Parallel encoding for reduced latency
readonly PROFILE="main"            # Main profile for better compression
readonly LEVEL="4.2"               # H.264 Level 4.2 for 1080p30
readonly MTU="1200"                # Reduced MTU for less fragmentation delay

# GPIO Reset Constants (VCU reset on bit 6)
readonly GPIO_RST_DEVICE="gpiochip0"
readonly VCU_RESET_BIT=6

echo "=== KV260 OV5647 Camera + VCU UDP Streaming Setup Script ==="
echo "Note: Run 'sudo xmutil desktop_disable' and 'sudo xmutil loadapp kv260_rpicamera_to_dp' before this script"
echo ""

# 0. Initialize VCU hardware
echo "=== Initializing VCU Hardware ==="

# Use standard gpioset for GPIO chip manipulation to take VCU out of reset (bit 6 high)
if command -v gpioset &> /dev/null; then
    echo "Resetting VCU hardware via gpiochip0 bit 6..."
    gpioset ${GPIO_RST_DEVICE} ${VCU_RESET_BIT}=1 2>/dev/null || echo "Note: gpioset failed. VCU might already be out of reset."
else
    echo "WARNING: gpioset not found. Consider running: sudo apt install gpiod"
fi
echo ""

# 1. Configure V4L2 pipeline formats
echo "=== Configuring Pipeline Formats ==="
media-ctl -V "\"${SENSOR_ENTITY}\":0 [fmt:${SENSOR_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${MIPI_CSI_ENTITY}\":0 [fmt:${SENSOR_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${MIPI_CSI_ENTITY}\":1 [fmt:${SENSOR_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${DEMOSAIC_ENTITY}\":0 [fmt:${SENSOR_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${DEMOSAIC_ENTITY}\":1 [fmt:${RGB_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${GAMMA_ENTITY}\":0 [fmt:${RGB_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${GAMMA_ENTITY}\":1 [fmt:${RGB_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${CSC_ENTITY}\":0 [fmt:${RGB_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${CSC_ENTITY}\":1 [fmt:${STREAM_YUV_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${SCALER_ENTITY}\":0 [fmt:${STREAM_YUV_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${SCALER_ENTITY}\":1 [fmt:${STREAM_YUV_FORMAT}/${RESOLUTION_ENCODE} ${FIELD_SETTING}]"

# 2. Enable pipeline links
echo "=== Enabling Pipeline Links ==="
media-ctl -l "\"${SENSOR_ENTITY}\":0->\"${MIPI_CSI_ENTITY}\":0[1]"
media-ctl -l "\"${MIPI_CSI_ENTITY}\":1->\"${DEMOSAIC_ENTITY}\":0[1]"
media-ctl -l "\"${DEMOSAIC_ENTITY}\":1->\"${GAMMA_ENTITY}\":0[1]"
media-ctl -l "\"${GAMMA_ENTITY}\":1->\"${CSC_ENTITY}\":0[1]"
media-ctl -l "\"${CSC_ENTITY}\":1->\"${SCALER_ENTITY}\":0[1]"
media-ctl -l "\"${SCALER_ENTITY}\":1->\"vcap_v_proc_ss_scaler output 0\":0[1]"

# 3. Configure sensor settings
echo "=== Configuring Sensor Settings ==="
v4l2-ctl --set-ctrl=analogue_gain=600 --set-ctrl=exposure=900

# 4. Apply color correction (CSC)
echo "=== Applying Color Correction ==="
v4l2-ctl -d /dev/v4l-subdev4 --set-ctrl=csc_brightness=60 --set-ctrl=csc_contrast=55 2>/dev/null || true
v4l2-ctl -d /dev/v4l-subdev4 --set-ctrl=csc_red_gain=65 --set-ctrl=csc_green_gain=35 --set-ctrl=csc_blue_gain=55 2>/dev/null || true

# 5. Apply gamma correction
echo "=== Applying Gamma Correction ==="
v4l2-ctl -d /dev/v4l-subdev0 --set-ctrl=red_gamma_correction_1_0_1_10=12 2>/dev/null || true
v4l2-ctl -d /dev/v4l-subdev0 --set-ctrl=blue_gamma_correction_1_0_1_10=12 2>/dev/null || true
v4l2-ctl -d /dev/v4l-subdev0 --set-ctrl=green_gamma_correction_1_0_1_1=10 2>/dev/null || true

# 6. Configure video device node for NV12 output
echo "=== Configuring Video Node ==="
v4l2-ctl -d ${VIDEO_DEVICE} --set-fmt-video=width=${RESOLUTION_ENCODE%x*},height=${RESOLUTION_ENCODE#*x},pixelformat=NV12

# 7. Verify Video Device
echo "=== Verifying Video Device ==="
v4l2-ctl -d ${VIDEO_DEVICE} --get-fmt-video

echo ""
echo "=== Setup Complete ==="
echo ""
echo "=== VCU Hardware Streaming Command (1080p30, Multicast) ==="
echo ""
echo "sudo gst-launch-1.0 -v v4l2src device=${VIDEO_DEVICE} io-mode=mmap ! \\"
echo "  \"video/x-raw, width=${RESOLUTION_ENCODE%x*}, height=${RESOLUTION_ENCODE#*x}, format=NV12, framerate=30/1\" ! \\"
echo "  omxh264enc target-bitrate=${BITRATE} control-rate=low-latency prefetch-buffer=true \\"
echo "    gop-length=${GOP_LENGTH} b-frames=0 periodicity-idr=${IDR_PERIOD} num-slices=${NUM_SLICES} ! \\"
echo "  \"video/x-h264, profile=${PROFILE}, level=(string)${LEVEL}, alignment=au\" ! \\"
echo "  h264parse config-interval=1 ! \\"
echo "  rtph264pay config-interval=1 pt=96 mtu=${MTU} ! \\"
echo "  udpsink host=224.1.1.1 port=${TARGET_PORT} auto-multicast=true ttl-mc=1 sync=false async=false"
echo ""