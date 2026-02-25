#!/bin/bash

# =============================================================================
# KV260 OV5647 Camera Setup Script
# =============================================================================
# 
# DEVICE DISCOVERY COMMANDS (for different platforms):
#   # List all media devices and their entities:
#   media-ctl -p
#
#   # Find V4L2 subdevices:
#   ls /dev/v4l-subdev*
#   v4l2-ctl --list-devices
#
#   # Find video capture devices:
#   ls /dev/video*
#   v4l2-ctl --list-formats-ext
#
#   # Show media topology with entity names:
#   media-ctl -d /dev/media0 --print-dot
#
# =============================================================================

# Device Constants (update these for different platforms)
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
readonly RESOLUTION_SENSOR="1920x1080"
readonly RESOLUTION_DISPLAY="2560x1440"
readonly FIELD_SETTING="field:none"

echo "=== KV260 OV5647 Camera Setup Script ==="
echo "Note: Run 'sudo xmutil desktop_disable' and 'sudo xmutil loadapp kv260_rpicamera_to_dp' before this script"
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
media-ctl -V "\"${CSC_ENTITY}\":1 [fmt:${RGB_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${SCALER_ENTITY}\":0 [fmt:${RGB_FORMAT}/${RESOLUTION_SENSOR} ${FIELD_SETTING}]"
media-ctl -V "\"${SCALER_ENTITY}\":1 [fmt:${RGB_FORMAT}/${RESOLUTION_DISPLAY} ${FIELD_SETTING}]"

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

# 6. Configure video device node for 1440p RGB
echo "=== Configuring Video Node ==="
v4l2-ctl -d ${VIDEO_DEVICE} --set-fmt-video=width=2560,height=1440,pixelformat=RGB3

# 7. Verify video device
echo "=== Verifying Video Device ==="
v4l2-ctl -d ${VIDEO_DEVICE} --list-formats
v4l2-ctl -d ${VIDEO_DEVICE} --get-fmt-video

echo ""
echo "=== Setup Complete ==="
echo ""
echo "=== Test Commands ==="
echo "# Live video to DP display, zero-copy, 1440p RGB, kmssink, plane 40:"
echo "sudo gst-launch-1.0 v4l2src device=${VIDEO_DEVICE} io-mode=mmap ! \"video/x-raw, width=${RESOLUTION_DISPLAY%x*}, height=${RESOLUTION_DISPLAY#*x}, format=RGB\" ! kmssink driver-name=xlnx plane-id=40 sync=false"
echo ""
echo "# Screenshot capture (skip first frames for exposure settling):"
echo "sudo gst-launch-1.0 v4l2src device=${VIDEO_DEVICE} io-mode=4 num-buffers=5 ! video/x-raw,width=${RESOLUTION_DISPLAY%x*},height=${RESOLUTION_DISPLAY#*x},format=BGRx ! videoconvert ! jpegenc ! multifilesink location=capture_%d.jpeg"
echo ""
