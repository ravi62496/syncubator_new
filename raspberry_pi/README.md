# Syncubator

An incubator monitoring & control system: a Raspberry Pi reads live sensor
data (temperature, humidity, weight, bed position, oxygen level) and
controls actuators (heaters, humidifier, bed motor, oxygen valve), exposing
everything over a secured HTTPS API that a Flutter mobile app connects to.

---

## 1. How it fits together

```
 Sensors (I2C / GPIO / analog)
    │
    ▼
 Raspberry Pi
    │  hardware drivers + background polling threads
    ▼
 Flask API (app.py)            — defines routes, holds shared `state` dict
    │
    ▼
 Gunicorn                      — production WSGI server running app.py
    │  1 worker process, 8 threads (gthread), bound to 127.0.0.1:5000 only
    ▼
 Nginx                         — reverse proxy, listens on 443
    │  terminates TLS, forwards to Gunicorn over localhost
    ▼
 HTTPS (self-signed cert, pinned to the Pi's static IP)
    │
    ▼
 Flutter App                   — polls /status every 1s, sends control
                                  commands, displays the camera stream
```

**Why this many layers?** Flask's built-in dev server (`app.run(...)`) is
fine for testing but isn't meant to face real traffic. Gunicorn is the
production-grade server that replaces it. Nginx sits in front of Gunicorn
to terminate HTTPS and to correctly handle the camera's long-lived MJPEG
stream (`proxy_buffering off`), which Gunicorn alone handles awkwardly.
Gunicorn is deliberately locked to `127.0.0.1` only — it is **not**
reachable directly from the network, only through Nginx.

---

## 2. Hardware

| Component | Purpose | Interface | Address / Pin |
|---|---|---|---|
| TMP117 (×2) | Air temperature | I2C | `0x48`, `0x49` |
| BME680 | Temp / humidity / pressure | I2C | `0x77` (fallback `0x76`) |
| MS8607 | Humidity (secondary) | I2C | `0x40` |
| VL53L4CD | Time-of-flight distance (bed position) | I2C | default address |
| ADS1115 + analog O2 sensor | Ambient oxygen % | I2C (analog channel 0) | `0x4A` |
| HX711 (×4) | Load cell amplifiers (weight) | GPIO bit-bang | DT pins `22, 5, 19, 21`, shared SCK `17` |
| Relay: Heater A / Heater B | Climate heating (redundant pair) | GPIO OUT | `23`, `24` |
| Relay: Humidifier | Climate humidity | GPIO OUT | `16` |
| Motor: bed up / down | Bed tilt/position motor | GPIO OUT | `25`, `26` |
| Servo (PWM) | Oxygen valve position (0–7 levels) | GPIO PWM | `18` |
| IMX708 CSI camera | Live video | `rpicam-vid` subprocess | — |

All GPIO pin numbers are **BCM numbering**, not physical pin numbers.
Relays are active-low (`RELAY_ACTIVE_LOW = True` in `app.py`) — confirm this
matches your relay board before wiring a new one.

**Calibration constants** (`CAL_FACTORS`, `ZERO_OFFSETS` for the load
cells; `O2_V_ZERO`/`O2_V_AIR`/etc. for the oxygen sensor) are specific to
the physical units currently installed. If you swap a load cell or the O2
sensor, these need to be recalibrated — they are not universal constants.

---

## 3. Repository structure

```
├── app.py                  # Flask app: routes + hardware drivers + background loops
├── requirements.txt        # Python dependencies (see note on version pinning below)
├── deploy/
│   ├── syncubator.service  # systemd unit — runs app.py under Gunicorn on boot
│   └── nginx_syncubator.conf  # Nginx reverse proxy + TLS config
└── README.md
```

The Flutter app lives in a separate repo/directory
(`lib/services/api_service.dart`, `lib/utils/secure_http_client.dart`,
`lib/utils/api_constants.dart`, `lib/widgets/camera_stream_card.dart` are
the files most relevant to how it talks to the Pi — see section 6).

---

## 4. Raspberry Pi setup (from a fresh clone)

### 4.1 Prerequisites

```bash
sudo apt update
sudo apt install -y python3-dev python3-venv libatlas-base-dev i2c-tools nginx
sudo raspi-config   # Interface Options → I2C → Enable
```

Verify sensors are visible on the bus before doing anything in Python:

```bash
i2cdetect -y 1
```

### 4.2 Python environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

> **Note on `requirements.txt`:** `Flask` and `gunicorn` are pinned to known
> working versions. `numpy` and the Adafruit CircuitPython packages are
> intentionally **not** pinned — pinning them previously caused install
> failures (no matching wheel for the Python version in use, or a version
> that no longer exists on PyPI). Letting pip resolve current compatible
> versions has been more reliable in practice on Raspberry Pi OS.

### 4.3 Manual test (before touching systemd)

```bash
python3 app.py
```

Confirm the log shows `[OK]` for each sensor you have physically connected,
then hit `http://<pi-ip>:5000/status` from another device on the network
and confirm it returns live (non-zero) sensor readings, not just valid
JSON shape. Ctrl+C to stop once confirmed.

### 4.4 Static IP (required for the HTTPS cert to keep working)

The TLS certificate is generated for the Pi's specific IP address. If the
Pi's IP ever changes, the certificate becomes invalid for the new address.
Reserve the Pi's IP either in your router's DHCP settings, or directly via
NetworkManager on the Pi:

```bash
nmcli connection show   # find your active connection's name
sudo nmcli connection modify "<connection-name>" \
  ipv4.addresses <pi-ip>/24 ipv4.gateway <router-ip> \
  ipv4.dns "1.1.1.1,8.8.8.8" ipv4.method manual
sudo nmcli connection down "<connection-name>" && sudo nmcli connection up "<connection-name>"
```

Reboot and confirm the IP survives a full restart before moving on.

### 4.5 Self-signed HTTPS certificate

```bash
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout syncubator.key -out syncubator.crt -days 3650 \
  -subj "/CN=<pi-ip>" -addext "subjectAltName=IP:<pi-ip>"
sudo mkdir -p /etc/nginx/ssl
sudo mv syncubator.crt syncubator.key /etc/nginx/ssl/
sudo chmod 600 /etc/nginx/ssl/syncubator.key
```

The `subjectAltName` flag is required — modern TLS clients (including
Flutter) reject certificates that rely on the older CN-only style.

Copy `syncubator.crt` (not the `.key` — never share the private key) to
whoever is building the Flutter app; it needs to be bundled into the app
as a trusted asset (see section 6).

### 4.6 Nginx

```bash
sudo cp deploy/nginx_syncubator.conf /etc/nginx/sites-available/syncubator
sudo ln -s /etc/nginx/sites-available/syncubator /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default   # avoid it intercepting requests
sudo nginx -t     # check syntax before reloading
sudo systemctl reload nginx
```

Edit the `server_name` and cert paths in the config to match your Pi's IP
if different from what's checked in.

### 4.7 systemd service

```bash
sudo cp deploy/syncubator.service /etc/systemd/system/syncubator.service
```

Edit `WorkingDirectory`, `User`, and the `ExecStart` path inside that file
to match where you actually cloned this repo and which Linux user should
run it (needs to be in the `gpio`/`i2c`/`video` groups for hardware access).

```bash
sudo systemctl daemon-reload
sudo systemctl enable syncubator.service
sudo systemctl start syncubator.service
sudo systemctl status syncubator.service   # should show "active (running)"
```

Check logs any time with:

```bash
sudo journalctl -u syncubator.service -f
```

### 4.8 Verifying the full chain

```bash
curl -s --max-time 3 http://<pi-ip>:5000/status     # should FAIL (port locked to localhost — expected)
curl -sk https://<pi-ip>/status                       # should return live JSON
```

---

## 5. API reference

All endpoints are served at `https://<pi-ip>` (port 443, via Nginx).

| Method | Path | Body | Notes |
|---|---|---|---|
| GET | `/status` | — | Full current state: weight, climate, bed, oxygen |
| POST | `/weight/tare` | — | Zeroes all load cells; platform must be empty |
| POST | `/climate/settings` | `{target_temp?, target_hum?, active_heater?, enabled?}` | Any subset of fields; only provided keys are updated |
| POST | `/bed/move` | `{"direction": "up" \| "down"}` | Rejected with `409` if bed is already moving; `400` if current position is out of bounds for that direction |
| POST | `/oxygen/level` | `{"level": 0-7}` | Moves the oxygen valve servo; `409` if already moving |
| GET | `/video_feed` | — | MJPEG multipart stream — **cannot** be rendered with a plain `<img>`/`Image.network`; must be parsed frame-by-frame (see `camera_stream_card.dart` on the app side) |

`/status` response shape:

```json
{
  "weight": {"total": 0, "cells": [0,0,0,0], "unit": "g", "status": "OK"},
  "climate": {"temp": 0, "humidity": 0, "pressure": 0, "target_temp": 30.0,
              "target_hum": 60.0, "control_enabled": false,
              "active_heater": 1, "heater_on": false, "humidifier_on": false},
  "bed": {"distance": 0, "status": "idle", "moving": false},
  "oxygen": {"level": 0, "angle": 65, "moving": false, "percent": 0}
}
```

---

## 6. How the Flutter app connects

- **`lib/utils/api_constants.dart`** — `baseUrl` is `https://<pi-ip>` (no
  port; HTTPS default 443). Must match whatever static IP the Pi is
  actually running at.
- **`lib/utils/secure_http_client.dart`** — the app does **not** use
  Flutter's default HTTP client for talking to the Pi. Because the Pi uses
  a self-signed certificate, the default client would reject every
  request (fails TLS validation — it only trusts public certificate
  authorities). This file loads `syncubator.crt` as a bundled asset and
  builds a client that trusts *exactly that one certificate* — not
  certificates in general. Every network call to the Pi, including the
  camera stream, goes through `SecureHttpClient.instance`.
- **`lib/widgets/camera_stream_card.dart`** — the `/video_feed` endpoint
  is an MJPEG multipart stream, which Flutter's `Image.network` cannot
  render (it expects a single static image, not a continuous stream).
  This widget manually reads the byte stream and extracts individual JPEG
  frames between `0xFFD8`/`0xFFD9` markers, rendering each with
  `Image.memory`.
- Getting a new certificate onto a fresh app build: copy `syncubator.crt`
  from `/etc/nginx/ssl/` on the Pi into the Flutter project's
  `assets/certs/syncubator.crt`, and confirm it's registered under
  `flutter: assets:` in `pubspec.yaml`.

---

## 7. Known open items

- **Load cell calibration is unverified.** `CAL_FACTORS`/`ZERO_OFFSETS`
  produce implausible weight readings in current testing (large negative
  numbers). Needs a proper tare + known-weight calibration pass before the
  weight readings can be trusted.
- **Oxygen sensor (ADS1115) calibration is a placeholder.** `O2_V_ZERO`/
  `O2_V_AIR` were set from a bench test, not a full calibration against a
  reference gas mixture — treat `/status`'s `oxygen.percent` as
  indicative, not medically accurate, until this is redone properly.
- **Self-signed cert is IP-pinned.** If the Pi's static IP ever changes,
  the certificate must be regenerated (section 4.5) and the new
  `.crt` re-bundled into the Flutter app.

---

## 8. For new contributors

- Don't change `--bind 127.0.0.1:5000` in `deploy/syncubator.service` back
  to `0.0.0.0` — that was deliberately locked down so the API is only
  reachable via Nginx/HTTPS, not plain HTTP directly.
- Background sensor-reading threads (`weight_loop`, `climate_loop`,
  `bed_monitor`, `oxygen_sensor_loop`) are started **unconditionally at
  module level** in `app.py`, not inside `if __name__ == "__main__":`.
  This is intentional — Gunicorn imports the module rather than running it
  as a script, so anything inside that `if` block never executes in
  production. Don't move new background loops into that block.
- Any new sensor/actuator should follow the existing pattern: init inside
  `init_hardware()` wrapped in `try/except` (so one missing sensor doesn't
  crash the whole app), a dedicated read function, a background loop
  thread started at module level, and its own key under `state`.
