# Syncubator Project Status & Documentation

## 1. Project Overview
The **Syncubator** app is a Flutter-based mobile application designed to monitor and control an incubator system. It connects to a Flask API running on a Raspberry Pi to provide real-time data and hardware control.

### How the App Runs
- **Framework:** Flutter
- **State Management:** `Provider` pattern (MultiProvider in `main.dart`).
- **Communication:** HTTP requests to a Flask backend.
- **Backend IP:** Currently configured in `lib/utils/api_constants.dart`.
- **Data Updates:** The app polls the Raspberry Pi every 1 second for fresh sensor readings.
- **Mock Mode:** A `useMockData` toggle in `ApiConstants` allows the app to run with simulated data for UI testing.

---

## 2. Directory Structure (`lib/`)
The project follows a clean, modular architecture:

- **`models/`**: Data structures for Bed, Climate, Oxygen, and Weight.
- **`services/`**: Low-level API communication logic (e.g., `bed_service.dart`, `weight_service.dart`).
- **`providers/`**: Business logic and state management that connects services to the UI.
- **`screens/`**: Primary application views (`home_screen.dart`, `monitoring_screen.dart`, `settings_screen.dart`).
- **`widgets/`**: Reusable UI components like `bed_control_card.dart`, `climate_card.dart`, and `bottom_navbar.dart`.
- **`utils/`**: Global constants for APIs (`api_constants.dart`) and styling (`app_colors.dart`).

---

## 3. Implementation Progress
As of now, the following milestones have been completed:

1.  **Architecture Setup:** Implemented a scalable `Provider` + `Service` + `Model` architecture.
2.  **API Integration:** 
    - Established endpoints for `/status`, `/weight/tare`, `/climate/settings`, `/bed/move`, and `/oxygen/level`.
    - Implemented request timeout handling.
3.  **UI/UX Design:**
    - Developed a cohesive dashboard using a card-based layout.
    - Integrated a custom Bottom Navigation Bar.
    - Created interactive controls for hardware (Bed movement, Weight taring).
    - **App Branding:** Configured `logo.jpeg` as the official Launcher Icon for Android and iOS.
4.  **Real-time Synchronization:** Polling mechanism implemented to ensure the UI stays in sync with hardware sensors.
5.  **Testing Tools:** Integrated a Mock Data layer for development without physical hardware.

---

## 4. Current Configuration
- **Base URL:** `http://192.168.0.116:5000`
- **Poll Interval:** 1 Second
- **Request Timeout:** 3 Seconds
