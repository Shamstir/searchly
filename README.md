# Searchly

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

**Searchly** is a premium, smart, and context-aware homescreen dashboard application built with Flutter. It provides an intuitive interface with a collection of powerful widgets designed to boost your productivity. Featuring heavy glassmorphism, satisfying spring physics, rich tactile haptics, and a powerful Universal Command Bar, Searchly brings all your essential tools right to your fingertips in a futuristic UI.

---

## ✨ Features

### 🚀 Universal Command Search
The bottom search bar isn't just for apps; it's a powerful command line for your phone:
- **Fuzzy App Matching**: Type part of an app's name, and if there's only one match, Searchly launches it instantly.
- **Quick Calls**: Type `call John` to instantly search your contacts and dial their number.
- **Smart Alarms**: Type `alarm 7am` or `alarm 14:30` to seamlessly set a native Android alarm.
- **WhatsApp Integration**: Type `wm Hello!` to jump straight into WhatsApp with a pre-filled message.

### 🎨 Premium UI & Touch Experience
- **Heavy Glassmorphism**: Beautiful translucent widget surfaces float above a dynamically blurred background that adapts to your media player's album art.
- **Fluid Spring Physics**: Bouncy, organic scrolling and drawer transitions that mimic natural physics.
- **Rich Haptic Feedback**: Satisfying, customized vibration patterns across the UI—from a subtle "tick" on overscroll to a satisfying "thud" when the app drawer closes.
- **Dark Theme by Default**: Carefully crafted dark color palette to reduce eye strain and save battery.

### 🧩 Smart Widgets
Searchly comes packed with a suite of highly functional and interactive widgets:
- 🕒 **Clock & Weather**: Stay updated with the current time and local weather forecasts.
- 🎵 **Music Player**: Control your media playback directly from the dashboard, complete with dynamic background artwork.
- 🖼️ **Image Gallery**: View your latest photos right on the homescreen.
- ⚙️ **System Controls**: Quick toggles for essential system functions like Flashlight, Volume control, and Brightness adjustments.
- ✅ **Todo List**: Manage your daily tasks seamlessly.
- 📊 **Screen Time Tracker**: Monitor your digital wellbeing with integrated app usage statistics.
- 📱 **App Shortcuts**: Quickly access your most used installed applications.
- 🗄️ **App Drawer**: A bouncy, swipe-up app drawer for accessing all your installed applications.

## 🛠️ Tech Stack & Packages

- **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.11.4)
- **Language**: Dart
- **Key Packages**:
  - `url_launcher` & `android_intent_plus`: Powering the Universal Command Bar deep links and alarms.
  - `flutter_contacts`: Fast on-device contact querying.
  - `photo_manager`: Fetching and displaying local gallery images.
  - `installed_apps`: Retrieving installed apps for shortcuts and the app drawer.
  - `usage_stats`: Providing data for the Screen Time widget.
  - `flutter_volume_controller` & `torch_light`: Managing device volume and flashlight.
  - `flutter_media_controller`: Interfacing with system media sessions.
  - `permission_handler`: Graceful runtime permission requests.
  - `google_fonts`: Custom typography (Inter font).

## 🚀 Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

- Flutter SDK (v3.11.4 or higher)
- Android Studio or VS Code with Flutter extensions
- An Android physical device or emulator (Note: Features like Flashlight, Media Control, Contacts, and Haptics perform best on physical devices).

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/searchly.git
   cd searchly
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

*(Note: On the first launch or when using commands, the app will request multiple runtime permissions such as Storage, Contacts, Phone, and Usage Access. Please grant them to ensure all features function correctly.)*

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/yourusername/searchly/issues).

1. Fork the project.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
