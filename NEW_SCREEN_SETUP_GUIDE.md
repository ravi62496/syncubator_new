# Syncubator: Connected Screen & Multi-Device Setup Guide

This guide provides step-by-step instructions for configuring a screen connected directly to the Raspberry Pi (HDMI or touchscreen) while simultaneously running the **Syncubator** Flutter app on external mobile devices (Android / iOS / Tablets) over Wi-Fi.

---

## 1. System Architecture Overview

The system utilizes a client-server architecture where the Raspberry Pi functions as both the hardware backend host and a display client.

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                              Raspberry Pi 4 / 5                               │
│                                                                               │
│   ┌──────────────────────────┐         ┌──────────────────────────────────┐   │
│   │ Hardware Drivers & Flask │ ◄─────► │ Gunicorn WSGI + Nginx Proxy      │   │
│   │ (Sensors, Motors, Camera)│         │ (Listens on Port 443 with TLS)   │   │
│   └──────────────────────────┘         └─────────────────┬────────────────┘   │
│                                                          │                    │
│                                                          ▼                    │
│                                        ┌──────────────────────────────────┐   │
│                                        │ Syncubator Flutter App (Linux)   │   │
│                                        └─────────────────┬────────────────┘   │
└──────────────────────────────────────────────────────────┼────────────────────┘
                                                           │ HDMI / Touchscreen
                                                           ▼
                                                  [ Local Pi Display ]

                                                           ▲
                                                           │ Local Wi-Fi / LAN
                                ┌──────────────────────────┴──────────────────────────┐
                                ▼                                                     ▼
                     [ Android Phone / Tablet ]                             [ iOS Device / iPad ]
               (Connects via https://192.168.0.116)                   (Connects via https://192.168.0.116)
```

### Key Technical Concepts:
1. **Central WSGI Server:** Nginx sits on port 443 with TLS termination and proxies requests to Gunicorn running the Flask backend (`app.py`).
2. **Simultaneous Multi-Client Access:** Nginx handles concurrent requests from multiple clients (the local Pi display app and external mobile devices over Wi-Fi).
3. **Unified Endpoint:** Setting `baseUrl = 'https://<PI_STATIC_IP>'` allows the exact same compiled binary/APK to work seamlessly on both the Raspberry Pi screen (via local loopback network routing) and on external phones/tablets.

---

## 2. Prerequisites

### Hardware Requirements
- **Raspberry Pi 4 or 5** running Raspberry Pi OS (64-bit Desktop edition recommended).
- Connected Display (HDMI monitor or official Raspberry Pi DSI/HDMI touchscreen).
- Active local network connection (Wi-Fi or Ethernet router).
- Mobile devices (Android/iOS) connected to the same local Wi-Fi.

### Software Dependencies
On the Raspberry Pi, install necessary packages:
```bash
sudo apt update
sudo apt install -y python3-dev python3-venv libatlas-base-dev i2c-tools nginx \
                    clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
```

---

## 3. Step 1: Reserve Static IP for the Raspberry Pi

The HTTPS certificate and mobile clients rely on a fixed IP address for the Pi.

Find your active network connection name:
```bash
nmcli connection show
```

Configure a static IP (e.g., `192.168.0.116`):
```bash
sudo nmcli connection modify "<connection-name>" \
  ipv4.addresses 192.168.0.116/24 ipv4.gateway 192.168.0.1 \
  ipv4.dns "1.1.1.1,8.8.8.8" ipv4.method manual

sudo nmcli connection down "<connection-name>" && sudo nmcli connection up "<connection-name>"
```
*(Alternatively, reserve the IP address inside your Wi-Fi router's DHCP reservation settings).*

---

## 4. Step 2: Generate Multi-SAN SSL Certificate

Because Flutter strictly enforces TLS security, self-signed certificates must explicitly declare all valid IP addresses under **Subject Alternative Names (SAN)**.

### 1. Generate Certificate on Raspberry Pi
```bash
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout syncubator.key -out syncubator.crt -days 3650 \
  -subj "/CN=192.168.0.116" \
  -addext "subjectAltName=IP:192.168.0.116,IP:127.0.0.1,DNS:localhost"
```

### 2. Install Certificate in Nginx
```bash
sudo mkdir -p /etc/nginx/ssl
sudo mv syncubator.crt syncubator.key /etc/nginx/ssl/
sudo chmod 600 /etc/nginx/ssl/syncubator.key
sudo systemctl reload nginx
```

### 3. Copy Certificate to Flutter App Bundle
Copy `syncubator.crt` from `/etc/nginx/ssl/` into your Flutter repository at:
`assets/certs/syncubator.crt`

Ensure `pubspec.yaml` includes the asset:
```yaml
flutter:
  assets:
    - assets/images/
    - assets/certs/syncubator.crt
```

---

## 5. Step 3: Configure Flutter App Code base

Open `lib/utils/api_constants.dart` and ensure `baseUrl` points to the Pi's static IP address:

```dart
class ApiConstants {
  ApiConstants._();

  /// Set to false to disable mock data and use physical hardware
  static const bool useMockData = false;

  /// The static IP address of your Raspberry Pi
  static const String baseUrl = 'https://192.168.0.116';

  static String get statusEndpoint => '$baseUrl/status';
  static String get weightTareEndpoint => '$baseUrl/weight/tare';
  static String get climateSettingsEndpoint => '$baseUrl/climate/settings';
  static String get bedMoveEndpoint => '$baseUrl/bed/move';
  static String get oxygenLevelEndpoint => '$baseUrl/oxygen/level';

  static const Duration pollInterval = Duration(seconds: 1);
  static const Duration requestTimeout = Duration(seconds: 3);
}
```

---

## 6. Step 4: Setup App on the Raspberry Pi Screen

### Option A: Native Linux Flutter App (Recommended)

1. **Install Flutter SDK on Raspberry Pi (ARM64):**
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable ~/flutter
   echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
   source ~/.bashrc
   
   flutter config --enable-linux-desktop
   ```

2. **Build Release Binary:**
   ```bash
   cd ~/syncubator
   flutter pub get
   flutter build linux --release
   ```

3. **Configure Kiosk Autostart on Boot:**
   Create autostart entry:
   ```bash
   mkdir -p ~/.config/autostart
   nano ~/.config/autostart/syncubator.desktop
   ```
   Add the following content:
   ```ini
   [Desktop Entry]
   Type=Application
   Name=Syncubator
   Exec=/home/pi/syncubator/build/linux/arm64/release/bundle/syncubator
   X-GNOME-Autostart-enabled=true
   ```

---

### Option B: Chromium Web Kiosk Mode (Alternative Setup)

If you prefer not to build native Linux desktop binaries on the Pi:

1. **Build Web Target on Development Machine:**
   ```bash
   flutter build web --release
   ```
2. **Deploy Web Build to Pi Nginx:**
   Copy `build/web/*` contents to `/var/www/html/` on the Pi.

3. **Configure Autostart in Chromium Kiosk:**
   Create `~/.config/autostart/syncubator_kiosk.desktop`:
   ```ini
   [Desktop Entry]
   Type=Application
   Name=Syncubator Kiosk
   Exec=chromium-browser --kiosk --noerrdialogs --disable-infobars --check-for-update-interval=31536000 https://127.0.0.1
   X-GNOME-Autostart-enabled=true
   ```

---

### Option C: Dual HDMI Display Configuration

If two physical HDMI displays are connected to the Pi (HDMI-0 and HDMI-1):

- **To Duplicate/Mirror Screen:**
  ```bash
  xrandr --output HDMI-1 --same-as HDMI-2
  ```
- **To Run Independent Screens:**
  Launch the main Flutter app on Display 1:
  ```bash
  DISPLAY=:0.0 /home/pi/syncubator/build/linux/arm64/release/bundle/syncubator &
  ```

---

## 7. Step 5: Build and Deploy Mobile App (Android/iOS)

1. **Build Android APK:**
   On your development machine:
   ```bash
   flutter build apk --release
   ```
2. **Install APK:**
   Install `build/app/outputs/flutter-apk/app-release.apk` on Android phones/tablets.
3. **Verify Wi-Fi Connection:**
   Ensure the mobile device is connected to the same Wi-Fi network as the Raspberry Pi (`192.168.0.116`).

---

## 8. Step 6: Verification & Testing Checklist

Execute the following verification checklist after setup:

| Test Item | Verification Command / Action | Expected Result |
|---|---|---|
| **Pi API Service** | `sudo systemctl status syncubator.service` | `active (running)` |
| **Nginx Web Proxy** | `curl -sk https://192.168.0.116/status` | Valid status JSON returned |
| **Pi Screen App** | Reboot Pi or run executable | App fills connected screen and updates every 1s |
| **Mobile App** | Open installed APK on phone | Shows live sensor metrics (Temp, Weight, Oxygen) |
| **Camera Feed** | Open Monitoring tab on Pi screen & Phone | Simultaneous live MJPEG camera streaming |
| **Control Commands** | Move bed or change temperature target | Real-time state update reflected across both screens |

---

## 9. Troubleshooting Guide

### 1. SSL / Handshake Exception (`CERTIFICATE_VERIFY_FAILED`)
* **Cause:** The mobile device or Pi app is rejecting the self-signed certificate.
* **Fix:** Ensure the `syncubator.crt` file copied into `assets/certs/syncubator.crt` matches the exact certificate installed in `/etc/nginx/ssl/syncubator.crt` on the Pi.

### 2. Device Unreachable / Connection Timeout
* **Cause:** The Pi's IP changed or Firewall/Router is blocking traffic.
* **Fix:** Verify `baseUrl` matches the Pi's actual IP (`hostname -I`). Check router DHCP settings.

### 3. Video Feed Lag or Black Screen
* **Cause:** Nginx proxy buffering or camera process conflict.
* **Fix:** Ensure `proxy_buffering off;` is set in `/etc/nginx/sites-available/syncubator` for the `/video_feed` endpoint.

---

*Guide generated for Syncubator Version 1.0.0*
