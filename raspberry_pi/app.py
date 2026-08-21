import time
import threading
import subprocess
import os
import signal
import logging
import numpy as np
from flask import Flask, jsonify, request, Response
import RPi.GPIO as GPIO
import board
import busio
from hx711 import HX711
import adafruit_tmp117
import adafruit_bme680
import adafruit_vl53l4cd
from adafruit_bus_device.i2c_device import I2CDevice
from adafruit_ads1x15.ads1115 import ADS1115
from adafruit_ads1x15.analog_in import AnalogIn

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("syncubator")

app = Flask(__name__)

# ============================================================
# GPIO PIN CONFIGURATION (BCM)
# ============================================================
DT_PINS = [22, 5, 19, 21]
SCK_PIN = 17
HEATER_PIN_A, HEATER_PIN_B, HUMIDIFIER_PIN = 23, 24, 16
MOTOR_UP_PIN, MOTOR_DOWN_PIN = 25, 26
OXYGEN_SERVO_PIN = 18

# CONSTANTS & CALIBRATION
# ============================================================
CAL_FACTORS = [8.04, 8.53, 7.26, 9.84]

ZERO_OFFSETS = [
    1720.28,
    -2542.03,
    14617.63,
    -761.82
]

RELAY_ACTIVE_LOW = True

TEMP_HYSTERESIS = 1.5
HUM_HYSTERESIS = 1.5

# Bed Distance Bounds (cm)
DIST_UP_MIN, DIST_UP_MAX, DIST_UP_TARGET = 0.80, 1.50, 2.20
DIST_DOWN_MIN, DIST_DOWN_MAX, DIST_DOWN_TARGET = 1.50, 2.50, 1.20

# Safety: max time a bed motor is allowed to run before we force-stop it
BED_MOVE_TIMEOUT_S = 20.0

# Oxygen VALVE servo: level 0-7 maps to a servo angle
OXYGEN_LEVEL_MIN, OXYGEN_LEVEL_MAX = 0, 7
OXYGEN_ANGLE_BASE, OXYGEN_ANGLE_STEP = 65, 10  # angle = BASE + STEP * level

# Oxygen SENSOR (ADS1115 analog) — separate physical device from the valve
# servo above. Reads actual ambient O2 percentage.
O2_SENSOR_ADDRESS = 0x4A
O2_V_ZERO, O2_PCT_ZERO = 0.0, 0.0
O2_V_AIR, O2_PCT_AIR = 1.4, 20.9
O2_SENSOR_SLOPE = (O2_PCT_AIR - O2_PCT_ZERO) / (O2_V_AIR - O2_V_ZERO)

# ============================================================
# HARDWARE INITIALIZATION
# ============================================================
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
for pin in [HEATER_PIN_A, HEATER_PIN_B, HUMIDIFIER_PIN, MOTOR_UP_PIN, MOTOR_DOWN_PIN]:
    GPIO.setup(pin, GPIO.OUT)

def relay_write(pin, on):
    level = (GPIO.LOW if on else GPIO.HIGH) if RELAY_ACTIVE_LOW else (GPIO.HIGH if on else GPIO.LOW)
    GPIO.output(pin, level)

# Initial state: All OFF
for p in [HEATER_PIN_A, HEATER_PIN_B, HUMIDIFIER_PIN, MOTOR_UP_PIN, MOTOR_DOWN_PIN]:
    relay_write(p, False)

# Oxygen valve servo (PWM)
GPIO.setup(OXYGEN_SERVO_PIN, GPIO.OUT)
oxygen_servo = GPIO.PWM(OXYGEN_SERVO_PIN, 50)
oxygen_servo.start(0)
oxygen_lock = threading.Lock()  # serializes servo moves separately from the state lock

def oxygen_level_to_angle(level):
    return OXYGEN_ANGLE_BASE + OXYGEN_ANGLE_STEP * level

def set_servo_angle(angle):
    duty = 2.5 + angle / 18
    oxygen_servo.ChangeDutyCycle(duty)
    time.sleep(0.8)
    oxygen_servo.ChangeDutyCycle(0)  # stop sending pulses once the servo has settled

i2c = busio.I2C(board.SCL, board.SDA)
tmp1, tmp2, bme, ms8607_hum, tof, scales = None, None, None, None, None, []
ads, o2_chan = None, None

def init_hardware():
    global tmp1, tmp2, bme, ms8607_hum, tof, scales, ads, o2_chan
    log.info("--- Initializing Hardware ---")
    try:
        tmp1 = adafruit_tmp117.TMP117(i2c, address=0x48)
        log.info("[OK] TMP117 #1")
    except Exception as e:
        log.warning(f"[ERR] TMP117 #1: {e}")

    try:
        tmp2 = adafruit_tmp117.TMP117(i2c, address=0x49)
        log.info("[OK] TMP117 #2")
    except Exception as e:
        log.warning(f"[ERR] TMP117 #2: {e}")

    try:
        try:
            bme = adafruit_bme680.Adafruit_BME680_I2C(i2c, address=0x77)
        except Exception:
            bme = adafruit_bme680.Adafruit_BME680_I2C(i2c, address=0x76)
        log.info("[OK] BME68x")
    except Exception as e:
        log.warning(f"[ERR] BME68x: {e}")

    try:
        ms8607_hum = I2CDevice(i2c, 0x40)
        log.info("[OK] MS8607")
    except Exception as e:
        log.warning(f"[ERR] MS8607: {e}")

    try:
        tof = adafruit_vl53l4cd.VL53L4CD(i2c)
        tof.start_ranging()
        log.info("[OK] VL53L4CD (Bed Distance)")
    except Exception as e:
        log.warning(f"[ERR] VL53L4CD: {e}")

    try:
        ads = ADS1115(i2c, address=O2_SENSOR_ADDRESS)
        o2_chan = AnalogIn(ads, 0)
        log.info("[OK] ADS1115 Oxygen Sensor")
    except Exception as e:
        log.warning(f"[ERR] ADS1115 Oxygen Sensor: {e}")

    log.info("Initializing Weight Scales...")
    for i, dt in enumerate(DT_PINS):
        try:
            s = HX711(dt, SCK_PIN)
            s.reset()
            scales.append(s)
            log.info(f"[OK] Scale {i+1}")
        except Exception as e:
            scales.append(None)
            log.warning(f"[ERR] Scale {i+1}: {e}")

init_hardware()

# ============================================================
# SHARED STATE
# ============================================================
lock = threading.Lock()
state = {
    "weight": {"total": 0, "cells": [0, 0, 0, 0], "unit": "g", "status": "OK"},
    "climate": {
        "temp": 0, "humidity": 0, "pressure": 0,
        "target_temp": 30.0, "target_hum": 60.0,
        "control_enabled": False, "active_heater": 1,
        "heater_on": False, "humidifier_on": False
    },
    "bed": {"distance": 0, "status": "idle", "moving": False},
    "oxygen": {
        "level": 0, "angle": oxygen_level_to_angle(0), "moving": False,
        "percent": 0  # live reading from the ADS1115 O2 sensor
    }
}

# ============================================================
# VIDEO STREAMING (IMX708 CSI SENSOR)
# ============================================================

def gen_frames():
    cmd = [
        'rpicam-vid', '-t', '0', '--width', '640', '--height', '480',
        '--framerate', '20', '--codec', 'mjpeg', '--inline',
        '--nopreview', '--flush', '--denoise', 'cdn_off', '-o', '-'
    ]

    log.info("Starting IMX708 Camera Stream...")
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, preexec_fn=os.setsid)

    try:
        buffer = b""
        while True:
            chunk = process.stdout.read(4096)
            if not chunk:
                break
            buffer += chunk
            while True:
                a = buffer.find(b'\xff\xd8')
                b = buffer.find(b'\xff\xd9', a + 2)
                if a != -1 and b != -1:
                    jpg = buffer[a:b + 2]
                    buffer = buffer[b + 2:]
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n\r\n' + jpg + b'\r\n')
                else:
                    break
    except Exception as e:
        log.error(f"Stream Error: {e}")
    finally:
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
        except Exception:
            pass

@app.route('/video_feed')
def video_feed():
    return Response(gen_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

# ============================================================
# BACKGROUND SENSOR LOOPS
# ============================================================

def read_ms8607_hum():
    if not ms8607_hum:
        return None
    try:
        with ms8607_hum as sensor:
            sensor.write(bytes([0xF5]))
        time.sleep(0.02)
        res = bytearray(3)
        with ms8607_hum as sensor:
            sensor.readinto(res)
        raw = (res[0] << 8) | res[1]
        return max(0.0, min(100.0, ((raw * 125.0) / 65536.0) - 6.0))
    except Exception as e:
        log.debug(f"MS8607 read failed: {e}")
        return None

def read_tof():
    if not tof:
        return -1.0
    try:
        for _ in range(5):
            if tof.data_ready:
                d = tof.distance
                tof.clear_interrupt()
                return d / 10.0
            time.sleep(0.01)
        return -1.0
    except Exception as e:
        log.debug(f"ToF read failed: {e}")
        return -1.0

def read_oxygen_sensor_percent():
    if not o2_chan:
        return None
    try:
        voltage = o2_chan.voltage
        pct = O2_PCT_ZERO + O2_SENSOR_SLOPE * (voltage - O2_V_ZERO)
        return round(pct, 2)
    except Exception as e:
        log.debug(f"O2 sensor read failed: {e}")
        return None

def weight_loop():
    while True:
        w = []
        for i in range(len(scales)):
            if scales[i]:
                try:
                    r = scales[i].get_raw_data(3)
                    v = [x for x in r if x is not None]
                    w.append(round((sum(v) / len(v) - ZERO_OFFSETS[i]) / CAL_FACTORS[i], 2) if v else 0)
                except Exception as e:
                    log.debug(f"Scale {i+1} read failed: {e}")
                    w.append(0)
            else:
                w.append(0)
        with lock:
            state["weight"]["total"] = round(sum(w), 2)
            state["weight"]["cells"] = w
        time.sleep(0.5)

def climate_loop():
    while True:
        try:
            ts, hs = [], []
            p = 0
            if tmp1:
                ts.append(tmp1.temperature)
            if tmp2:
                ts.append(tmp2.temperature)
            if bme:
                ts.append(bme.temperature)
                hs.append(bme.humidity)
                p = bme.pressure
            mh = read_ms8607_hum()
            if mh:
                hs.append(mh)
            at = sum(ts) / len(ts) if ts else 0
            ah = sum(hs) / len(hs) if hs else 0
            with lock:
                state["climate"].update({"temp": round(at, 2), "humidity": round(ah, 2), "pressure": round(p, 2)})
                if state["climate"]["control_enabled"]:
                    tt, th = state["climate"]["target_temp"], state["climate"]["target_hum"]
                    state["climate"]["heater_on"] = at < (tt - TEMP_HYSTERESIS) if not state["climate"]["heater_on"] else at < (tt + TEMP_HYSTERESIS)
                    state["climate"]["humidifier_on"] = ah < (th - HUM_HYSTERESIS) if not state["climate"]["humidifier_on"] else ah < (th + HUM_HYSTERESIS)
                    ap = HEATER_PIN_A if state["climate"]["active_heater"] == 1 else HEATER_PIN_B
                    relay_write(ap, state["climate"]["heater_on"])
                    relay_write(HEATER_PIN_A if ap == HEATER_PIN_B else HEATER_PIN_B, False)
                    relay_write(HUMIDIFIER_PIN, state["climate"]["humidifier_on"])
                else:
                    for pin in [HEATER_PIN_A, HEATER_PIN_B, HUMIDIFIER_PIN]:
                        relay_write(pin, False)
        except Exception as e:
            log.error(f"climate_loop error: {e}")
        time.sleep(2)

def bed_monitor():
    while True:
        d = read_tof()
        if d > 0:
            with lock:
                state["bed"]["distance"] = round(d, 2)
        time.sleep(0.2)

def oxygen_sensor_loop():
    while True:
        pct = read_oxygen_sensor_percent()
        if pct is not None:
            with lock:
                state["oxygen"]["percent"] = pct
        time.sleep(1)

# ============================================================
# API ENDPOINTS
# ============================================================

@app.route("/status")
def get_status():
    with lock:
        return jsonify(state)

@app.route("/weight/tare", methods=["POST"])
def tare_weight():
    for s in scales:
        if s:
            s.tare()
    return jsonify({"message": "Tared"})

@app.route("/climate/settings", methods=["POST"])
def set_climate():
    data = request.json or {}
    with lock:
        if "target_temp" in data:
            state["climate"]["target_temp"] = float(data["target_temp"])
        if "target_hum" in data:
            state["climate"]["target_hum"] = float(data["target_hum"])
        if "active_heater" in data:
            state["climate"]["active_heater"] = int(data["active_heater"])
        if "enabled" in data:
            state["climate"]["control_enabled"] = bool(data["enabled"])
    return jsonify({"status": "updated"})

def do_move(direction, target, pin_on, pin_off, is_up):
    """Drive the bed motor toward `target` distance, with a hard timeout
    and guaranteed motor shutoff even on error (both were missing before)."""
    start_time = time.monotonic()
    with lock:
        state["bed"]["status"] = f"moving_{direction}"
        state["bed"]["moving"] = True
    try:
        while True:
            if time.monotonic() - start_time > BED_MOVE_TIMEOUT_S:
                log.warning(f"Bed move '{direction}' timed out after {BED_MOVE_TIMEOUT_S}s — stopping motor")
                break
            d = read_tof()
            if d < 0 or (is_up and d >= target) or (not is_up and d <= target):
                break
            GPIO.output(pin_on, GPIO.HIGH)
            GPIO.output(pin_off, GPIO.LOW)
            time.sleep(0.1)
    finally:
        GPIO.output(pin_on, GPIO.LOW)
        GPIO.output(pin_off, GPIO.LOW)
        with lock:
            state["bed"]["status"] = "idle"
            state["bed"]["moving"] = False

@app.route("/bed/move", methods=["POST"])
def move_bed():
    direction = (request.json or {}).get("direction")
    if direction not in ("up", "down"):
        return jsonify({"status": "error", "message": "direction must be 'up' or 'down'"}), 400

    with lock:
        already_moving = state["bed"]["moving"]
        curr_dist = state["bed"]["distance"]

    if already_moving:
        return jsonify({"status": "error", "message": "bed is already moving"}), 409

    if direction == "up" and DIST_UP_MIN <= curr_dist <= DIST_UP_MAX:
        threading.Thread(target=do_move, args=("up", DIST_UP_TARGET, MOTOR_UP_PIN, MOTOR_DOWN_PIN, True), daemon=True).start()
        return jsonify({"status": "command_sent"})
    elif direction == "down" and DIST_DOWN_MIN <= curr_dist <= DIST_DOWN_MAX:
        threading.Thread(target=do_move, args=("down", DIST_DOWN_TARGET, MOTOR_DOWN_PIN, MOTOR_UP_PIN, False), daemon=True).start()
        return jsonify({"status": "command_sent"})
    else:
        return jsonify({"status": "error", "message": f"current distance {curr_dist} out of bounds for '{direction}'"}), 400

def do_oxygen_move(level):
    """Move the oxygen valve servo to the angle for `level`, off the request thread."""
    angle = oxygen_level_to_angle(level)
    try:
        with oxygen_lock:
            set_servo_angle(angle)
        with lock:
            state["oxygen"]["level"] = level
            state["oxygen"]["angle"] = angle
    except Exception as e:
        log.error(f"Oxygen valve move failed: {e}")
    finally:
        with lock:
            state["oxygen"]["moving"] = False

@app.route("/oxygen/level", methods=["POST"])
def set_oxygen_level():
    data = request.json or {}
    if "level" not in data:
        return jsonify({"status": "error", "message": "level is required"}), 400
    try:
        level = int(data["level"])
    except (TypeError, ValueError):
        return jsonify({"status": "error", "message": "level must be an integer"}), 400
    if not (OXYGEN_LEVEL_MIN <= level <= OXYGEN_LEVEL_MAX):
        return jsonify({"status": "error", "message": f"level must be between {OXYGEN_LEVEL_MIN} and {OXYGEN_LEVEL_MAX}"}), 400

    with lock:
        if state["oxygen"]["moving"]:
            return jsonify({"status": "error", "message": "oxygen valve is already moving"}), 409
        state["oxygen"]["moving"] = True

    threading.Thread(target=do_oxygen_move, args=(level,), daemon=True).start()
    return jsonify({"status": "command_sent", "level": level})

# Background sensor loops must start unconditionally, not just under
# `python3 app.py`. Gunicorn imports this file as a module (app:app)
# rather than executing it as a script, so __name__ is "app", not
# "__main__" — starting these only inside `if __name__ == "__main__"`
# means they'd never run under Gunicorn.
t1 = threading.Thread(target=weight_loop, daemon=True)
t2 = threading.Thread(target=climate_loop, daemon=True)
t3 = threading.Thread(target=bed_monitor, daemon=True)
t4 = threading.Thread(target=oxygen_sensor_loop, daemon=True)
t1.start(); t2.start(); t3.start(); t4.start()
log.info("Background sensor loops started (weight, climate, bed, oxygen sensor)")

if __name__ == "__main__":
    log.info("SYNCUBATOR SERVER STARTING ON PORT 5000 (dev server)")
    try:
        app.run(host="0.0.0.0", port=5000, threaded=True)
    finally:
        oxygen_servo.stop()
        GPIO.cleanup()
