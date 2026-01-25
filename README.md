# PagerBridge (ESP32-S3 → Motorola ADVISOR® Gold FLX DATA IN)

> **Status: Work in progress / not functional yet.** This project is still under active development and **does not currently work with Motorola ADVISOR Gold FLX pagers**. Do not rely on it for production use.

## What this does (no RF)
This project turns a Seeed XIAO ESP32-S3 into a BLE/Serial bridge that injects a **baseband NRZ stream** directly into a Motorola ADVISOR Gold FLX logic board. The RF board is removed; the ESP32 drives the **DATA injection node** on the logic board (continuity to the RF board’s **TA31142 pin 15** net). This branch is configured for **FLEX** terminology (RICs) with a **dummy RIC** until the real RIC is known.  

## Wiring / Injection (ADVISOR Gold FLX)
### Required
- **ESP32 GND → pager GND** (common ground is mandatory).  
  - Tie to **TA31142 pin 19** or a nearby ground plane on the RF board.
- **ESP32 GPIO3 (D2) → TA31142 pin 15 net**  
  - **Recommended:** insert a **1k–2k series resistor** in-line from GPIO3 to the injection node.
  - **Best practice:** isolate the TA31142 output by **lifting pin 15** or **cutting the trace**, then inject on the **downstream side** toward the logic board.

### Drive style
By default the firmware drives **open-drain** for TA31142 injection:
- **Logic 1 / idle**: GPIO3 set to **INPUT (hi-Z)**
- **Logic 0**: GPIO3 driven **OUTPUT LOW**

You can also choose **push-pull** if you need it:
- **Logic 1 / idle**: GPIO3 driven **HIGH**
- **Logic 0**: GPIO3 driven **LOW**

### Optional (for automatic probe/hit detection)
If you want PROBE auto-detect to work, wire the pager’s alert indication to **ALERT_GPIO** (see `kAlertGpio` in `src/main.cpp`):
- Suggested sources: **buzzer drive** line or **LED/backlight** line.
- Use a simple conditioning network if needed (e.g., resistor divider or transistor) to make a clean 3.3 V logic signal.

## ADVISOR Gold FLX bring-up (RF board installed, data isolated)
When the RF board is installed for battery-save wake, keep the RF hardware present but **isolate the data path** so the ESP32 is the only driver of TSP2.

**Wiring checklist**
- Keep the **RF board installed** so the pager stays awake.
- **Disconnect** the RF data net: **RF chip pin 15 → header pin 3 → TSP2** (cut trace or lift pin).
- Inject the ESP32 DATA output into **TSP2** through a **1k series resistor**.
- Share **common ground** between the ESP32 and pager logic board.

**Command checklist**
- Use **open-drain** mode:
  ```
  SET OUTPUT OPEN_DRAIN
  ```
- Send a minimal bring-up page first:
  ```
  SEND_MIN <ric> <function 0-3> <preamble_ms>
  ```
- If there’s no response, toggle polarity and retry:
  ```
  SET INVERT 1
  SEND_MIN <ric> <function 0-3> <preamble_ms>
  ```
- `TEST CARRIER` is **only for scope timing** (not for alerting).

## Bring-up checklist (dummy FLEX RIC 1234567)
**Known values**
- **Protocol:** FLEX (target)
- **Baud:** 512 bps
- **RIC:** 1234567 (dummy placeholder)

**Recommended starting config**
- **OUTPUT:** `OPEN_DRAIN` (open-collector)
- Sweep **INVERT** via `AUTOTEST_FAST` instead of changing RICs.

**Suggested injection points to try (not guaranteed)**
- RF header **DATA** pin (commonly pin 4 in related Advisor projects).
- RF header **wake/pulse** pin (commonly pin 7) to confirm pager activity.
- **TSP2-related pads** only as a secondary option.

**Suggested test flow**
1. Run `DEBUG_SCOPE` at 512 on the chosen injection point.
2. Run `AUTOTEST_FAST 60` while moving the clip/probe.
3. If any beep/alert is observed, lock that combo and use `SEND_MIN_LOOP` for longer.

## No RF service bring-up
On some logic board revisions, **TSP2 may not accept raw sliced NRZ** or the node may be gated/conditioned. If AUTOTEST never decodes, move the injection wire to other test pads and brute-force different signal styles.

### Injection profiles (signal styles)
- **NRZ_SLICED**: raw NRZ bits at the baud rate. Intended for **post-slicer digital nodes** (TSP2).
- **NRZ_PUSH_PULL**: raw NRZ, but push-pull drive for CMOS-style inputs.
- **MANCHESTER**: bi-phase level (each bit is high→low or low→high at half-bit rate).
- **DISCRIM_AUDIO_FSK**: square-wave approximation of discriminator audio (1200/2200 Hz per bit). Intended for **discriminator/analog/slicer-input** nodes.
- **SLICER_EDGE_PULSE**: emit a short low pulse on each NRZ transition. Intended for **AC-coupled nodes**.

### Multi-pin brute force
Set a list of candidate GPIOs so you can move the injection wire without changing commands:
```
SET_GPIO_LIST 3,4
AUTOTEST2 1234567 120
```

Notes:
- Replace the dummy RIC once you identify the pager’s real FLEX RIC.

## Build & flash (PlatformIO)
1. Install **PlatformIO** in VS Code.
2. Open this repo in VS Code.
3. Build and flash:
   ```bash
   platformio run -t upload
   ```
4. Open serial monitor at **115200**:
   ```bash
   platformio device monitor
   ```
   (`monitor_speed = 115200` is already configured in `platformio.ini`.)

## How to use
### BLE interface
- **Device name:** `PagerBridge`
- **Service UUID:** `1b0ee9b4-e833-5a9e-354c-7e2d486b2b7f`
- **RX characteristic (write):** `1b0ee9b4-e833-5a9e-354c-7e2d496b2b7f`
- **Status characteristic (read/notify):** `1b0ee9b4-e833-5a9e-354c-7e2d4a6b2b7f`

You can use any BLE client (nRF Connect, LightBlue, etc.) to write commands or page text to the **RX characteristic**.

### Serial console
Open the serial monitor at 115200 baud. Type the same commands as BLE (ending with newline) to control the pager.

## Commands (BLE or Serial)
Commands are **plain text** and case-insensitive. Examples show the exact text to send.

### STATUS
Shows a single-line summary including baud/invert/output/data GPIO plus default function/preamble.
```
STATUS
```

### SET RIC <int> (alias: SET CAPCODE)
Sets the individual RIC (and group to IND+1 unless already set explicitly).
```
SET RIC 01234567
```

### SET RICIND <int> (alias: SET CAPIND)
```
SET RICIND 01234567
```

### SET RICGRP <int> (alias: SET CAPGRP)
```
SET RICGRP 01234568
```

### SET RICS <ind> <grp> (alias: SET CAPS)
```
SET RICS 01234567 01234568
```

### SET BAUD <512|1200|2400>
```
SET BAUD 1200
```

### SET INVERT <0|1>
```
SET INVERT 1
```

### SET OUTPUT <PUSH_PULL|OPEN_DRAIN|OPEN_COLLECTOR>
```
SET OUTPUT PUSH_PULL
```

### SET_GPIO <pin>
Change the DATA GPIO (re-initializes the transmitter).
```
SET_GPIO 3
```

### SET_GPIO_LIST <pin1,pin2,...>
Store a list of candidate DATA GPIOs for AUTOTEST2 (used when moving the injection wire).
```
SET_GPIO_LIST 3,4
```

### SET_IDLE <0|1>
Set idle polarity (1 = idle high, 0 = idle low).
```
SET_IDLE 1
```

### SET AUTOPROBE <0|1>
Enable/disable a one-time probe on boot (tries the saved IND then GRP RICs once).
```
SET AUTOPROBE 1
```

### PAGE <text>
Send a page to the configured individual RIC (RICIND).
```
PAGE Hello
```

### PAGEI <text>
Force a page to the individual RIC.
```
PAGEI Hello
```

### PAGEG <text>
Force a page to the group RIC.
```
PAGEG Hello
```

### PAGE <ric> <text>
Send to a specific RIC.
```
PAGE 01234567 Hello
```

### TEST CARRIER <ms>
Transmit a repeating 0xAA pattern for wiring verification (uses current BAUD/output/invert).
```
TEST CARRIER 3000
```

### SET_RATE <512|1200|2400>
```
SET_RATE 512
```

### SET_INVERT <0|1>
```
SET_INVERT 0
```

### SET_MODE <opendrain|pushpull>
```
SET_MODE opendrain
```

### SEND_TEST
Send a 2-second 1010 test pattern, then a full preamble + sync + one batch.
```
SEND_TEST
```

### DEBUG_SCOPE
Emit a 2-second 1010 pattern at the current baud using the selected output mode, then stop.
```
DEBUG_SCOPE
```

### SEND_ADDR <ric> <function 0-3>
```
SEND_ADDR 1234567 0
```

### SEND_MSG <ric> <function 0-3> <ascii>
```
SEND_MSG 1234567 0 "HELLO"
```

### SEND_CODEWORDS <hex...>
Inject already-encoded 32-bit codewords (useful for bring-up).
```
SEND_CODEWORDS 0x7CD215D8 0x12345678 0x7A89C197
```

### SEND_MIN <ric> <function 0-3> <preamble_ms>
Send a minimal page burst: preamble (1010) + sync + one batch with only the address codeword.
```
SEND_MIN 1234567 0 1500
```

### SEND_MIN_LOOP <ric> <function 0-3> <preamble_ms> <seconds>
Repeat the minimal page burst until timeout.
```
SEND_MIN_LOOP 1234567 0 1500 30
```

### SEND_SYNC
Send a preamble + sync + short idle for scope verification.
```
SEND_SYNC
```

### AUTOTEST <ric> [seconds]
Sweep baud/invert/idle/function/preamble combinations to brute-force a working page.
```
AUTOTEST 1234567 120
```
- AUTOTEST tries baud **512/1200/2400**, invert **0/1**, idle **1/0**, function **0-3**,
  and preamble lengths **576/1152/2304**.

### AUTOTEST2 <ric> [seconds]
Sweeps **profiles + baud + invert + idle + function + preamble** and iterates across GPIOs in the
`SET_GPIO_LIST` list (or the single configured GPIO if unset).
```
AUTOTEST2 1234567 120
```
Profiles tested:
- `NRZ_SLICED`
- `NRZ_PUSH_PULL`
- `MANCHESTER`
- `DISCRIM_AUDIO_FSK`
- `SLICER_EDGE_PULSE`

### AUTOTEST2 STOP
Stop a running AUTOTEST2 early.
```
AUTOTEST2 STOP
```

### AUTOTEST_FAST <seconds>
Fast deterministic sweep for bring-up (fixed RIC 1234567 at 512 bps, no RIC sweep).
```
AUTOTEST_FAST 60
```

### AUTOTEST STOP
Stop a running AUTOTEST early.
```
AUTOTEST STOP
```

### LIST
List stored pages (newest first). Output is chunked into status notifications and also printed to Serial.
```
LIST
```

### RESEND <index>
Resend a stored page by index from LIST (0 = newest).
```
RESEND 0
```

### CLEAR
Clear stored pages.
```
CLEAR
```

### PROBE START <start> <end> <step>
Sequentially probe RICs and auto-detect a “hit” using ALERT_GPIO.
```
PROBE START 90000 92000 1
```

### PROBE BINARY <start> <end>
Binary-ordered probing (faster coverage) with ALERT_GPIO hit detection.
```
PROBE BINARY 90000 92000
```

### PROBE STOP
Stop any active probe.
```
PROBE STOP
```

### PROBE ONESHOT <cap1> <cap2> ...
Send probe pages once per RIC **without** auto-detection (manual watch).
```
PROBE ONESHOT 91833 91834 91835
```

### SAVE
Force-save settings to NVS (RICs/baud/invert/autoprobe + recent pages).
```
SAVE
```

## Quick-start
1. Wire GND and GPIO3 to the pager DATA injection node (with series resistor).
2. Flash the firmware (PlatformIO).
3. Open Serial Monitor at 115200 and confirm the boot banner prints settings.
4. Send a page:
   ```
   PAGE Hello
   ```
5. If the pager wakes but doesn’t decode, toggle invert:
   ```
   SET INVERT 0
   ```
6. If you need auto-probe, wire ALERT_GPIO and use `PROBE START` or `PROBE BINARY`.

## Recommended settings (ADVISOR Gold FLX TA31142 injection)
- **BAUD:** 512  
- **INVERT:** 0  
- **OUTPUT:** OPEN_DRAIN  
- **RICs:** 1234567 (individual) / 1234568 (group)

## Injecting into logic board (no RF board)
When the RF/IF board is removed, the logic board still expects **sliced data** on the node that
normally connects to the RF detector’s **FSK OUT / sliced data** line. Wire:
- **GND → logic board GND**
- **DATA → logic board DATA-IN node** (the same net that previously went to RF board FSK OUT)

## Troubleshooting (top 3)
1. **Wrong pad / net**: confirm you are on the logic board’s DATA-IN node (the RF board’s FSK OUT net).
2. **Wrong polarity**: try toggling invert (`SET_INVERT 1`) if you see activity but no decode.
3. **Missing pull-up / mode mismatch**: switch between push-pull and open-drain (`SET_MODE opendrain`).

## Quick Test (wiring verification)
1. Check current settings:
   ```
   STATUS
   ```
2. Send a carrier:
   ```
   TEST CARRIER 3000
   ```
3. Page individual RIC:
   ```
   PAGEI test
   ```
4. Page group RIC:
   ```
   PAGEG test
   ```

## Expected behavior / troubleshooting
- **No serial output**  
  Ensure `ARDUINO_USB_CDC_ON_BOOT=1` is enabled (already in `platformio.ini`) and you’re using 115200 baud.
- **Pager wakes but won’t decode**  
  Toggle `SET INVERT 0/1`. The DATA line polarity must match the logic board.
- **Nothing happens at all**  
  Verify **common ground** and the DATA injection node continuity to the TA31142 pin 15 net.
- **Probe doesn’t auto-save RICs**  
  `PROBE START` and `PROBE BINARY` **require ALERT_GPIO**. If ALERT_GPIO isn’t wired, you’ll get `ERROR PROBE NO_ALERT_GPIO`. Use `PROBE ONESHOT` and watch the pager manually.

### Notes
- Leading zeros are just formatting (e.g., **01234567 == 1234567**).
