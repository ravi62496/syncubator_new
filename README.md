# Syncubator 🏥👶

Syncubator is a comprehensive, cross-platform Flutter application designed for the monitoring and control of neonatal incubators. It provides a unified interface for both remote monitoring via mobile devices and direct bedside control via a Raspberry Pi touchscreen.

## 🚀 Project Overview

The Syncubator system bridges the gap between hardware and healthcare providers. By running a Flask-based API on a Raspberry Pi, the system collects data from various sensors and controls incubator hardware, while the Flutter frontend provides a modern, intuitive UI for real-time interaction.

### Key Features

*   **Real-time Monitoring:** Track temperature, humidity, and oxygen levels with live updates.
*   **Precision Weight Tracking:** Integrated weight monitoring with the ability to "tare" the scale remotely.
*   **Bed Control:** Adjust the incubator bed position (elevation/tilt) directly from the app.
*   **Dual-Mode Deployment:**
    *   **Mobile (Android):** Optimized for remote monitoring by staff within the hospital network.
    *   **Bedside (Linux/Raspberry Pi):** Optimized for direct interaction via a ribbon-cable connected touchscreen.
*   **Smart API Routing:** Automatically detects the platform to switch between `localhost` (for the Pi) and network IPs (for mobile).

---

## 🛠 Tech Stack

*   **Frontend:** Flutter (Dart)
*   **State Management:** Provider
*   **Backend:** Flask (Python) running on Raspberry Pi
*   **Communication:** RESTful API (http/https)
*   **Hardware:** Raspberry Pi 4, Load Cells, DHT22 Sensors, Oxygen Sensors, Stepper Motors.

---

## 📦 Installation & Setup

### 1. Prerequisites
*   Flutter SDK installed on your development machine.
*   For Raspberry Pi: Raspberry Pi OS (Linux) with build-essential tools.

### 2. Configuration
Open `lib/utils/api_constants.dart` to configure your connection:
*   `useMockData`: Set to `true` for UI testing without hardware, `false` for production.
*   `baseUrl`: Update the IP address to match your Raspberry Pi's network address.

### 3. Building for Mobile (Android)
```bash
flutter build apk --release
```
The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

### 4. Running on Raspberry Pi (Linux)
On your Raspberry Pi terminal:
```bash
# Install dependencies
sudo apt update
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev

# Enable Linux support and run
flutter config --enable-linux-desktop
flutter run -d linux
```

---

## 📁 Project Structure

*   `lib/models/`: Data structures for weight, climate, and bed status.
*   `lib/services/`: API communication logic.
*   `lib/providers/`: Global state management using Provider.
*   `lib/screens/`: UI pages (Dashboard, Controls, Settings).
*   `lib/widgets/`: Reusable UI components (Gauge cards, control buttons).
*   `lib/utils/`: Theme data and API constants.

---

## 🤝 Contribution

This project is part of an ongoing effort to improve neonatal care through open-source hardware and software integration.

**Maintained by:** [ravi62496](https://github.com/ravi62496)
