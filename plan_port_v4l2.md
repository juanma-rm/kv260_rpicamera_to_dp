# Porting Plan: KV260 RPI Camera (OV5647) — V4L2 / GStreamer Approach

> **Alternative approach**: See [`plan_port_pynq.md`](plan_port_pynq.md) for the Kria-PYNQ/UIO method, which bypasses V4L2 entirely.

This document outlines the steps to port the existing bare-metal video pipeline to run on Ubuntu 22.04 using the standard Linux **V4L2**, **Media Controller**, and **DRM/KMS** frameworks.

## Table of Contents

- [Overview](#overview)
- [References](#references)
- [Section 1 — Hardware: Vivado Build, Device Tree & Deployment](#section-1--hardware-vivado-build-device-tree--deployment)
  - [1.1 Project artifacts](#11-project-artifacts)
  - [1.2 Hardware IPs, Addresses, I2C Topology & Interrupts](#12-hardware-ips-addresses-i2c-topology--interrupts)
  - [1.3 Device Tree Overlay — Structure & Manual Edits](#13-device-tree-overlay----structure--manual-edits)
  - [1.4 Deploy Bitstream & Device Tree onto the KV260](#14-deploy-bitstream--device-tree-onto-the-kv260)
- [Section 2 — Linux Drivers: Kernel Modules & Image Sensor](#section-2--linux-drivers-kernel-modules--image-sensor)
  - [2.0 Software setup](#20-software-setup)
  - [2.1 Verify required Kernel modules](#21-verify-required-kernel-modules)
  - [2.2 Load PL IP drivers](#22-load-pl-ip-drivers)
  - [2.3 OV5647 Driver — Patched Out-of-Tree Build](#23-ov5647-driver----patched-out-of-tree-build)
  - [2.4 Verify all drivers are now loaded](#24-verify-all-drivers-are-now-loaded)
- [Section 3 — Linux Media Graph & Stream](#section-3--linux-media-graph--stream)
- [Section 4 — Stream via network (UDP/IP)](#section-4--stream-via-network-udpip)
- [Section 5 — Future work](#section-5--future-work)


## Overview

| Component | Bare Metal | Ubuntu V4L2 |
| :--- | :--- | :--- |
| **Camera Config** | Direct I2C via PS I2C1 (EMIO) | Kernel Driver (`ov5647.ko`) via AXI IIC + PCA9546 mux |
| **Pipeline Mgmt** | Direct AXI-Lite Register Writes | Media Controller / V4L2 Subdevs |
| **Data Transfer (Write)** | AXI VDMA S2MM bare-metal | `xilinx-frmbuf` kernel driver (`v_frmbuf_wr`) |
| **Hardware Scaling** | None | `xilinx-vpss-scaler` (VPSS) |
| **Display** | PS DP Controller (Bare Metal) | DRM/KMS Driver (`zynqmp-dpsub`) |
| **Application** | `while(1)` loop | GStreamer + `kmssink` |

> **Note on DMA**: We have transitioned from **AXI VDMA** to **v_frmbuf_wr**. This aligns with modern Xilinx V4L2 drivers and provides better stability and support for standard video formats. We also added a **VPSS Scaler** for hardware-accelerated upscaling.

---

## References

Xilinx Smart Camera Project
- URLs:
  - https://xilinx.github.io/kria-apps-docs/kv260/2022.1/build/html/docs/smartcamera/docs/sw_arch_platform.html
  - https://xilinx.github.io/kria-apps-docs/kv260/2022.1/build/html/docs/smartcamera/docs/sw_arch_accel.html
  - https://xilinx.github.io/kria-apps-docs/kv260/2022.1/build/html/docs/smartcamera/docs/hw_arch_platform.html
  - https://xilinx.github.io/kria-apps-docs/kv260/2022.1/build/html/docs/smartcamera/docs/hw_arch_accel.html
  - https://xilinx.github.io/kria-apps-docs/kv260/2022.1/build/html/docs/smartcamera/docs/app_deployment.html
  - https://github.com/Xilinx/kria-vitis-platforms/
- Setup:
- Hardware Architecture (PL): 
- Software Architecture: 

A Smart Camera implemented in PetaLinux 2022.1 on ZCU104
- URL: https://www.hfequipment.vn/...
- Setup: ZCU104 Evaluation Kit + Raspberry Pi Camera V2. Built using the PetaLinux 2022.1 toolchain.
- Hardware Architecture (PL): Discrete ISP Chain: MIPI CSI-2 Rx → Demosaic → Gamma LUT → CSC → Scaler → Frame Buffer Write. Unlike unified blocks, this uses individual Xilinx IP cores for each stage of the image pipeline.
- Software Architecture: Embedded Linux (PetaLinux). It utilizes the Xilinx V4L2 TRD (Target Reference Design) framework. Specific tools include media-ctl for pad-to-pad pipeline linking and v4l2-ctl for real-time register tuning of brightness, contrast, and gamma.

RasPi-Camera-V2-KV260
- URL: https://github.com/ikwzm/RasPi-Camera-V2-KV260
- Setup: Kria KV260 Vision AI Starter Kit + RPi Camera V2. Runs on Ubuntu or Debian.
- Hardware Architecture (PL): VPSS-Centric: MIPI CSI-2 Rx → Video Processing Subsystem (VPSS) → Frame Buffer Write. The VPSS is configured in "Samples Per Clock" mode to simplify the design by abstracting demosaic, color space conversion, and scaling into a single managed IP block.
- Software Architecture: Modular Linux Overlay. Uses dtbo-config.txt and xmutil for dynamic hardware loading. The capture is driven by GStreamer using v4l2src with io-mode=4 (DMABUF) to minimize CPU overhead during HD capture.

KV260_IMX477_CAMERA
- URL: https://github.com/zakinder/KV260_IMX477_CAMERA
- Setup: Kria KV260 + IMX477 Sensor. Developed using Vivado and Vitis for a baremetal/standalone implementation.
- Hardware Architecture (PL): Direct-to-Display: IMX477 (4-lanes) → MIPI CSI-2 Rx → Sensor ISP → VDMA → DisplayPort Controller. It prioritizes a high-bandwidth path to the DP output to handle the sensor's 4K capabilities without OS jitter.
- Software Architecture: Baremetal (No OS). The logic is orchestrated in main.c which calls low-level C drivers to manually initialize every IP. Specific drivers like xv_gamma_lut are used to push hardcoded gamma tables (e.g., xgamma10_07) directly into hardware BRAM during boot.


### Xilinx Smart Camera Project: analysis of video pipeline

- Load FPGA platform. It uses xmutil to load the "overlay" (bitstream) that must be loaded into the FPGA before any video device (`/dev/video*`) will exist. The default `kv260-smartcam` overlay connects the MIPI sensor (AR1335) through an ISP (AP1302) to memory. 
- Media Graph: 
  - **Media Controller Framework** (`media-ctl`) to link hardware blocks inside the FPGA.
  ```bash
  # Visualize the media graph. You will see a chain like: `ar1335` (Sensor) -> `ap1302` (ISP) -> `mipi_csi2_rx_subsystem` -> `video_mipi` (DMA Write).
  media-ctl -d /dev/media0 -p

  # Manual configuration. The `mediasrcbin` element in GStreamer usually handles this, but if you were doing this purely manually, you would use `media-ctl -V` to set the formats on the pads.
  media-ctl -V '"ar1335 2-003c":0 [fmt:SRGGB10_1X10/1920x1080 field:none]'
  ```
- DisplayPort (DRM/KMS) Configuration. The DisplayPort on Xilinx SoCs is managed by the Direct Rendering Manager (DRM). It writes to a specific hardware **Video Plane**.
  ```bash
  # Find the plane ID. The generic commands often use `plane-id=39`, but this can change based on the kernel version. Run this to find the correct ID:
  # Look for "Planes". Find one that supports `NV12` format (this is the native format of the video pipeline).
  # Note the **ID** of that plane (e.g., 34, 35, 39).
  modetest -M xlnx -p

  # Check Connectivity. Ensure the status is `connected` for the DP/HDMI connector.
  modetest -M xlnx -c
  ```
- Stream the video pipeline via GStreamer: this command bypasses the high-level Python scripts and streams directly from the hardware driver (`v4l2src`) to the display driver (`kmssink`).
  ```bash
  gst-launch-1.0 \
    mediasrcbin media-device=/dev/media0 v4l2src0::io-mode=mmap ! \
    video/x-raw, width=1920, height=1080, format=NV12, framerate=30/1 ! \
    kmssink driver-name=xlnx plane-id=39 fullscreen-overlay=true sync=false
  ```

---

## Section 1 — Hardware: Vivado Build, Device Tree & Deployment

This section covers everything needed to produce and load the FPGA firmware: building the bitstream, generating and editing the device tree overlay, and deploying it onto the KV260.

---

### 1.1 Project artifacts

The hardware build is automated by `output/build_vivado_proj.py`. It drives Vivado and Vitis in batch mode to produce all required artifacts. The script writes all outputs to `output/artifacts/` during the build:

| File | Description |
| :--- | :--- |
| `kv260_rpicamera_to_dp.bit` | Raw Vivado bitstream |
| `kv260_rpicamera_to_dp.bit.bin` | `bootgen`-converted binary (for FPGA manager) |
| `kv260_rpicamera_to_dp.xsa` | Hardware platform (for Vitis / XSCT) |
| `kv260_rpicamera_to_dp.dtsi` | Device tree source — **edited manually** before compilation |
| `kv260_rpicamera_to_dp.dtbo` | Compiled overlay binary (compiled from edited DTSI) |
| `shell.json` | `xmutil` app metadata (`XRT_FLAT`, 1 slot) |
| `bootgen.bif` | BIF file used by `bootgen` to produce the `.bit.bin` |

DTBO generation flow (inside `build_vivado_proj.py`):
1. Generates the XSA (non-extensible) via `write_hw_platform`
2. Creates a Vitis platform with an overlay domain (`dt_overlay=True`) to produce a raw `pl.dtsi`
3. **Pauses and prompts** the user to edit `output/artifacts/kv260_rpicamera_to_dp.dtsi` (add V4L2 nodes — see section 1.3)
4. Resumes and compiles the edited DTSI using `dtc -@ -O dtb` to produce the final `.dtbo`

Alternatively, the user can leave the default `pl.dtsi` as it is, continue with the build process, and then manually edit the `pl.dtsi` file and compile it from the kv260 with:
```bash
dtc -@ -O dtb -o kv260_rpicamera_to_dp.dtbo kv260_rpicamera_to_dp.dtsi
```

---

### 1.2. Hardware IPs, Addresses, I2C Topology & Interrupts

#### Main IP blocks involved

**Video Pipeline IPs:**
- **MIPI CSI-2 RX Subsystem** - Camera interface
  - DPHY lanes: 2 lanes (positions 28, 30)
  - Pixel format: RAW10 (converted to RAW8)
  - Line rate: 912 Mbps
  - Clock lane: position 26
  - IO bank: 66 (HP IO bank)
  - Data width: 10-bit input, 8-bit output via subset converter
  - Supported formats: RAW10, RAW8 (after conversion)
- **AXI Subset Converter** - RAW10→RAW8 conversion  
  - Input: 2 bytes (16 bits) → Output: 1 byte (8 bits)
  - Bit mapping: `tdata[9:2]` (extracts 8 bits from 10)
  - Required for demosaic IP compatibility
  - Data width: 16-bit to 8-bit conversion
- **Video Demosaic** - Bayer to RGB conversion
  - Max resolution: 4096×2560, 8-bit, 1 sample/clock
  - Input format: RAW8 Bayer
  - Output format: RGB888 (24-bit)
  - Data width: 8-bit input, 24-bit output
- **Video Gamma LUT** - Gamma correction
  - Max resolution: 4096×2560, 8-bit
  - Input/Output format: RGB888 (24-bit)
  - Data width: 8-bit per channel (24-bit total)
- **VPSS CSC** - Color space conversion
  - Topology: 3 (color space conversion mode)
  - Max resolution: 4096×2160, 8-bit, 1 sample/clock
  - Input/Output format: RGB888 (24-bit)
  - Data width: 8-bit per channel (24-bit total)
- **VPSS Scaler** - Hardware scaling
  - Max resolution: 4096×2160, 8-bit, topology=0
  - Input/Output format: RGB888 (24-bit)
  - Data width: 8-bit per channel (24-bit total)
  - Scaling capability: Up/down scaling
- **Video Frame Buffer Write** - Memory DMA
  - Max resolution: 4096×2160, 8-bit, 1 sample/clock
  - Supported formats: RGB8, BGR8, RGBX8, BGRX8, XRGB8, XBGR8, Y_UV8_420 (NV12)
  - Data width: 8-bit per component
  - Max planes: 3 (for YUV formats)
- **VCU (Video Codec Unit)** - Hardware H.264/H.265 encoding
  - Encoder enabled, decoder disabled
  - Max resolution: 3840x2160 @ 30fps
  - Color depth / format: 8-bit / YUV 4:2:0
  - Number of streams max: 1

**Control & Support IPs:**
- **AXI IIC** - I2C controller for camera
  - Interface: I2C (400 kHz)
  - Board interface: som240_1_connector_hda_iic_switch
- **AXI GPIO** - Reset controller for video IPs
  - GPIO width: 6 bits
  - All outputs, default value: 0x3F
  - Bit mapping: demosaic(0), gamma(1), cam_en(2), scaler(3), frmbuf(4), csc(5)
- **Counter Wrapper** - Debug/test output
  - Output width: 8 bits
  - Clock domain: 100 MHz

#### Video Pipeline Flow

```
OV5647 Camera
     │ (MIPI CSI-2, 2 lanes, RAW10)
     ▼
MIPI CSI-2 RX Subsystem
     │ (AXI-Stream, RAW10)
     ▼
AXI Subset Converter
     │ (AXI-Stream, RAW8)
     ▼
Video Demosaic
     │ (AXI-Stream, RGB888)
     ▼
Video Gamma LUT
     │ (AXI-Stream, RGB888)
     ▼
VPSS CSC (Color Space Conv.)
     │ (AXI-Stream, RGB888)
     ▼
VPSS Scaler (Hardware Scaling)
     │ (AXI-Stream, RGB888)
     ▼
Video Frame Buffer Write
     │ (AXI DMA, DDR Memory)
     ▼
Linux V4L2 Driver (/dev/video0)
     │
     ▼
(Optional) VCU (Video Codec Unit)
     │
     ▼
User Application (OpenCV, GStreamer, etc.). To display, file, network stream, etc.
```

#### Interrupt Routing

All PL IPs connect **directly to the GIC** via `pl_ps_irq1` (no `axi_intc_0` cascade). The `xlconcat_0` output feeds `zynq_ultra_ps/pl_ps_irq1` directly. In the DTSI each IP's `interrupt-parent` is `<&gic>` and interrupts use the 3-cell GIC SPI format `<0 SPI_number trigger>`.

**Interrupt mapping (SPI numbers)**:
| IP | Interrupt | SPI | xlconcat input |
| :--- | :--- | :--- | :--- |
| `v_frmbuf_wr_0` | interrupt | 104 | In0 |
| `axi_iic_0` | iic2intc_irpt | 105 | In1 |
| `mipi_csi2_rx_0` | csirxss_csi_irq | 106 | In2 |
| `v_demosaic_0` | interrupt | 107 | In3 |
| `v_gamma_lut_0` | interrupt | 108 | In4 |
| `vcu_0` | vcu_host_interrupt | 109 | In5 |

**Issues found**:
- **AXI INTC kernel panic**: The `irq-xilinx` driver on kernel 5.15 has a known bug causing a kernel panic (`xintc_write` null-pointer write) when the INTC is loaded via DT overlay rather than at boot. **Fix**: removing INTC IP and routing directly to the GIC (MPSoC IP interface) avoids this entirely.
- **GIC IRQ0 conflicts**: When connecting to IRQ0, the KV260 base DT pre-registers SPI 89-94 as `"fabric"` IRQs, causing `-EBUSY` conflicts when the overlay tries to claim them with different flags. **Fix**: using PSU__USE__IRQ1 lines instead of 0 to avoid the base DT's pre-claimed range.

#### I2C Topology — Critical Difference from Bare Metal

In bare-metal the OV5647 is accessed via the **PS I2C1 (EMIO)**. Under Linux the routing goes entirely through the PL:

```
PS ARM → AXI IIC (PL IP @ 0xa0040000) → PCA9546 Mux (addr 0x74) → Channel 2 → OV5647 (addr 0x36)
```

Under Linux this becomes a chain of I2C adapters:
- The AXI IIC creates a new Linux `i2c-N` adapter (e.g., `i2c-3`)
- The `pca954x` driver adds 4 sub-buses (e.g., `i2c-4` … `i2c-7`)
- The OV5647 driver binds to the sub-bus for channel 2

---

### 1.3. Device Tree Overlay — Structure & Manual Edits

The DTSI produced by Vitis covers PL clocks, AFI reset, and all IP register nodes. It requires **manual extensions** to describe the V4L2 media graph. The file in `output/artifacts/kv260_rpicamera_to_dp.dtsi` already contains all edits applied.

Note: command outputs shown before do not show vcu since it was not instantiated when they were run.

The following were added by hand to the auto-generated DTSI:

**A. OV5647 sensor clock** (inside `&fpga_full`, at the end):
```dts
/* Manually extended: Sensor Clock for OV5647 */
ov5647_clk: camera-clk {
  compatible = "fixed-clock";
  #clock-cells = <0>;
  clock-frequency = <25000000>;
};	
```

**B. I2C mux topology** (inside the `&amba` / `axi_iic_0` node, at the end):
```dts
/* Manually extended: I2C Topology Extension */
#address-cells = <1>;
#size-cells = <0>;
iic_mux_0: i2c_mux@74 {
  compatible = "nxp,pca9546";
  #address-cells = <1>;
  #size-cells = <0>;
  reg = <0x74>;
  i2c@0 { reg = <0>; };
  i2c@1 { reg = <1>; };
  rpi_i2c: i2c@2 {
    #address-cells = <1>;
    #size-cells = <0>;
    reg = <2>;
    ov5647_0: camera@36 {
      compatible = "ovti,ov5647";
      reg = <0x36>;
      clocks = <&ov5647_clk>;
      pwdn-gpios = <&axi_gpio_rst 2 1>; 
      clock-names = "xclk"; 
      port {
        ov5647_to_mipi: endpoint {
          remote-endpoint = <&mipi_csi_inmipi_csi2_rx_0>;
          clock-lanes = <0>;
          data-lanes = <1 2>;
        };
      };
    };
  };
  i2c@3 { reg = <3>; };
};
```

**C. Media graph endpoint linkage** — (inside `&amba` / `mipi_csi_portsmipi_csi2_rx_0: ports` / `mipi_csi_port0mipi_csi2_rx_0: port@0` / `mipi_csi_inmipi_csi2_rx_0: endpoint` (before data-lanes field)):
```dts
/* Manually extended */
remote-endpoint = <&ov5647_to_mipi>;
```

**D1. Remove the scaler nodes from the autogenerated content**

:warning: do this only if we are using frame buffer xilinx-frmbuf instead of vdma. 

Add the line `status = "disabled";` under each of the following components, as shown:
```dts
  ...
	v_proc_ss_scaler_hsc: v_proc_ss_scaler_hsc@0 {
    /* Manually extended */
    status = "disabled";
  ...
	v_proc_ss_scaler_reset_sel_axis: v_proc_ss_scaler_reset_sel_axis@10000 {
    /* Manually extended */
    status = "disabled";
  ...
	v_proc_ss_scaler_vsc: v_proc_ss_scaler_vsc@20000 {
    /* Manually extended */
    status = "disabled";
  ...
```

**D2. `vcap_pipeline` capture node** (inside `&amba`, at the end):

:warning: do this only if we are using vdma instead of frame buffer xilinx-frmbuf.

```dts
/* Manually extended: Video Capture Pipeline Node linking hardware to V4L2 device */
vcap_pipeline {
  compatible = "xlnx,video";
  dma-names = "port0";
  dmas = <&v_frmbuf_wr_0 1>;   /* Link to Frame Buffer Write engine */
  ports {
    #address-cells = <1>;
    #size-cells = <0>;
    port@0 {
      reg = <0>;
      direction = "input";
      axi_v_frmbuf_wr_0v_proc_ss_scaler: endpoint { remote-endpoint = <&sca_outv_proc_ss_scaler>; };
    };
  };
};
```

---

### 1.4. Deploy Bitstream & Device Tree onto the KV260

> **Artifacts used** from `output/artifacts/`:
> - `kv260_rpicamera_to_dp.bit.bin` — raw binary bitstream (bootgen-converted)
> - `kv260_rpicamera_to_dp.dtbo` — pre-compiled overlay (ready to use)
> - `shell.json` — xmutil app metadata (`XRT_FLAT`, 1 slot)

#### Step 1 — Transfer artifacts to the KV260

```bash
# From dev machine
scp -r output\artifacts\ kv260:/home/ubuntu/
```

On the **KV260**, place the bitstream in the firmware search path:

```bash 
sudo cp ~/artifacts/kv260_rpicamera_to_dp.bit.bin /lib/firmware/
```

#### Step 2 — Load via `xmutil`

```bash
# Create the xmutil app directory with all three files
sudo mkdir -p /lib/firmware/xilinx/kv260_rpicamera_to_dp
sudo cp ~/artifacts/kv260_rpicamera_to_dp.bit.bin /lib/firmware/xilinx/kv260_rpicamera_to_dp/
sudo cp ~/artifacts/kv260_rpicamera_to_dp.dtbo    /lib/firmware/xilinx/kv260_rpicamera_to_dp/
sudo cp ~/artifacts/shell.json                    /lib/firmware/xilinx/kv260_rpicamera_to_dp/

# Unload any currently running app, then load ours
sudo xmutil unloadapp
sudo xmutil loadapp kv260_rpicamera_to_dp

# To set default firmware to be loaded on boot (optional)
echo "kv260_rpicamera_to_dp" | sudo tee /etc/dfx-mgrd/default_firmware

```

#### Step 3 — Verify bitstream is programmed

```bash
# FPGA manager state — must read "operating"
cat /sys/class/fpga_manager/fpga0/state

# Confirm the write event in dmesg
sudo dmesg | grep -E "fpga|firmware|bitstream" | tail -10
# Expected: fpga_manager fpga0: writing kv260_rpicamera_to_dp.bit.bin to Xilinx ZynqMP FPGA Manager
```

#### Step 4 — Verify device tree nodes were created

Note: command outputs shown before do not show vcu since it was not instantiated when they were run.

```bash
# All five PL IP platform devices must appear
ls /sys/bus/platform/devices/ | grep -E "a00"
# Expected something like this:
# a0010000.v_demosaic
# a0030000.v_gamma_lut
# a0080000.v_proc_ss_scaler
# a0020000.v_frmbuf_wr
# 80030000.i2c
# 80040000.gpio

# The AXI IIC must have created a new Linux I2C adapter
i2cdetect -l
# Expected: a new entry like "i2c-3  a0050000.i2c  I2C adapter"
```

#### Step 5 — Check driver probe messages in `dmesg`

Note: some issues are expected at this time, since the ov5647 driver will need some fix.

Note: command outputs shown before do not show vcu since it was not instantiated when they were run.

```bash
sudo dmesg | grep -E "xilinx-(demosaic|gamma|video|dma)|axi-iic|pca954x|ov5647|mipi" | tail -30
```

**Expected key lines** (before `ov5647.ko` is loaded — see section 2):
```
i2c i2c-X: Added multiplexed i2c bus Y        ← PCA9546 mux (4 sub-buses)
xilinx-demosaic a0010000.v_demosaic: Xilinx Video Demosaic Probe Successful
xilinx-gamma-lut a0030000.v_gamma_lut: Xilinx 8-bit Video Gamma Correction LUT registered
xilinx-vpss-scaler a0080000.v_proc_ss_scaler: VPSS Scaler Probe Successful
xilinx-frmbuf a0020000.v_frmbuf_wr: Xilinx Video Framebuffer Probe Successful
xilinx-video axi:vcap_pipeline: device registered   ← /dev/videoX exposed
```

---

## Section 2 — Linux Drivers: Kernel Modules & Image Sensor

This section covers loading all required kernel modules for the PL IPs and the camera sensor, including building the OV5647 driver out-of-tree if it is missing from the kernel.

---

### 2.0. Sotware setup

Using the official Kria Ubuntu 22.04 image:
- [Boot Kria Starter Kit Linux on KV260](https://xilinx.github.io/kria-apps-docs/kv260/2022.1/build/html/docs/linux_boot.html)
- [Ubuntu amd kria-k26 images](https://ubuntu.com/download/amd#kria-k26)

### 2.1. Verify required Kernel modules

Required tools:

```bash
# Install Xilinx PPA and required packages for VCU
sudo add-apt-repository ppa:ubuntu-xilinx/updates
sudo add-apt-repository ppa:xilinx-apps/ppa
sudo apt update
sudo apt install -y v4l-utils yavta i2c-tools device-tree-compiler
sudo apt install -y gstreamer-xilinx1.0-tools gstreamer-xilinx1.0-plugins-good gstreamer-xilinx1.0-plugins-bad gstreamer-xilinx1.0-omx-zynqmp
sudo apt install -y libdrm-xlnx-dev build-essential
sudo apt install -y v4l-utils-xlnx
```

Check kernel config:

```bash
zcat /proc/config.gz | grep -E "CONFIG_VIDEO|CONFIG_XILINX_DMA"
```

Required configs:
- `CONFIG_VIDEO_XILINX_CSI2RXSS` — MIPI CSI-2 RX Subsystem
- `CONFIG_VIDEO_XILINX_FRMBUF` — Video Frame Buffer Write
- `CONFIG_VIDEO_XILINX_VPSS_SCALER` — VPSS Scaler
- `CONFIG_VIDEO_XILINX` — Xilinx Video IP framework
- `CONFIG_VIDEO_XILINX_DEMOSAIC` — Video Demosaic IP
- `CONFIG_VIDEO_XILINX_GAMMA` — Gamma LUT IP
- `CONFIG_VIDEO_OV5647` — OV5647 sensor driver

### 2.2. Load PL IP drivers

The PL IP drivers (Demosaic, Gamma LUT, VDMA, Xilinx video framework, PCA9546) bind automatically when the device tree overlay is applied if the modules are already loaded.

Step 1. Verify platform devices have drivers attached. Look for a 'driver' subdirectory in each device path. The commands should return the full path (e.g., `/sys/bus/platform/devices/a0010000.v_demosaic/driver`)
```bash
ls -d /sys/bus/platform/devices/*.v_demosaic/driver
ls -d /sys/bus/platform/devices/*.v_gamma_lut/driver
ls -d /sys/bus/platform/devices/*.dma/driver
```

Step 2. Check dmesg for "Probe Successful" messages. 
```bash
sudo dmesg | grep -E "demosaic|gamma|video|dma" | tail -n 20
```

If not, load them manually:

```bash
sudo modprobe xilinx-frmbuf      # Framebuffer driver
sudo modprobe xilinx-vpss-scaler # VPSS Scaler driver
sudo modprobe xilinx-video       # Xilinx video framework
sudo modprobe xilinx-demosaic    # Demosaic driver
sudo modprobe xilinx-gamma-lut   # Gamma LUT driver
sudo modprobe i2c-mux-pca954x    # I2C mux driver
```

Check what is already loaded:

```bash
lsmod | grep -E "xilinx|pca954x"
```

Step 3. Verify V4L2 device nodes exist. `/dev/video0` and `/dev/media0` must appear in the `/dev` list.
```bash
ls -l /dev/video* /dev/media*
```

Note: `dev/media*` will not appear until the ov5647 driver is fixed and reloaded.

---

### 2.3. OV5647 Driver — Patched Out-of-Tree Build

The standard OV5647 driver contains an initialization sequence that causes an I2C timeout on the KV260. We must patch the `sensor_oe_enable_regs` values to ensure the sensor powers up correctly on this hardware.

---

#### Patch and build the driver from source code

The OV5647 driver patched is already available at `sw/ov5647_driver_patched`. The sections below show how to get the original driver from the kernel source code and how to patch it, but those steps are not needed if you directly use the patched driver.


Step 1 — Install kernel headers:

```bash
sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r)
```

Step 2 — Get driver source (Xilinx-specific branch):

```bash
# Clone the matched Xilinx kernel source (minimal depth)
git clone --depth 1 --branch xlnx_rebase_v5.15 \
    https://github.com/Xilinx/linux-xlnx.git linux-xlnx

# Extract specifically the ov5647 driver
mkdir ov5647_driver_patched && cp linux-xlnx/drivers/media/i2c/ov5647.c ov5647_driver_patched/
cd ov5647_driver_patched
```

Step 3 — Apply KV260 I2C Timeout Patch, replacing sensor_oe_enable_regs with the following:

```bash
static const struct regval_list sensor_oe_enable_regs[] = {
  {0x3000, 0x0c},
  {0x3001, 0x1f},
  {0x3002, 0xe4},
};

# Optionally, to have feedback in dmesg upon successful loading, replace the line:
dev_dbg(dev, "OmniVision OV5647 camera driver probed\n");
# with:
dev_info(dev, "OmniVision OV5647 camera driver probed successfully\n");
```

Step 4 — Create `Makefile` and compile **from the kv260**:

```bash
touch Makefile
```

```makefile
obj-m := ov5647.o
KDIR := /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install
	depmod -a
```

Compile the driver (generating `ov5647.ko`):
```bash
make
```

#### Install and load the driver

Requirement: `ov5647.ko`, used as it is in `sw/ov5647_driver_patched/` or generated as shown above.

Load the driver from the kv260:

```bash

# Backup the original driver
sudo mv /lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5647.ko /lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5647.ko.bak

# Unload the app and the module in case they were loaded
sudo xmutil unloadapp
sudo modprobe -r ov5647

# Install by replacing ko:
sudo cp ov5647.ko /lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5647.ko
sudo depmod -a # It ensures the kernel's internal index points to the new file; will take a few seconds

# Alternatively, install with Makefile (though this was not working well, the kernel didn't load the module):
sudo make install

```

Now the driver should be installed. Load the driver from the kv260:

```bash

sudo xmutil unloadapp
sudo modprobe -r ov5647
sudo xmutil loadapp kv260_rpicamera_to_dp
sudo modprobe ov5647 # should have been done automatically during the previous step of loading the firmware
sudo dmesg | tail -n 100 # Expected: ov5647 6-0036: OmniVision OV5647 camera driver probed successfully
```

---

### 2.4. Verify all drivers are now loaded

Note: command outputs shown before do not show vcu since it was not instantiated when they were run.

After loading all modules (including `ov5647`):

**Full driver probe check**:
```bash
sudo dmesg | tail -100

[25585.625300] OF: ERROR: memory leak, expected refcount 1 instead of 2, of_node_get()/of_node_put() unbalanced - destroy cset entry: attach overlay node /axi/v_proc_ss@a0080000/ports
[25585.642115] OF: ERROR: memory leak, expected refcount 1 instead of 2, of_node_get()/of_node_put() unbalanced - destroy cset entry: attach overlay node /axi/v_proc_ss@a0030000/ports
[25585.658425] OF: ERROR: memory leak, expected refcount 1 instead of 2, of_node_get()/of_node_put() unbalanced - destroy cset entry: attach overlay node /axi/v_gamma_lut@a0020000/ports
[25585.674888] OF: ERROR: memory leak, expected refcount 1 instead of 2, of_node_get()/of_node_put() unbalanced - destroy cset entry: attach overlay node /axi/v_demosaic@a0010000/ports
[25588.742730] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /fpga-full/firmware-name
[25588.754847] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/misc_clk_0
[25588.764931] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/misc_clk_2
[25588.775015] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/misc_clk_1
[25588.785070] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/clocking1
[25588.795043] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/clocking0
[25588.805025] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/afi0
[25588.814543] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/ov5647_clk
[25588.824609] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/axi_gpio_rst
[25588.834837] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/axi_iic_0
[25588.844811] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/iic_mux_0
[25588.854790] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/rpi_i2c
[25588.864575] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/ov5647_0
[25588.874464] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/ov5647_to_mipi
[25588.884859] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/mipi_csi2_rx_0
[25588.895250] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/mipi_csi_portsmipi_csi2_rx_0
[25588.906860] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/mipi_csi_port1mipi_csi2_rx_0
[25588.918536] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/mipi_csirx_outmipi_csi2_rx_0
[25588.930138] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/mipi_csi_port0mipi_csi2_rx_0
[25588.941724] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/mipi_csi_inmipi_csi2_rx_0
[25588.953049] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_demosaic_0
[25588.963247] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/demosaic_portsv_demosaic_0
[25588.974670] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/demosaic_port1v_demosaic_0
[25588.986093] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/demo_outv_demosaic_0
[25588.996986] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/demosaic_port0v_demosaic_0
[25589.008436] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_demosaic_0mipi_csi2_rx_0
[25589.019857] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_frmbuf_wr_0
[25589.030144] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_gamma_lut_0
[25589.040424] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/gamma_portsv_gamma_lut_0
[25589.051665] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/gamma_port1v_gamma_lut_0
[25589.062904] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/gamma_outv_gamma_lut_0
[25589.073973] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/gamma_port0v_gamma_lut_0
[25589.085214] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_gamma_lut_0v_demosaic_0
[25589.096539] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_proc_ss_csc
[25589.106825] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/csc_portsv_proc_ss_csc
[25589.117923] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/csc_port1v_proc_ss_csc
[25589.128993] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/csc_outv_proc_ss_csc
[25589.139897] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/csc_port0v_proc_ss_csc
[25589.150964] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_proc_ss_cscv_gamma_lut_0
[25589.162405] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_proc_ss_scaler
[25589.172956] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/scaler_portsv_proc_ss_scaler
[25589.184539] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/scaler_port1v_proc_ss_scaler
[25589.196127] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/sca_outv_proc_ss_scaler
[25589.207280] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/scaler_port0v_proc_ss_scaler
[25589.218867] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_proc_ss_scalerv_proc_ss_csc
[25589.230579] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/mipi_csi2_rx_0_rx
[25589.241221] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_proc_ss_csc_csc
[25589.251853] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_proc_ss_scaler_hsc
[25589.262809] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_proc_ss_scaler_reset_sel_axis
[25589.274764] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_proc_ss_scaler_vsc
[25589.285751] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/vcap_portsv_proc_ss_scaler
[25589.297237] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/vcap_portv_proc_ss_scaler
[25589.308596] OF: overlay: WARNING: memory leak will occur if overlay removed, property: /__symbols__/v_frmbuf_wr_0v_proc_ss_scaler
[25589.546003] i2c i2c-3: Added multiplexed i2c bus 4
[25589.552053] i2c i2c-3: Added multiplexed i2c bus 5
[25589.565277] i2c i2c-3: Added multiplexed i2c bus 6
[25589.565575] i2c i2c-3: Added multiplexed i2c bus 7
[25589.565587] pca954x 3-0074: registered 4 multiplexed busses for I2C switch pca9546
[25589.566572] platform a0000000.mipi_csi2_rx_subsystem: Fixing up cyclic dependency with 6-0036
[25589.567624] platform a0010000.v_demosaic: Fixing up cyclic dependency with a0000000.mipi_csi2_rx_subsystem
[25589.572778] xilinx-frmbuf a0040000.v_frmbuf_wr: Xilinx AXI frmbuf DMA_DEV_TO_MEM
[25589.572931] xilinx-frmbuf a0040000.v_frmbuf_wr: Xilinx AXI FrameBuffer Engine Driver Probed!!
[25589.573466] platform a0020000.v_gamma_lut: Fixing up cyclic dependency with a0010000.v_demosaic
[25589.574490] platform a0030000.v_proc_ss: Fixing up cyclic dependency with a0020000.v_gamma_lut
[25589.575691] platform a0080000.v_proc_ss: Fixing up cyclic dependency with a0030000.v_proc_ss
[25589.582677] platform axi:vcap_v_proc_ss_scaler: Fixing up cyclic dependency with a0080000.v_proc_ss
[25589.583417] xilinx-video axi:vcap_v_proc_ss_scaler: device registered
[25589.604267] ov5647 6-0036: OmniVision OV5647 camera driver probed successfully
[25589.606589] xilinx-video axi:vcap_v_proc_ss_scaler: Entity type for entity a0000000.mipi_csi2_rx_subsystem was not initialized!
[25589.608038] xilinx-video axi:vcap_v_proc_ss_scaler: Entity type for entity a0010000.v_demosaic was not initialized!
[25589.608074] xilinx-demosaic a0010000.v_demosaic: Xilinx Video Demosaic Probe Successful
[25589.609444] xilinx-video axi:vcap_v_proc_ss_scaler: Entity type for entity a0020000.v_gamma_lut was not initialized!
[25589.609479] xilinx-gamma-lut a0020000.v_gamma_lut: Xilinx 8-bit Video Gamma Correction LUT registered
[25589.617079] xilinx-video axi:vcap_v_proc_ss_scaler: Entity type for entity a0030000.v_proc_ss was not initialized!
[25589.617104] xilinx-vpss-csc a0030000.v_proc_ss: VPSS CSC 8-bit Color Depth Probe Successful
[25589.618304] xilinx-video axi:vcap_v_proc_ss_scaler: Entity type for entity a0080000.v_proc_ss was not initialized!
[25589.619557] xilinx-vpss-scaler a0080000.v_proc_ss: Num Hori Taps 6
[25589.619570] xilinx-vpss-scaler a0080000.v_proc_ss: Num Vert Taps 6
[25589.619575] xilinx-vpss-scaler a0080000.v_proc_ss: VPSS Scaler Probe Successful


# Expected complete output:
# i2c i2c-X: Added multiplexed i2c bus Y        ← PCA9546 sub-bus (×4)
# pca954x X-0074: registered 4 multiplexed busses for I2C switch pca9546
# xilinx-demosaic a0020000.v_demosaic: Xilinx Video Demosaic Probe Successful
# xilinx-gamma-lut a0030000.v_gamma_lut: Xilinx 8-bit Video Gamma Correction LUT registered
# xilinx-video axi:vcap_pipeline: device registered
# ov5647 Y-0036: OV5647 camera driver probed
```

**Verify I2C chain:**
```bash
# Find AXI IIC adapter (e.g., i2c-3) and mux sub-buses
ubuntu@kria: sudo i2cdetect -l
i2c-1   i2c             Cadence I2C at ff030000                 I2C adapter
i2c-2   i2c             ZynqMP DP AUX                           I2C adapter
i2c-3   i2c             xiic-i2c a0040000.i2c                   I2C adapter
i2c-4   i2c             i2c-3-mux (chan_id 0)                   I2C adapter
i2c-5   i2c             i2c-3-mux (chan_id 1)                   I2C adapter
i2c-6   i2c             i2c-3-mux (chan_id 2)                   I2C adapter
i2c-7   i2c             i2c-3-mux (chan_id 3)                   I2C adapter

# Note the bus id from the previous command and use: sudo i2cdetect -y -r <mux_ch2_bus>
# Expect UU at 0x36 (OV5647 bound by driver)

ubuntu@kria: sudo i2cdetect -y -r 3
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
30: -- -- -- -- -- -- UU -- -- -- -- -- -- -- -- --
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
70: -- -- -- -- UU -- -- --
```

**Verify V4L2 device node exists:**
```bash
ubuntu@kria:~$ ls /dev/video*
/dev/video0

ubuntu@kria:~$ v4l2-ctl --list-devices
vcap_pipeline output 0 (platform:vcap_pipeline:0):
        /dev/video0

Xilinx Video Composite Device (platform:xilinx-video):
        /dev/media0
```

---

## Section 3 — Linux Media Graph & Stream

This section covers configuring the V4L2 media graph (format propagation across all subdevices), tuning the Gamma LUT, and streaming video to the DisplayPort output via GStreamer.

Video flow in software:

Video Frame Buffer Write (Hardware - PL)
     │ Writes the raw video pixels (RGB888) via Direct Memory Access (DMA)
     │ into standard system DDR Memory.
     ▼
V4L2 Driver (Kernel)
     │ The Linux subsystem that tracks where those frames are stored in DDR memory.
     ▼
v4l2src (GStreamer - Userspace)
     │ Claims the memory buffer. With io-mode=mmap, it doesn't copy
     │ the pixels; it just passes the memory pointer down the pipeline.
     ▼
kmssink (GStreamer - Userspace)
     │ Receives the pointer and tells the Linux display driver: "Put the frame
     │ located at this memory address onto hardware Plane 40."
     ▼
DRM/KMS Driver (Kernel)
     │ The Direct Rendering Manager driver programs the registers of the actual
     │ hardware DisplayPort controller.
     ▼
DisplayPort Controller (Hardware - PS)
       Reads the pixels directly from the DDR memory address provided and outputs
       the electrical signal to your monitor.

### Configure media graph and stream to display

The process to **configure the media graph and stream video to the DisplayPort output via GStreamer** is as follows:
1. Configure the media graph using `media-ctl` and `v4l2-ctl` commands.
2. Stream video to the DisplayPort output via GStreamer.

See `sw\setup_v4l2.sh` for the commands to configure the media graph.

```bash
sudo xmutil unloadapp
sudo xmutil loadapp kv260_rpicamera_to_dp
# Expected in the external display before desktop_disable: ubuntu GUI
sudo xmutil desktop_disable # We need to disable the desktop environment. To re-enable desktop later: sudo xmutil desktop_enable
# Expected in the external display after desktop_disable: tty terminal
sudo ./setup_v4l2.sh 

# Stream to display
sudo gst-launch-1.0 v4l2src device=/dev/video0 io-mode=mmap ! "video/x-raw, width=2560, height=1440, format=RGB" ! kmssink driver-name=xlnx plane-id=40 sync=false

# Capture screenshots:
sudo gst-launch-1.0 v4l2src device=/dev/video0 io-mode=4 num-buffers=5 ! video/x-raw,width=2560,height=1440,format=BGRx ! videoconvert ! jpegenc ! multifilesink location=capture_%d.jpeg
```

### GStreamer gst-launch-1.0

`gst-launch-1.0` is a command-line tool used to build and run GStreamer media pipelines.

**Syntax**: `gst-launch-1.0 [OPTIONS] PIPELINE-DESCRIPTION`

**Key Symbols in Pipelines**
- `!` (Exclamation Mark): Links two elements together (the "plug").
- ` ` Space: Separates elements and their properties.
- `.` (Dot): Used to reference named elements or pads (e.g., my_mux.video_sink).

**Source Elements & Parameters**:
- Source types:
  - `v4l2src` - Video4Linux2 source (captures from camera devices)
  - `mediasrcbin` - Media controller source bin (Xilinx-specific, auto-configures media graph, no need to run the `setup_v4l2.sh` file)
  - `filesrc` - Reads from files
  - `videotestsrc` - Generates test patterns
  - `udpsrc` - Network UDP source
- `device=/dev/video0` - Specifies the camera device node to use
- `io-mode=mmap` - Memory-mapped I/O (zero-copy between kernel and userspace)
- `io-mode=dmabuf` - DMA buffer sharing (ideal for passing zero-copy buffers directly to hardware encoders or displays)
- `num-buffers=5` - Pipeline automatically stops after capturing this many frames
- `do-timestamp=true` - Attaches hardware/system timestamps to frames (crucial for latency measurement and A/V sync)

**Format Negotiation (Caps)**:
- `"video/x-raw, width=1920, height=1080, format=BGRx"` - Forces specific formats
- `video/x-raw` - Uncompressed, raw video frames (as opposed to encoded formats like H.264 or JPEG)
- `framerate=30/1` - Negotiates a specific frame rate (e.g., 30 fps)
- `format=NV12` - Native hardware format for KV260 DisplayPort and VPSS blocks (avoids software conversion)

**Processing & Buffering Elements**:
- `videoconvert` - Software format conversion (CPU intensive; avoid if hardware supports native formats)
- `queue` - Creates a new thread and buffers data. Vital in complex pipelines to prevent one slow element from stalling the whole pipeline
- `max-size-buffers=3` - Limits the queue size to reduce latency buildup
- `videorate` - Drops or duplicates frames to match a requested downstream framerate

**Hardware Accelerators (KV260 Specific):**
- `omxh264enc` - OpenMAX H.264 encoder using the VCU hardware
  - `target-bitrate=6000` - Encoding bitrate in Kbps (6 Mbps for 1080p)
  - `control-rate=low-latency` - Optimizes for minimal encoding delay
  - `prefetch-buffer=true` - Pre-fetches frames for smoother encoding
  - `gop-length=3` - GOP size in frames (100ms at 30fps for ultra-low latency)
  - `b-frames=0` - Disables B-frames to reduce latency
  - `periodicity-idr=3` - IDR frame frequency (matches GOP)
  - `num-slices=8` - Number of slices for parallel encoding
- `omxh265enc` - OpenMAX H.265 encoder using the VCU hardware
- `h264parse` - Parses the encoded H.264 stream for packaging (required before muxing)
- `rtph264pay` - Payloads H.264 frames into RTP packets for network transport
  - `config-interval=1` - Sends SPS/PPS headers periodically
  - `pt=96` - Payload type for H.264 in RTP
  - `mtu=1200` - Maximum transmission unit to reduce fragmentation
- `mp4mux` - Packages H.264 video into an MP4 container

**Sinks (Outputs)**:
- **Displays:**
  - `fbdevsink device=/dev/fb0` - Linux framebuffer sink writing to /dev/fb0 (DisplayPort)
    - `kmssink` - Modern DRM/KMS interface with hardware acceleration (recommended)
    - `autovideosink` - Auto-detect best available display sink
    - `glimagesink` - OpenGL hardware acceleration (GUI environments)
    - `ximagesink` - X11 display output (not recommended for embedded)
    - `vaapisink` - VAAPI hardware acceleration (Intel GPU specific)
    - `waylandsink` - Wayland display server (modern alternative to X11)
  - `kmssink` - Direct hardware rendering using DRM/KMS (Zero-copy)
  - `fpsdisplaysink video-sink="kmssink"` - Wraps a video sink and overlays the real-time frames-per-second (FPS) on the screen. Excellent for debugging performance
  - `appsink` - Captures frames and passes them to user applications (like OpenCV in Python/C++)
- **Files:**
  - `multifilesink location=frame_%04d.jpg` - Saves each frame as a sequentially numbered file
  - `filesink location=video.mp4` - Saves the stream to a single file

**Advanced Sink Properties (Low Latency & KMS)**:
- `sync=false` - Sink plays frames immediately as they arrive, ignoring timestamps (lowest latency)
- `async=false` - Does not wait for a state change to complete before continuing, speeding up pipeline start time
- `qos=true` - Enables Quality of Service. The sink tracks latency and tells upstream elements (like the source or decoder) to drop frames if it falls behind

**kmssink Specifics**:
- `driver-name=xlnx` - Forces GStreamer to use the Xilinx DRM driver
- `plane-id=39` - Targets a specific hardware overlay plane (Plane 39 is typically the KV260 Live DP input)
- `fullscreen-overlay=true` - Bypasses standard window managers to draw directly to the screen

### Verify media graph configuration

The following **commands can be used to verify the media graph configuration**:

Note: command outputs shown before do not show vcu since it was not instantiated when they were run.

**Check media topology after setup_v4l2.sh**:

```bash
media-ctl -p

# Expected output

Media controller API version 5.15.136

Media device information
------------------------
driver          xilinx-video
model           Xilinx Video Composite Device
serial
bus info
hw revision     0x0
driver version  5.15.136

Device topology
- entity 1: vcap_v_proc_ss_scaler output 0 (1 pad, 1 link)
            type Node subtype V4L flags 0
            device node name /dev/video0
        pad0: Sink
                <- "a0080000.v_proc_ss":1 [ENABLED]

- entity 5: a0030000.v_proc_ss (2 pads, 2 links)
            type V4L2 subdev subtype Unknown flags 0
            device node name /dev/v4l-subdev0
        pad0: Sink
                [fmt:RBG888_1X24/1920x1080 field:none]
                <- "a0020000.v_gamma_lut":1 [ENABLED]
        pad1: Source
                [fmt:RBG888_1X24/1920x1080 field:none]
                -> "a0080000.v_proc_ss":0 [ENABLED]

- entity 8: a0020000.v_gamma_lut (2 pads, 2 links)
            type V4L2 subdev subtype Unknown flags 0
            device node name /dev/v4l-subdev1
        pad0: Sink
                [fmt:RBG888_1X24/1920x1080 field:none]
                <- "a0010000.v_demosaic":1 [ENABLED]
        pad1: Source
                [fmt:RBG888_1X24/1920x1080 field:none]
                -> "a0030000.v_proc_ss":0 [ENABLED]

- entity 11: a0010000.v_demosaic (2 pads, 2 links)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev2
        pad0: Sink
                [fmt:SBGGR10_1X10/1920x1080 field:none]
                <- "a0000000.mipi_csi2_rx_subsystem":1 [ENABLED]
        pad1: Source
                [fmt:RBG888_1X24/1920x1080 field:none]
                -> "a0020000.v_gamma_lut":0 [ENABLED]

- entity 14: a0080000.v_proc_ss (2 pads, 2 links)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev3
        pad0: Sink
                [fmt:RBG888_1X24/1920x1080 field:none]
                <- "a0030000.v_proc_ss":1 [ENABLED]
        pad1: Source
                [fmt:RBG888_1X24/2560x1440 field:none]
                -> "vcap_v_proc_ss_scaler output 0":0 [ENABLED]

- entity 17: a0000000.mipi_csi2_rx_subsystem (2 pads, 2 links)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev4
        pad0: Sink
                [fmt:SBGGR10_1X10/1920x1080 field:none]
                <- "ov5647 6-0036":0 [ENABLED]
        pad1: Source
                [fmt:SBGGR10_1X10/1920x1080 field:none]
                -> "a0010000.v_demosaic":0 [ENABLED]

- entity 20: ov5647 6-0036 (1 pad, 1 link)
             type V4L2 subdev subtype Sensor flags 0
             device node name /dev/v4l-subdev5
        pad0: Source
                [fmt:SBGGR10_1X10/1920x1080 field:none colorspace:srgb
                 crop.bounds:(16,16)/2592x1944
                 crop:(364,450)/1928x1080]
                -> "a0000000.mipi_csi2_rx_subsystem":0 [ENABLED]
```

**Check video device formats**:
```bash
v4l2-ctl -d /dev/video0 --list-formats-ext

# Expected output

ioctl: VIDIOC_ENUM_FMT
        Type: Video Capture Multiplanar

        [0]: 'RX24' (32-bit XBGR 8-8-8-8)
        [1]: 'XR24' (32-bit BGRX 8-8-8-8)
        [2]: 'RGB3' (24-bit RGB 8-8-8)
        [3]: 'BGR3' (24-bit BGR 8-8-8)
```

**Verify device nodes**:
```bash
ls -l /dev/video* /dev/media*

crw-rw----+ 1 root video 246, 0 Feb 25 12:08 /dev/media0
crw-rw----+ 1 root video  81, 0 Feb 25 12:08 /dev/video0
```

Expected:
- The media topology must show the graph expected according to the video pipeline as defined in the PL block design.
- Entity names use the hex base address without the `0x` prefix (e.g., `a0020000.v_demosaic`).
- The `N` in `ov5647 N-0036` is the Linux I2C adapter number of the PCA9546 channel 2 sub-bus — find it with `i2cdetect -l` or `dmesg | grep "Added multiplexed"`.
- All links must show `[ENABLED]`.

**Verify the sink kmssink (display port controller) state:**

This command dumps the real-time atomic state of the Linux DRM/KMS (Direct Rendering Manager / Kernel Mode Setting) subsystem. It corresponds to the very end of the chain: the software kmssink element and the hardware DisplayPort Controller. Specifically, it shows the configuration of four core DRM hardware elements:
- Planes (e.g., plane[40]): Hardware overlay layers. They fetch the pixel data from DDR memory (where your Video Frame Buffer Write deposited it). The output shows the memory address, resolution, and expected pixel format (like RG16).
- CRTCs (e.g., crtc-0): The actual hardware display controller (Cathode Ray Tube Controller). It takes the planes, blends them together, and applies the display timings (e.g., 2560x1440 @ 60Hz).
- Encoders: The hardware that converts the CRTC's raw pixel stream into the specific electrical signaling needed for the output.
- Connectors (e.g., DP-1): The physical DisplayPort on the KV260 board. It handles monitor detection (plugged/unplugged) and reads the monitor's supported resolutions (EDID).

```bash
sudo cat /sys/kernel/debug/dri/0/state

# Expected output (after sudo xmutil desktop_disable). 2560x1440 @ 60Hz, Plane 40 locked into RG16 (RGB565), text console (fbcon) currently using the screen
plane[39]: plane-0
        crtc=(null)
        fb=0
        crtc-pos=0x0+0+0
        src-pos=0.000000x0.000000+0.000000+0.000000
        rotation=1
        normalized-zpos=0
        color-encoding=ITU-R BT.601 YCbCr
        color-range=YCbCr limited range
plane[40]: plane-1
        crtc=crtc-0
        fb=46
                allocated by = [fbcon]
                refcount=2
                format=RG16 little-endian (0x36314752)
                modifier=0x0
                size=2560x2880
                layers:
                        size[0]=2560x2880
                        pitch[0]=5120
                        offset[0]=0
                        obj[0]:
                                name=0
                                refcount=1
                                start=00100000
                                size=14745600
                                imported=no
                                paddr=0x0000000036200000
                                vaddr=0000000035f8a4c5
        crtc-pos=2560x1440+0+0
        src-pos=2560.000000x1440.000000+0.000000+0.000000
        rotation=1
        normalized-zpos=0
        color-encoding=ITU-R BT.601 YCbCr
        color-range=YCbCr limited range
crtc[41]: crtc-0
        enable=1
        active=1
        self_refresh_active=0
        planes_changed=1
        mode_changed=0
        active_changed=0
        connectors_changed=0
        color_mgmt_changed=0
        plane_mask=2
        connector_mask=1
        encoder_mask=1
        mode: "2560x1440": 60 241500 2560 2608 2640 2720 1440 1443 1448 1481 0x48 0x9
connector[43]: DP-1
        crtc=crtc-0
        self_refresh_aware=0
        max_requested_bpc=0
```

### Verify kmssink and external display

Run a video test with standard color bar pattern to verify the DRM/KMS configuration is correct:
```bash
sudo gst-launch-1.0 videotestsrc !   video/x-raw, width=1920, height=1080, format=RGB !   videoscale ! video/x-raw, width=2560, height=1440 !   kmssink driver-name=xlnx plane-id=40 sync=false
```

### Stream video to DisplayPort or take screenshots 

See `sw\setup_v4l2.sh` for the commands to stream video to the DisplayPort output via GStreamer or take screenshots.

Other useful commands:
```bash
# Display FPS statistics
sudo gst-launch-1.0 -v v4l2src device=/dev/video0 ! \
  video/x-raw,width=2560,height=1440,format=BGRx ! \
  queue ! \
  fpsdisplaysink video-sink=kmssink text-overlay=false sync=false

# Check file was created (check appropriate size):
ls -lh test.png
```

---

## Section 4 — Stream via network (UDP/IP)

### VCU Hardware-Accelerated Multicast Streaming (1080p30, ~300-400ms latency)

**Prerequisites:**

KV260:
```bash
sudo ufw disable  # Disable firewall on KV260
```

**Setup and Stream (KV260):**

```bash
# Load hardware overlay
sudo xmutil unloadapp
sudo xmutil loadapp kv260_rpicamera_to_dp

# Configure VCU pipeline
sudo chmod +x sw/setup_vcu_udp.sh
sudo ./sw/setup_vcu_udp.sh

# Start multicast stream
sudo gst-launch-1.0 -v v4l2src device=/dev/video0 io-mode=mmap ! \
  "video/x-raw, width=1920, height=1080, format=NV12, framerate=30/1" ! \
  omxh264enc target-bitrate=6000 control-rate=low-latency prefetch-buffer=true \
    gop-length=3 b-frames=0 periodicity-idr=3 num-slices=8 ! \
  "video/x-h264, profile=main, level=(string)4.2, alignment=au" ! \
  h264parse config-interval=1 ! \
  rtph264pay config-interval=1 pt=96 mtu=1200 ! \
  udpsink host=224.1.1.1 port=5000 auto-multicast=true ttl-mc=1 sync=false async=false
```

**Workstation (create `stream_multicast.sdp` or use the one available in sw/stream_multicast.sdp):**
```sdp
v=0
o=- 0 0 IN IP4 224.1.1.1
s=KV260 Multicast Stream
c=IN IP4 224.1.1.1/1
t=0 0
m=video 5000 RTP/AVP 96
a=rtpmap:96 H264/90000
a=fmtp:96 packetization-mode=1
```

**Workstation (VLC - multiple clients can use same command):**
```powershell
# Windows
& "C:\Program Files\VideoLAN\VLC\vlc.exe" sw\stream_multicast.sdp --network-caching=30
# Linux
vlc sw/stream_multicast.sdp --network-caching=30
```

**Notes:**
- Multicast allows unlimited simultaneous clients with zero KV260 performance impact
- No firewall configuration needed (uses multicast group 224.1.1.1)
- Expected latency: 300-400ms end-to-end
- GOP=3 frames (100ms), 8 slices for parallel encoding

## Section 5 - Future work

(SOLVED) Improvement 1. Solve performance issues when streaming to display port using GStreamer. The current pipeline configuration used is not optimal (though it was the only was I could get it to work for now). I need to find a way to configure the pipeline so that it doesn't require format conversion via software or uses legacy sink.

Improvement 2. Add a direct path from PL to DisplayPort.
- PL: replace frame buffer with: Video Mixer -> Video Timing Controller (VTC) -> Live DP interface
  - Video Mixer: takes the AXI-Stream from your Broadcaster and converts it into a format the DisplayPort hardware understands. Enable the "Live Video Input" port in its configuration.
  - Video Timing Controller (VTC): requires physical sync signals (HSYNC, VSYNC, Data Enable). The VTC generates these based on your target resolution (e.g., 1080p60).
  - Enable Live DP in Zynq MPSoC block configuration.
  - Check if the device tree includes everything properly.
- PS:
  - Check if there are drivers to control video mixer and VTC.
  - Stream video to the DisplayPort output via GStreamer. We need to tell the Xilinx DRM driver to activate the hardware overlay plane (usually Plane 39 on the KV260)
  ```bash
  gst-launch-1.0 v4l2src device=/dev/video0 ! \
  "video/x-raw, width=1920, height=1080, format=NV12" ! \
  kmssink driver-name=xlnx plane-id=39 sync=false
  ```

(SOLVED) Improvement 3. Add VCU encoder to PL to enable hardware-accelerated video encoding and improve streaming performance.