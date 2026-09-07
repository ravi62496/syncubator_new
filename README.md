# Syncubator 🏥👶

Syncubator is a professional Flutter-based application designed for real-time monitoring and control of neonatal incubators. It provides a modern, intuitive interface for healthcare providers to ensure the safety and comfort of newborns.

## 🚀 Project Overview

The system consists of a Flutter frontend that communicates with a Raspberry Pi (running a Flask API). The Pi handles the low-level hardware interactions with sensors and motors, while this app provides the user interface.

### Key Features

*   **Climate Monitoring:** Real-time tracking of Temperature, Humidity, and Oxygen levels using interactive gauges.
*   **Weight Management:** Precision weight monitoring with a built-in "Tare" function for accurate measurements.
*   **Bed Control:** Remote adjustment of the incubator's bed position (elevation and tilt).
*   **Status Dashboard:** At-a-glance view of all critical incubator parameters.
*   **Hardware Integration:** Built to communicate with a Raspberry Pi over a local network (Wi-Fi or Ethernet).

---

## 🛠 Tech Stack

*   **Frontend:** Flutter (Dart)
*   **State Management:** Provider (for real-time UI updates)
*   **Networking:** REST API communication via `http`
*   **Hardware (Backend):** Raspberry Pi running a Python/Flask API

---

## 📦 Getting Started

### 1. Configuration
Before running the app, you must configure the connection to your Raspberry Pi:
1.  Open `lib/utils/api_constants.dart`.
2.  Set `baseUrl` to your Raspberry Pi's IP address (e.g., `https://192.168.0.116`).
3.  Set `useMockData` to `false` when connected to real hardware, or `true` for testing the UI without a Pi.

### 2. Assets
Ensure the following assets are present:
*   `assets/images/logo.jpeg` - The main application logo.
*   `assets/certs/syncubator.crt` - (If using HTTPS) The security certificate for the API.

### 3. Run the App
```bash
# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK for Android
flutter build apk --release
```

### 4. Connected Screen & Multi-Device Setup
To set up a touchscreen/monitor connected directly to the Raspberry Pi while simultaneously running the app on external mobile devices over Wi-Fi, see our detailed guide:
👉 [NEW_SCREEN_SETUP_GUIDE.md](NEW_SCREEN_SETUP_GUIDE.md)

---

## 📁 Project Structure

*   `lib/models/`: Data objects (Weight, Climate, Bed status).
*   `lib/services/`: Logic for API calls and network communication.
*   `lib/providers/`: State management to keep the UI in sync with sensor data.
*   `lib/screens/`: The main UI pages (Home, Settings, etc.).
*   `lib/widgets/`: Custom UI components like gauges and control cards.
*   `lib/utils/`: Theme settings, constants, and global configurations.

---

## 🤝 Contribution & Support

This project aims to provide a reliable software layer for life-saving neonatal equipment.

**Developer:** [ravi62496](https://github.com/ravi62496)
