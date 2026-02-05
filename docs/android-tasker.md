# Android Tasker Setup for PagerBLE (ESP32 BLE Receiver)

This guide documents the **known-good Tasker + AutoNotification + BLE Tasker Plugin** flow used to forward notification text to PagerBLE.

## Known Working Values

```text
MAC:    20:6E:F1:86:D3:89
UUID:   1b0ee9b4-e833-5a9e-354c-7e2d486b2b7f
Plugin: BLE Tasker Plugin (Stein Ov)
Pkg:    nl.steinov.bletaskerplugin
```

## Required Apps / Plugins

1. **Tasker**
2. **AutoNotification** (joaomgcd)
3. **BLE Tasker Plugin** by Stein Ov (`nl.steinov.bletaskerplugin`)

> No paid/obscure plugins are required beyond the apps above.

## Asset Files

- `assets/android/tasker/PagerBLE.prj.xml` (canonical project export)
- `assets/android/tasker/SmstoPager.prj.xml` (legacy-compatible duplicate)
- `assets/android/tasker/known-good-values.txt`

## Import Path (Preferred)

1. Copy `PagerBLE.prj.xml` to your phone.
2. In Tasker: **Data → Restore**.
3. Pick the XML and import project **PagerBLE**.
4. Open task **Smstopager** and verify plugin actions still show configured values.

### Expected Project Contents

- Project: **PagerBLE**
- Profile: **AutoNotification Intercept Event → Smstopager**
- Main task: **Smstopager**
- Test task: **PagerBLE_Test**
- Globals task: **PagerBLE_SetGlobals**

## Android Permissions Checklist (Modern Android)

For **Tasker**, **AutoNotification**, and **BLE Tasker Plugin**:

- [ ] Nearby devices / Bluetooth permissions granted
- [ ] Location permission granted (required on some builds for BLE discovery)
- [ ] AutoNotification has Notification Access enabled
- [ ] Battery optimization disabled for all three apps

### Where to disable battery optimization

Typical path (varies by OEM):
- **Settings → Apps → Special Access → Battery Optimization**
- Set each app to **Unrestricted / Not Optimized**.

## Manual Build Steps (Fallback if import fails)

Use this if Tasker reports **bad packed data format** or if plugin actions lose configuration after import.

### 1) Create Profile

1. In Tasker Profiles: `+` → **Event** → **Plugin** → **AutoNotification Intercept**.
2. Tap pencil icon and configure:
   - Notification Apps filter: start with **Messages** as example.
   - Keep output variables available: `%antitle`, `%antext`.
3. Back out and link profile to task **Smstopager**.

### 2) Create Task `Smstopager`

Add actions in this exact order:

1. **Variable Set**
   - Name: `%msg`
   - To: `SEND %antitle: %antext`
2. **Variable Search Replace**
   - Variable: `%msg`
   - Search: `\n`
   - Replace: ` ` (single space)
   - Global: On
3. **If** `%msg(#) > %PAGER_MAXLEN`
4. **Variable Section**
   - Variable: `%msg`
   - From: `1`
   - Length: `100`
   - Store Result In: `%msg`
5. **End If**
6. **If** `%PAGER_ADD_NL ~ 1`
7. **Variable Set**
   - Name: `%msg`
   - To: `%msg\n`
8. **End If**
9. **Plugin Action → BLE Tasker Plugin → Connect Action**
   - MAC address to connect to: `20:6E:F1:86:D3:89`
   - Override characteristics: **checked**
   - GATT Service UUID: `1b0ee9b4-e833-5a9e-354c-7e2d486b2b7f`
   - Characteristic for receive message event: `1b0ee9b4-e833-5a9e-354c-7e2d486b2b7f`
   - Characteristic for sending messages: `1b0ee9b4-e833-5a9e-354c-7e2d486b2b7f`
10. **Wait** `3000 ms`
11. **Plugin Action → BLE Tasker Plugin → Send Message Action**
    - Encoding: **Text message / UTF-8**
    - Message content: `%msg`
    - Write type: **Write Without Response** (if present)
12. **If** `%err > 0`
13. **Wait** `800 ms`
14. **Plugin Action → Send Message Action** (same config)
15. **End If**
16. *(Optional recommended)* Wait `200 ms`
17. *(Optional recommended)* **Disconnect Action**

### 3) Create globals task `PagerBLE_SetGlobals`

Set:
- `%PAGER_MAC = 20:6E:F1:86:D3:89`
- `%PAGER_UUID = 1b0ee9b4-e833-5a9e-354c-7e2d486b2b7f`
- `%PAGER_MAXLEN = 100`
- `%PAGER_ADD_NL = 1`

### 4) Create test task `PagerBLE_Test`

1. Variable Set `%msg = SEND TEST: HELLO WORLD`
2. Reuse same connect + wait + send sequence as `Smstopager`
3. Run manually to validate BLE path independent of notifications

## Screenshot-Oriented Setup Notes (what to capture on your phone)

When documenting internally, capture these screens:

1. **AutoNotification Intercept config screen**
   - Show selected app filter (Messages example)
   - Show event output fields that feed `%antitle`/`%antext`
2. **BLE Connect Action screen**
   - Show MAC and all three UUID fields (service/receive/send all same UUID)
   - Show “Override characteristics” checked
3. **BLE Send Message Action screen**
   - Show message `%msg`
   - Show UTF-8/text mode and write type
4. **Task run log screen**
   - Show `%err` and `%errmsg` values for failed send troubleshooting

## Troubleshooting

### Import failed / bad packed data format

- Use manual build steps above.
- Or use a Tasker version that can import `tv="6.3.0"` exports cleanly.

### Connect works but send fails intermittently

- Increase connect wait from 3000 ms to 3500–5000 ms.
- Use **Write Without Response** where supported.
- Consider leaving BLE connected between sends for reliability.

### `%err > 0` but no useful message

- Enable plugin debug/logging if available.
- Review Tasker Run Log for `%err` and `%errmsg` around plugin actions.

### ESP32 receives partial strings

- Keep `%PAGER_ADD_NL = 1` if firmware expects newline terminator.
- Keep max length at 100.
- Remove emojis/non-ASCII characters if firmware parser is ASCII-only.

## Disconnect vs keep-connected guidance

- **Disconnect after send** (default in provided task):
  - Better battery behavior
  - More handshake overhead
- **Keep connected** (remove disconnect action):
  - Better burst reliability
  - More battery usage

Use the mode that best matches your notification volume and phone BLE stability.
